#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # Override this variable for your add-on:
  export GITHUB_REPO=e0ipso/ddev-assistant-copilot

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH:-}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats:${DIR}/test_env/bats_libs"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/${PROJNAME}.XXXXXX")"
  export TEST_MARKER="$(basename "${TESTDIR}")"
  export TEST_HOST_GH_HOSTS="${HOME}/.config/gh/hosts.yml"
  export TEST_HOST_COPILOT_CONFIG="${HOME}/.copilot/config.json"
  export TEST_BACKUP_GH_HOSTS=""
  export TEST_BACKUP_COPILOT_CONFIG=""
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

prepare_host_copilot_config() {
  mkdir -p "${HOME}/.config/gh" "${HOME}/.copilot"

  if [ -e "${TEST_HOST_GH_HOSTS}" ]; then
    TEST_BACKUP_GH_HOSTS="$(mktemp)"
    cp "${TEST_HOST_GH_HOSTS}" "${TEST_BACKUP_GH_HOSTS}"
  fi
  if [ -e "${TEST_HOST_COPILOT_CONFIG}" ]; then
    TEST_BACKUP_COPILOT_CONFIG="$(mktemp)"
    cp "${TEST_HOST_COPILOT_CONFIG}" "${TEST_BACKUP_COPILOT_CONFIG}"
  fi

  echo "test-hosts" >"${TEST_HOST_GH_HOSTS}"
  echo '{"test":true}' >"${TEST_HOST_COPILOT_CONFIG}"
}

check_copilot_cli() {
  run ddev exec "command -v copilot"
  if [ "${status}" -ne 0 ]; then
    echo "# warning: copilot CLI not on PATH (npm install may have failed)" >&3
    skip "copilot CLI not installed (npm install may have failed without network)"
  fi
  assert_output --partial "copilot"

  run ddev exec "copilot --version"
  assert_success
}

health_checks() {
  DDEV_DEBUG=true run ddev launch
  assert_success
  assert_output --partial "FULLURL https://${PROJNAME}.ddev.site"

  # Verify gh is on PATH and accessible via non-interactive `ddev exec`
  run ddev exec "command -v gh"
  assert_success
  assert_output --partial "gh"

  run ddev exec "gh --version"
  assert_success

  # Verify host config dirs are mounted read-only under ~/.cred-seed/
  run ddev exec "test -d ~/.cred-seed/gh"
  assert_success
  run ddev exec "test -d ~/.cred-seed/copilot"
  assert_success

  # Verify writable runtime mirrors exist and are owned by the web user (not root)
  run ddev exec "test -d ~/.config/gh && test -w ~/.config/gh"
  assert_success
  run ddev exec "stat -c '%U' ~/.config/gh"
  assert_success
  refute_output "root"

  run ddev exec "test -d ~/.copilot && test -w ~/.copilot"
  assert_success
  run ddev exec "stat -c '%U' ~/.copilot"
  assert_success
  refute_output "root"

  # Verify copilot is on PATH when npm install succeeded
  check_copilot_cli

  # Restart idempotency: copilot remains on PATH after consecutive restarts
  run ddev restart -y
  assert_success
  run ddev restart -y
  assert_success
  check_copilot_cli
}

seed_mirror_checks() {
  # Verify host config is mounted in the seed area and copied into writable runtime paths
  run ddev exec "grep -F 'test-hosts' ~/.cred-seed/gh/hosts.yml"
  assert_success
  run ddev exec "grep -F 'test-hosts' ~/.config/gh/hosts.yml"
  assert_success

  run ddev exec "grep -F '\"test\":true' ~/.cred-seed/copilot/config.json"
  assert_success
  run ddev exec "grep -F '\"test\":true' ~/.copilot/config.json"
  assert_success

  # Verify restart-time mirroring deletes container-only files
  run ddev exec "touch ~/.config/gh/container-only-${TEST_MARKER}.yml"
  assert_success
  run ddev exec "touch ~/.copilot/container-only-${TEST_MARKER}.json"
  assert_success

  run ddev restart -y
  assert_success

  run ddev exec "test ! -e ~/.config/gh/container-only-${TEST_MARKER}.yml"
  assert_success
  run ddev exec "test ! -e ~/.copilot/container-only-${TEST_MARKER}.json"
  assert_success
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  if [ -n "${TEST_BACKUP_GH_HOSTS}" ]; then
    cp "${TEST_BACKUP_GH_HOSTS}" "${TEST_HOST_GH_HOSTS}"
    rm -f "${TEST_BACKUP_GH_HOSTS}"
  elif [ -f "${TEST_HOST_GH_HOSTS}" ] && grep -qx "test-hosts" "${TEST_HOST_GH_HOSTS}" 2>/dev/null; then
    rm -f "${TEST_HOST_GH_HOSTS}"
  fi
  if [ -n "${TEST_BACKUP_COPILOT_CONFIG}" ]; then
    cp "${TEST_BACKUP_COPILOT_CONFIG}" "${TEST_HOST_COPILOT_CONFIG}"
    rm -f "${TEST_BACKUP_COPILOT_CONFIG}"
  elif [ -f "${TEST_HOST_COPILOT_CONFIG}" ] && grep -q '"test":true' "${TEST_HOST_COPILOT_CONFIG}" 2>/dev/null; then
    rm -f "${TEST_HOST_COPILOT_CONFIG}"
  fi
  # Persist TESTDIR if running inside GitHub Actions. Useful for uploading test result artifacts
  # See example at https://github.com/ddev/github-action-add-on-test#preserving-artifacts
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  prepare_host_copilot_config
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
  seed_mirror_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  prepare_host_copilot_config
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}
