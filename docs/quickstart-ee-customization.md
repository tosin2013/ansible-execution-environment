# Quick Start Guide: Customizing Your Execution Environment

This guide will help you customize the execution environment for your specific needs using the `ee-variables.yml` configuration file.

## Prerequisites

- Access to a container registry (e.g., registry.redhat.io, registry.access.redhat.com)
- Ansible Builder installed (`pip install ansible-builder`)
- Docker or Podman installed

## Basic Usage

1. **Copy the Variables Template**
   ```bash
   cp ee-variables.yml my-ee-variables.yml
   ```

2. **Configure Base Image**
   ```yaml
   base_image:
     name: "registry.access.redhat.com/ubi9/ubi-minimal:latest"
     auth:
       enabled: true
       username: "${EE_REGISTRY_USERNAME}"  # Set these environment variables
       password: "${EE_REGISTRY_PASSWORD}"  # or modify directly
   ```

3. **Choose Package Manager**
   ```yaml
   package_manager:
     path: "/usr/bin/dnf"  # Change if using a different package manager
     options: "--nodocs"    # Customize installation options
   ```

4. **Configure Dependencies**
   ```yaml
   dependencies:
     galaxy:
       file: "my-collections.yml"  # Your Galaxy requirements
     python:
       file: "my-requirements.txt" # Your Python requirements
     system:
       file: "my-bindep.txt"      # Your system package requirements
   ```

5. **Enable/Disable Tools**
   ```yaml
   tools:
     azure_cli:
       enabled: false  # Disable tools you don't need
     packer:
       enabled: true
       version: "1.8.5"  # Pin to specific versions
   ```

## Environment Variables

You can override certain settings using environment variables:

- `EE_REGISTRY_USERNAME`: Registry authentication username
- `EE_REGISTRY_PASSWORD`: Registry authentication password
- `ANSIBLE_GALAXY_CLI_COLLECTION_OPTS`: Galaxy CLI options

## Common Customization Scenarios

### 1. Minimal Installation
```yaml
tools:
  azure_cli:
    enabled: false
  packer:
    enabled: false
  openscap:
    enabled: false

build_steps:
  prepend_base:
    system_info: false
  append_final:
    cleanup_cache: true
```

### 2. Development Environment
```yaml
package_manager:
  options: ""  # Keep documentation and weak dependencies

build_steps:
  prepend_base:
    system_info: true
    environment_check: true
  append_final:
    verify_dependencies: true
    cleanup_cache: false  # Keep cache for faster rebuilds
```

### 3. Production Environment
```yaml
base_image:
  name: "registry.redhat.io/ansible-automation-platform-24/ee-minimal-rhel9:latest"

package_manager:
  options: "--nodocs --setopt install_weak_deps=0"

build_steps:
  append_final:
    verify_dependencies: true
    cleanup_cache: true
```

## Next Steps

- Review the full configuration options in `ee-variables.yml`
- Check the troubleshooting guide for common issues
- Explore example configurations in the `examples/` directory

## Need Help?

- Check our troubleshooting guide
- Review the ADR-0007 for design decisions
- Open an issue for bug reports or feature requests 