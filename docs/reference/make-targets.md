---
title: Make Targets and Variables
description: Reference for Makefile targets, environment variables, and common usage.
---

# Make Targets and Variables

The Makefile orchestrates build, test, and publish tasks.

## Targets

- `clean` — remove build artifacts and prune images.
- `lint` — run yamllint.
- `token` — render `ansible.cfg` from template and pre-fetch collections (validates `ANSIBLE_HUB_TOKEN`).
- `build` — build the EE via `ansible-builder`.
- `inspect` — `podman inspect` the built image.
- `list` — list the built image (`podman images --filter reference=...`).
- `info` — show layers, Ansible version, collections, pip packages, rpm list.
- `test` — run `files/playbook.yml` via `ansible-navigator` using the built image.
- `publish` — tag and push to `TARGET_HUB`.
- `shell` — open a shell in the image.
- `docs-setup`/`docs-build`/`docs-serve` — local docs workflows.

## Variables

- `TARGET_NAME` — image name (default: `ansible-ee-minimal`).
- `TARGET_TAG` — image tag (default: `v5`).
- `CONTAINER_ENGINE` — container runtime (default: `podman`).
- `VERBOSITY` — ansible-builder verbosity level.
- `TARGET_HUB` — registry for `publish`.

Environment requirements:
- `ANSIBLE_HUB_TOKEN` — required; used to access Automation Hub/validated content.

## Common Invocations

```bash
# Clean rebuild
make clean build

# Build with explicit container engine and tag
CONTAINER_ENGINE=podman TARGET_TAG=v5 make build

# Build then test
make build test

# Publish to quay.io/your-namespace
TARGET_HUB=quay.io TARGET_NAME=your-namespace/ansible-ee make publish
```

## Optional Config Flows

- RHSM activation (RPM path):
  - Create `files/optional-configs/rhsm-activation.env` with `RH_ORG`/`RH_ACT_KEY`.
  - `make build`

- oc/kubectl tarball (repo-free path):
  - Create `files/optional-configs/oc-install.env` with `OC_VERSION` (e.g., `stable-4.19`).
  - `make build`
