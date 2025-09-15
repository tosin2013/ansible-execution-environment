---
title: Enable Kubernetes and OpenShift Tooling
description: Two supported paths to include kubernetes.core/redhat.openshift collections and oc/kubectl in your EE.
---

# Enable Kubernetes and OpenShift Tooling

This guide shows how to enable Kubernetes/OpenShift modules and include the `oc`/`kubectl` CLIs in your Execution Environment (EE).

Supported approaches:
- Path A (RPM via RHSM): enable Red Hat repos and install `openshift-clients` via RPM.
- Path B (Tarball, no RHSM): install `oc`/`kubectl` from the official tarball and bypass the RPM dependency.

## Prerequisites

- Working local build per the Build Locally guide.
- Optional RHSM entitlements for Path A.

## Step 1: Choose your path

### Path A — RPM install (requires RHSM entitlements)

Use this if you can attach an OpenShift client repo subscription during build.

1) Create `files/optional-configs/rhsm-activation.env` with your org/key:

```
RH_ORG=<your_org>
RH_ACT_KEY=<your_activation_key>
```

2) Uncomment collections in `files/requirements.yml` as needed:

```
# containers
- name: kubernetes.core
# - name: redhat.openshift
```

3) Build:

```
export ANSIBLE_HUB_TOKEN=$(cat token)
make build
```

What happens:
- The build registers with RHSM, attempts auto-attach, enables an `rhocp-4.15` or `4.14` repo (by arch), and installs `openshift-clients`.
- On cleanup, RHSM registration is removed.

Notes:
- Your activation key must attach a subscription that includes the OpenShift client repo. If not, the repo enable step is skipped.

### Path B — Tarball install (no RHSM required)

Use this if you do not have RHSM entitlements or want a simpler, portable build.

1) Create `files/optional-configs/oc-install.env` with a pinned version:

```
# Tracks latest in the 4.19 stream; or pin to an exact tag like v4.19.6
OC_VERSION=stable-4.19
```

2) Uncomment collections in `files/requirements.yml` as needed:

```
# containers
- name: kubernetes.core
# - name: redhat.openshift
```

3) Build:

```
export ANSIBLE_HUB_TOKEN=$(cat token)
make build
```

What happens:
- The build downloads `openshift-client-linux.tar.gz` from mirror.openshift.com for the requested version and installs `oc` and `kubectl` into `/usr/local/bin`.
- The EE intentionally filters the `openshift-clients` RPM from bindep to avoid failing without RHSM.

## Step 2: Verify

```
podman run --rm ansible-ee-minimal:v5 which oc kubectl
podman run --rm ansible-ee-minimal:v5 oc version --client
ansible-navigator collections --mode stdout --eei ansible-ee-minimal:v5 | grep kubernetes.core
```

## Troubleshooting

- Missing `openshift-clients` error during build:
  - Path A: your activation key didn’t attach an OCP entitlement; add an attach pool or use Path B.
  - Path B: ensure `files/optional-configs/oc-install.env` exists and is valid; rebuild.
- Corporate proxies: export `HTTP_PROXY`/`HTTPS_PROXY` for the build, or configure `additional_build_steps` to set them.

## Notes and Best Practices

- Pin `OC_VERSION` to your cluster’s major/minor (e.g., `v4.19.6`) for reproducibility.
- If you later adopt RHSM RPM install, remove `oc-install.env` to avoid duplicate installs.
- Upgrading ansible-builder: we override the builder’s `assemble`/`install-from-bindep` via `additional_build_files` to filter `openshift-clients`. Review these overrides when changing ansible-builder versions.

