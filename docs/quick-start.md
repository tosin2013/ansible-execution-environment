# Quick Start Guide: Ansible Execution Environment

This guide will help you quickly get started with building and using our Ansible Automation Platform 2.5 execution environments.

## Prerequisites

- Red Hat subscription (for AAP 2.5 base images)
- Podman, Buildah, and Skopeo installed
- Access to registry.redhat.io

## Environment Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd ansible-execution-environment
   ```

2. Copy and configure environment variables:
   ```bash
   cp .env-example .env
   # Edit .env with your registry credentials
   ```

3. Review and customize `ee-variables.yml`:
   - Verify base image settings
   - Check dependency configurations
   - Adjust tool installations as needed

## Building an Example Environment

We provide three validated example environments:

### OpenShift Virtualization Environment
```bash
# Set required variables
export EE_EXAMPLE=openshift_virt

# Build the environment
ansible-builder build -f execution-environment.yml -t my-ee-openshift:latest
```

### AWS Cloud Environment
```bash
# Set required variables
export EE_EXAMPLE=aws_cloud

# Build the environment
ansible-builder build -f execution-environment.yml -t my-ee-aws:latest
```

### Google Cloud Environment
```bash
# Set required variables
export EE_EXAMPLE=gcp_cloud

# Build the environment
ansible-builder build -f execution-environment.yml -t my-ee-gcp:latest
```

## Validation

Each example includes validation steps:
1. Required tools check
2. Registry access verification
3. Dependency validation

Run the validation script:
```bash
./files/testing/verify_example.sh ${EE_EXAMPLE}
```

## Environment Variables

Override default settings using environment variables:
- `EE_REGISTRY_USERNAME`: Registry authentication username
- `EE_REGISTRY_PASSWORD`: Registry authentication password
- `EE_BASE_IMAGE`: Override the base image
- `EE_EXAMPLE`: Select which example environment to build

## Next Steps

1. Review the full documentation in `docs/`
2. Check example playbooks in `examples/`
3. Explore customization options in `ee-variables.yml`

## Troubleshooting

Common issues and solutions:
1. Registry authentication failures:
   - Verify credentials in `.env`
   - Check registry access

2. Build failures:
   - Ensure all required tools are installed
   - Verify network access to required registries
   - Check system requirements match bindep.txt

3. Missing dependencies:
   - Review requirements files for your chosen example
   - Ensure all collections are accessible

For more detailed information, consult the full documentation or open an issue on GitHub. 