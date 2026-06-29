[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/e0ipso/ddev-assistant-copilot/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/e0ipso/ddev-assistant-copilot/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/e0ipso/ddev-assistant-copilot)](https://github.com/e0ipso/ddev-assistant-copilot/commits)
[![release](https://img.shields.io/github/v/release/e0ipso/ddev-assistant-copilot)](https://github.com/e0ipso/ddev-assistant-copilot/releases/latest)

# DDEV Assistant Copilot

## Overview

This add-on integrates Assistant Copilot into your [DDEV](https://ddev.com/) project.

## Installation

```bash
ddev add-on get e0ipso/ddev-assistant-copilot
ddev restart
```

After installation, make sure to commit the `.ddev` directory to version control.

## Usage

| Command | Description |
| ------- | ----------- |
| `ddev describe` | View service status and used ports for Assistant Copilot |
| `ddev logs -s assistant-copilot` | Check Assistant Copilot logs |

## Advanced Customization

To change the Docker image:

```bash
ddev dotenv set .ddev/.env.assistant-copilot --assistant-copilot-docker-image="ddev/ddev-utilities:latest"
ddev add-on get e0ipso/ddev-assistant-copilot
ddev restart
```

Make sure to commit the `.ddev/.env.assistant-copilot` file to version control.

All customization options (use with caution):

| Variable | Flag | Default |
| -------- | ---- | ------- |
| `ASSISTANT_COPILOT_DOCKER_IMAGE` | `--assistant-copilot-docker-image` | `ddev/ddev-utilities:latest` |

## Credits

**Contributed and maintained by [@e0ipso](https://github.com/e0ipso)**
