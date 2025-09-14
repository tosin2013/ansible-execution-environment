# Repository Guidelines

## Project Structure & Module Organization
- Root: `Makefile`, `execution-environment.yml`, `ansible-navigator.yml`.
- Dependencies: `files/requirements.yml` (collections), `files/requirements.txt` (Python), `files/bindep.txt` (system pkgs), plus sample `files/playbook.yml`.
- Docs: `docs/` (Diátaxis style: tutorials/how-to/reference/explanation) with `mkdocs.yml`.
- CI: `.github/workflows/yamllint.yml` for YAML linting.

## Build, Test, and Development Commands
- `make clean` — remove build artifacts and prune images.
- `make token` — verify `ANSIBLE_HUB_TOKEN` and pre-fetch collections.
- `make build` — build the EE image via `ansible-builder`.
- `make test` — run `files/playbook.yml` with `ansible-navigator` against the built image.
- `make inspect` — container metadata; `make info` — layers, versions, packages.
- `make publish` — push image to `TARGET_HUB`; `make shell` — open a shell in the image.
Environment: export `ANSIBLE_HUB_TOKEN`. Optional overrides: `TARGET_NAME`, `TARGET_TAG`, `CONTAINER_ENGINE` (podman), `TARGET_HUB`.
Example: `CONTAINER_ENGINE=podman TARGET_TAG=v5 make build test`.

## Coding Style & Naming Conventions
- YAML: 2-space indent, no tabs, lowercase keys with hyphens; files end with `.yml`.
- Keep `execution-environment.yml` minimal; add deps to `files/*` instead of inline.
- Docs: concise Markdown; relative links under `docs/`.
- Make targets: lowercase, verbs (e.g., `build`, `test`).

## Testing Guidelines
- Lint: `make lint` (yamllint). CI runs on push/PR.
- Validate builds with `make test`; for fast checks use: `ansible-navigator run files/playbook.yml --syntax-check --mode stdout`.
- Prefer small, reversible changes; test with `podman` locally.

## Commit & Pull Request Guidelines
- Commits: short, imperative subject; include scope when helpful. Examples: `fix: update bindep openssl-devel`, `docs: clarify publish steps`.
- PRs include: description of change, rationale, sample command(s) used, image tag produced, and `make test` output snippet. Link related issues and update `docs/` when behavior changes.

## Security & Configuration Tips
- Do not commit secrets (e.g., `ANSIBLE_HUB_TOKEN`, kubeconfigs). Use env vars and local config mounts.
- For private mirrors, adjust `ansible.cfg` and pip/yum config via `additional_build_steps` and mounted files.
- Use `podman` as the standard container engine in this repo and CI.

## Agent-Specific Instructions
- Scope: entire repo. Preserve file layout and target names.
- When adding dependencies, update `files/requirements*.{yml,txt}` and `files/bindep.txt` accordingly.
- Before opening a PR, run: `make lint build test`.
