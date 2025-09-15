---
title: Troubleshoot EE Builds
description: Common build errors, causes, and quick fixes for Execution Environment images.
---

# Troubleshoot EE Builds

Use this checklist when `make build` fails or images don’t behave as expected.

## Quick Triage

- Inspect logs: `tail -n 200 ansible-builder.log`
- Rebuild clean: `make clean && make build`
- Verify env: `echo $ANSIBLE_HUB_TOKEN`, `podman login registry.redhat.io`
- Fast validate: `ansible-navigator run files/playbook.yml --syntax-check --mode stdout`

## Common Errors and Fixes

### No package matches 'openshift-clients'

Cause: `kubernetes.core` (or related) adds a bindep on `openshift-clients` for RHEL; the base image lacks the OCP repo.

Fix options:
- With entitlements (RPM path): add `files/optional-configs/rhsm-activation.env` (RH_ORG/RH_ACT_KEY) and rebuild.
- Without entitlements: add `files/optional-configs/oc-install.env` (e.g., `OC_VERSION=stable-4.19`) to install `oc`/`kubectl` from tarball; rebuild.
- Temporarily comment out collections that pull in `kubernetes.core` in `files/requirements.yml`.

### RHSM “Not Subscribed” / No repositories available

Cause: The activation key registers but does not attach a pool that includes the OCP client repo.

Fix:
- Ensure your activation key auto-attaches a valid OCP pool, or provide a pool ID and attach explicitly (not covered here).
- Or use the tarball approach for `oc`.

### curl vs curl-minimal conflict

Symptom: microdnf reports conflicts when installing curl.

Fix:
- We attempt `($PKGMGR -y install curl tar || true)` in the tarball path. If needed, prefer `curl-minimal` (already present on UBI) and skip `curl`.
- Build still proceeds because the download usually succeeds.

### Pip cannot find ansible-core version

Cause: Base image Python version may not match latest ansible-core.

Fix:
- Pin a compatible version in `execution-environment.yml` under `dependencies.ansible_core` (example: `2.15.13`).
- Rebuild and verify `ansible --version` in `make info`.

### Galaxy/Hub auth issues

Symptom: `ansible-galaxy` download errors.

Fix:
- Confirm `ANSIBLE_HUB_TOKEN` is exported: `export ANSIBLE_HUB_TOKEN=$(cat token)`.
- Regenerate `ansible.cfg`: `make token` or remove and rebuild.

### Corporate proxies / timeouts

Fix:
- Export `HTTP_PROXY`/`HTTPS_PROXY` during `make build`.
- If proxies are mandatory, add a proxy-aware curl step in `additional_build_steps` or mount config files via `additional_build_files`.

### Which collection requires OCP?

Identify:
```
tmp=$(mktemp -d)
ansible-galaxy collection download -r files/requirements.yml -p "$tmp"
rg -n "openshift-clients" "$tmp"/**/bindep.txt
```

## When to ask for help

- Share the last 100–200 lines of `ansible-builder.log` and your `files/requirements.yml` diff.
- Include your chosen path (RPM vs tarball) and whether proxies are in use.

