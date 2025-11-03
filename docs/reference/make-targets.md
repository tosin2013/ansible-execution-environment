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
- `docs-setup`/`docs-build`/`docs-serve`/`docs-test` — local docs workflows.
- `setup-openshift-tarball` — setup Path B (tarball) configuration.
- `build-openshift-tarball` — build with Path B (tarball install).
- `test-openshift-tarball` — build and test Path B.
- `setup-openshift-rhsm` — setup Path A (RHSM) configuration.
- `build-openshift-rhsm` — build with Path A (RHSM/RPM install).
- `test-openshift-rhsm` — build and test Path A.
- `test-openshift-tooling` — test OpenShift/Kubernetes tooling in built image.

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

### OpenShift/Kubernetes Tooling

The project supports two paths for installing OpenShift/Kubernetes tooling, tested separately to avoid conflicts:

**Path A — RHSM/RPM install (requires RHSM entitlements):**
```bash
# Create files/optional-configs/rhsm-activation.env with RH_ORG and RH_ACT_KEY
make setup-openshift-rhsm build-openshift-rhsm
# Or test it all at once:
make test-openshift-rhsm
```

**Path B — Tarball install (no RHSM required):**
```bash
# Automatically creates files/optional-configs/oc-install.env
make setup-openshift-tarball build-openshift-tarball
# Or test it all at once:
make test-openshift-tarball
```

**Test existing image:**
```bash
make test-openshift-tooling
```

See the [Enable Kubernetes and OpenShift Tooling](../how-to/enable-kubernetes-openshift.md) guide for details on the two-phase testing approach.
