---
title: Optional llms.txt Manifest
description: Declare LLM crawling preferences with an llms.txt file at the repo root.
---

# Optional llms.txt Manifest

Use an `llms.txt` file to declare how Large Language Models may crawl and use content from this repository.

When to use
- You want to signal allow/deny preferences for LLM ingestion of documentation and code.
- You publish this repo publicly and want a clear policy document in the root.

Steps
1) Install the CLI following the official guide: https://llmstxt.org/intro.html#cli
2) From the repo root, initialize a manifest (example only):
   - Decide which paths to allow (e.g., `docs/`, `README.md`).
   - Deny sensitive paths (e.g., `files/krb5.conf`, any credential samples).
3) Generate the file at the project root:
   - Example flow (adapt per the CLI docs):
     - Define intent and scope, then write to `llms.txt`.
4) Commit and review policy with your team.

Suggested content ideas
- Allow: `README.md`, `docs/**`
- Disallow: `files/**` that may include configs or secrets, temporary build logs, or private endpoints.

CI tip
- Add a lightweight check to ensure `llms.txt` exists and is non-empty on PRs touching `docs/` or `README.md`.

Outcome
- A documented `llms.txt` policy at the repo root and optional CI guardrails.
