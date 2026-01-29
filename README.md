pre-commit drawio auto-export
=============================

This pre-commit hook automatically exports [Draw.io](https://www.drawio.com/) (`.drawio`) files in repository into `.png` whenever you commit changes.

**Table of Contents:**

- [Installation](#installation)
- [Features](#features)
- [Requirements](#requirements)
- [Supported Platforms](#supported-platforms)
- [CI/CD Examples](#cicd-examples)
   * [GitHub](#github)
   * [Gitlab](#gitlab)
- [Acknowledgements](#acknowledgements)

## Installation

Add the hook to your `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/devon-thyne/pre-commit-drawio-auto-export.git
    rev: v1.0.0
    hooks:
      - id: drawio-auto-export
```

## Features

- Automatically detects all `.drawio` files within repository
- Exports diagram file(s) to `.png` using the draw.io CLI (AppImage for Linux, Desktop app for macOS)
  - Exports multi-paged diagram files as multiple `.png` image(s) each suffixed with the diagram page's name
- Fails if any files are generated net-new or modified
- Automatically stages changes to new or modified exported files

## Requirements

* BASH interpreter
* `exiftool`
* `xvfb` (linux only)
* `Draw.io Desktop` (macos only)

## Supported Platforms

### Linux
- [xvfb](https://linux.die.net/man/1/xvfb) must be installed.
- **Note:** the script will automatically download and cache the Draw.io AppImage if not already present.
  - path: `~/.cache/pre-commit/drawio`

### macOS
- [Draw.io Desktop](https://github.com/jgraph/drawio-desktop/releases) must be installed in `/Applications`.
- **Note:** exports briefly display the Draw.io icon in the Dock due to macOS constraints

### Windows
- **not supported**
- use windows subsystem for linux

## CI/CD Examples

> [!TIP]
> Suggest pre-building your own pre-commit docker image with the necessary dependencies

### GitHub

The following example demonstrates how to run this hook in GitHub Actions.
Trigger conditions (e.g. push, pull_request, branches) are intentionally left to the user.

```yaml
name: pre-commit

jobs:
  pre-commit:
    runs-on: ubuntu-latest

    container:
      image: python:3.11-bullseye

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Mark workspace as safe for git
        run: |
          export HOME=/github/home
          git config --global --add safe.directory "$GITHUB_WORKSPACE"

      - name: Install system dependencies
        run: |
          apt-get update
          apt-get install -y \
            libasound2 \
            libatk-bridge2.0-0 \
            libatk1.0-dev \
            libcups2 \
            libdbus-1-dev \
            libgbm1 \
            libgtk-3-0 \
            libimage-exiftool-perl \
            libnss3 \
            xvfb

      - name: Install pre-commit
        run: pip3 install pre-commit

      - name: Run pre-commit
        run: pre-commit run --all-files
```

### Gitlab

The following example demonstrates how to run this hook in GitLab CI/CD.
Pipeline triggers and execution rules (e.g. branches, merge requests) should be defined by the user.

```yaml
pre-commit:
  stage: pre-commit
  image: python:3.11-bullseye
  script:
    - apt update
    - |
      apt install -y \
        libasound2 \
        libatk-bridge2.0-0 \
        libatk1.0-dev \
        libcups2 \
        libdbus-1-dev \
        libgbm1 \
        libgtk-3-0 \
        libimage-exiftool-perl \
        libnss3 \
        xvfb
    - pip3 install pre-commit
    - pre-commit run --all-files
```

## Acknowledgements

This project was inspired by an early CI/CD-based Draw.io export workflow shared by a colleague. That initial work sparked the idea to formalize and extend the approach into a reusable, pre-commit–based tool with additional logic around change detection, local generation, and reproducibility.
