# AGENTS.md

## Project Overview

**ddev-assistant-copilot** is a DDEV add-on that installs GitHub Copilot CLI into the DDEV web container and seeds the host user's GitHub CLI and Copilot configuration into the container without any additional setup. The host `~/.config/gh/` and `~/.copilot/` directories are mounted read-only under `~/.cred-seed/gh/` and `~/.cred-seed/copilot/` and mirrored into the writable in-container runtime directories on every start.

- **DDEV version requirement**: >= v1.24.0
- **Repository**: `e0ipso/ddev-assistant-copilot`

## Architecture

- `install.yaml` — DDEV add-on manifest; declares project files and version constraints
- `config.assistant-copilot.yaml` — DDEV hooks: **pre-start** (`exec-host`) ensures the host user's `~/.config/gh/` and `~/.copilot/` directories exist; **post-start** (`exec`) deletes stale in-container config content, copies the read-only seeds into writable runtime `~/.config/gh/` and `~/.copilot/`, fixes ownership, locks down credential permissions, installs `@github/copilot` via npm on every start, and wires `PATH` plus `COPILOT_GITHUB_TOKEN` (from `gh auth token`) into shell startup files and `/etc/bash.env`
- `docker-compose.assistant-copilot.yaml` — Bind-mounts the host user's `~/.config/gh/` and `~/.copilot/` directories read-only under `~/.cred-seed/gh/` and `~/.cred-seed/copilot/`; the container never live-mounts individual config files into the runtime directories
- `web-build/Dockerfile.assistant-copilot` — Installs GitHub CLI (`gh`) from the official apt repository so it is on `$PATH` for every shell type; sets `BASH_ENV=/etc/bash.env` so non-interactive `ddev exec` shells receive PATH and token exports from the post-start hook
- `.devcontainer/` — Local development container (Node.js 24, bats, shellcheck, GitHub CLI, Copilot CLI)
- `tests/test.bats` — BATS integration tests
- `.github/workflows/tests.yml` — CI using `ddev/github-action-add-on-test@v2`, matrix: DDEV `stable` + `HEAD`

## Testing

Tests use [BATS](https://bats-core.readthedocs.io/) (Bash Automated Testing System) with bats-assert, bats-file, and bats-support libraries.

```bash
# Run all tests
bats ./tests/test.bats

# Exclude release tests (for local development)
bats ./tests/test.bats --filter-tags '!release'

# Debug mode
bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure
```

Tests spin up a temporary DDEV project (`test-ddev-assistant-copilot`), install the add-on, and verify:
1. `ddev launch` works
2. `gh` resolves on `$PATH` and `gh --version` works via non-interactive `ddev exec`
3. `copilot` resolves on `$PATH` and `copilot --version` works when npm install succeeds (skipped if network/npm install fails)
4. Host config mounts under `~/.cred-seed/gh/` and `~/.cred-seed/copilot/` and mirrors into writable `~/.config/gh/` and `~/.copilot/`
5. Runtime config directories are owned by the web user (not `root`)
6. Container-only config files are deleted on restart because the host seed is authoritative
7. Copilot CLI remains on `$PATH` after consecutive restarts

The `install from release` test (tagged `@release`) installs from GitHub releases; skip it locally with `--filter-tags '!release'`.

## Development Notes

- **BATS tests must be run on the host machine**, not inside the devcontainer — they require DDEV, which manages Docker containers and cannot run inside a container itself
- This is primarily a shell/Docker project — no application-level package manager for the main code
- The `test_env/` directory contains npm-managed bats dependencies (gitignored)
- Commits use conventional commit format (e.g., `feat:`, `fix:`)
- CI runs on PRs, pushes to main, and daily at 08:25 UTC
- `.gitattributes` excludes tests, `.github/`, and docs from release archives
