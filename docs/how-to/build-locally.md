---
title: Build Locally with Makefile and Podman
description: Step-by-step guide to build and test the EE locally using podman and the project Makefile.
---

# Build Locally with Makefile and Podman

This guide shows how to build and test the Execution Environment (EE) fully on your machine. It uses `podman` as the container engine and the provided `Makefile` targets to keep commands consistent.

## Prerequisites

- `podman` installed and working (`podman --version`).
- `ansible-builder` and `ansible-navigator` installed.
- Optional for certified/private content: export `ANSIBLE_HUB_TOKEN`.

## Quick Start

```bash
# From the repo root
make lint            # yamllint checks
make token           # verifies ANSIBLE_HUB_TOKEN and pre-fetches collections
make build           # builds the EE image via ansible-builder
make list            # validate the image tag exists locally
make test            # runs files/playbook.yml inside the built image
```

## Environment Overrides

- `CONTAINER_ENGINE` defaults to `podman`. Example: `CONTAINER_ENGINE=podman make build`.
- `TARGET_NAME` and `TARGET_TAG` control the build tag. Example:

```bash
CONTAINER_ENGINE=podman TARGET_NAME=ansible-ee-minimal TARGET_TAG=v5 make build test
```

## Inspect and Debug

```bash
make info            # layers, versions, packages summary
make inspect         # container metadata via podman/inspect
make shell           # open a shell inside the image for manual checks
```

## Troubleshooting

- Token issues: Ensure `ANSIBLE_HUB_TOKEN` is exported before `make token build`.
- Network-restricted builds: add internal mirrors in `ansible.cfg` and copy via `additional_build_files` + `additional_build_steps`.
- Dependency errors: use `make shell` then run `pip check`, and validate system packages listed in `files/bindep.txt`.
- Fast validation: `ansible-navigator run files/playbook.yml --syntax-check --mode stdout`.

## Do and Don’t

- Do edit dependencies in `files/requirements.yml`, `files/requirements.txt`, and `files/bindep.txt`.
- Don’t overwrite `execution-environment.yml`; keep it minimal and declarative.
