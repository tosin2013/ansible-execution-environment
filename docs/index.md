# Ansible Execution Environment Documentation

Welcome to the documentation for the Ansible Execution Environment (EE) builder project.

Why this documentation: to give new and advanced users actionable, task-focused guides and the background needed to make sound design decisions with EEs.

## What is an Execution Environment?

In modern automation, a common challenge is ensuring that your Ansible Playbooks run reliably everywhere. An automation might work on your laptop but fail in a CI/CD pipeline because of a different version of Python, a missing library, or an incompatible Ansible Collection.

An **Execution Environment** solves this problem. It is a self-contained container image that packages everything your automation needs to run:

-   A specific version of Ansible
-   Specific versions of Python packages
-   Required Ansible Collections
-   Any necessary system-level libraries or tools

By running your playbooks inside an EE, you guarantee a consistent, predictable, and portable environment for your automation, no matter where it runs.

## Why Use This Project?

While you can build Execution Environments from scratch, this repository provides a framework to make the process standardized, repeatable, and easy to customize.

-   **For New Users:** It provides a "batteries-included" starting point. You can simply edit a few text files to define your dependencies, run `make build`, and get a working EE without needing to be an expert in containerization.
-   **For Advanced Users:** It offers a flexible and powerful way to manage the entire lifecycle of your EEs. The `Makefile` provides hooks to clean, build, test, inspect, and publish your images, and the configuration files offer deep customization options.

This documentation will guide you through understanding, using, and extending this framework.

## 📚 Learning-Oriented: Tutorials

Start here to build your first custom Execution Environment.
- [Getting Started with Execution Environments](tutorials/getting-started.md)
Who this is for: new users; outcome: a working EE build.

## 🔧 Task-Oriented: How-To Guides

Practical guides for specific tasks and more advanced usage.
- [How to Test Your Execution Environment](how-to/testing-execution-environment.md)
- [How to Add Windows Support](how-to/add-windows-support.md)
- [Build Locally with Makefile and Podman](how-to/build-locally.md)
- [Enable Kubernetes and OpenShift Tooling](how-to/enable-kubernetes-openshift.md)
- [Troubleshoot EE Builds](how-to/troubleshoot-ee-builds.md)
- [Advanced Usage Guide](how-to/advanced-usage.md)
- [CI/CD with GitHub Actions and Tekton](how-to/ci-cd.md)
- [Optional llms.txt Manifest](how-to/llms-txt.md)
- [Build Docs Locally (MkDocs)](how-to/build-docs-locally.md)
Who this is for: practitioners executing tasks; outcome: one concrete result per guide.

## 📖 Information-Oriented: Reference

Detailed technical reference for the tools and configuration.
- [Optional Configs and Secrets](reference/optional-configs-and-secrets.md)
- [Make Targets and Variables](reference/make-targets.md)
- [execution-environment.yml Reference](reference/execution-environment-yaml.md)
- [Tooling Reference](reference/tooling.md)
Who this is for: readers needing exact options and commands.

## 💡 Understanding-Oriented: Explanation

Conceptual documentation to understand the underlying architecture and design.
- [Execution Environment Concepts](explanation/concepts.md)
- [Technology Stack](explanation/technology-stack.md)
- [Design Decisions](explanation/design-decisions.md)
- [Why Keep execution-environment.yml Minimal](explanation/execution-environment-yaml-design.md)
Who this is for: decision-makers and maintainers; outcome: understand trade-offs and rationale.
