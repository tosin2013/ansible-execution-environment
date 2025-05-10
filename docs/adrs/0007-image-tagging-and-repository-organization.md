# ADR 0007: Image Tagging and Repository Organization

## Status
Proposed

## Context
To ensure traceability, reproducibility, and avoid conflicts in CI/CD and multi-user environments, container images built for the Ansible Execution Environment must not use the generic `latest` tag for each run. Instead, each build should be tagged with a unique, descriptive identifier (e.g., timestamp, commit hash, or user-supplied value).

## Decision
- The `.env` file must define a `TARGET_TAG` variable that is set to a unique value for each run (not `latest`).
- The build and push scripts must use this tag for all image operations.
- The tag can be generated automatically (e.g., using the current date/time or a CI build number) or provided by the user.
- The `TARGET_NAME` and `TARGET_TAG` variables together define the full image reference.
- Documentation and usage instructions must reflect this tagging strategy.

## Consequences
- All images are uniquely identifiable and traceable to a specific build or test run.
- No accidental overwrites or confusion from using the `latest` tag.
- CI/CD and multi-user workflows are more robust and auditable.

---

> Example: In `.env`, set `TARGET_TAG=2025-05-09T12-00-00` or similar for each run.
