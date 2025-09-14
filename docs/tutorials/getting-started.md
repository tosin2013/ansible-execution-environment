---
title: Getting Started with Execution Environments
---

# Getting Started with Execution Environments

This tutorial provides a step-by-step guide to building a custom Ansible Execution Environment using this repository.

## Prerequisites

- A build server with `podman` and `git` installed. The `files/provision.sh` script can be used to prepare a RHEL-based system.
- An `ANSIBLE_HUB_TOKEN` environment variable must be set to authenticate with the Red Hat Automation Hub for downloading certified collections. This is not required for public collections from Ansible Galaxy.

## Step 1: Clone the Repository

Begin by cloning this repository to your build server.

```bash
git clone https://github.com/tosin2013/ansible-execution-environment.git
cd ansible-execution-environment
```

## Step 2: Customize Dependencies

The core of your execution environment is defined by its dependencies.

### Ansible Collections

Edit `files/requirements.yml` to specify the Ansible Collections you need. This project includes several by default, such as:

```yaml
collections:
  - name: amazon.aws # For AWS automation
  - name: azure.azcollection # For Azure automation
  - name: community.general # A general collection of modules
  # - name: community.windows # Uncomment for Windows automation
```

### Python Packages

Edit `files/requirements.txt` to add any Python packages your collections or playbooks require. For example, this project includes `ara` for reporting.

```
# For reporting
ara

# Uncomment the following for Windows automation
# pywinrm>=0.3.0
```

### System-Level Dependencies

Edit `files/bindep.txt` for any system-level packages. These are often required for Python packages that compile from source. For example, `libcurl-devel` is included for `pycurl`.

```
dnf   [platform:rpm]
git   [platform:rpm]
# Uncomment the following for Kerberos support with Windows automation
# krb5-libs [platform:rpm]
# krb5-workstation [platform:rpm]
```

## Step 3: Configure the Build

The `execution-environment.yml` file defines the build process. The default base image is:

```yaml
images:
  base_image:
    name: 'registry.redhat.io/ansible-automation-platform-25/ee-minimal-rhel9:latest'
```

You can change this to use a different base image if needed.

## Step 4: Build the Image

The `Makefile` provides a simple way to build the image. It will use `ansible-builder` to combine the base image with your specified dependencies.

```bash
make build
```
This will create a new container image. By default, as defined in the `Makefile`, this image will be tagged as `ansible-ee-minimal:v5`.

## Step 5: Test the Image

After the build, run the included test playbook.

```bash
make test
```

This command uses `ansible-navigator` to run `files/playbook.yml` inside the new execution environment, confirming it is functional.