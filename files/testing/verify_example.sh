#!/bin/bash

# Automated verification script for execution environment examples
# This script performs basic validation and testing of example configurations

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
EXAMPLE_NAME=""
VERBOSE=false
EE_VARIABLES="ee-variables.yml"

# Help message
usage() {
    echo "Usage: $0 -e <example_name> [-v]"
    echo "  -e: Name of example to verify (openshift_virt, aws_cloud, or gcp_cloud)"
    echo "  -v: Verbose output"
    exit 1
}

# Parse arguments
while getopts "e:v" opt; do
    case $opt in
        e) EXAMPLE_NAME="$OPTARG" ;;
        v) VERBOSE=true ;;
        *) usage ;;
    esac
done

if [ -z "$EXAMPLE_NAME" ]; then
    usage
fi

log() {
    local level=$1
    shift
    case $level in
        INFO) echo -e "${GREEN}[INFO]${NC} $*" ;;
        WARN) echo -e "${YELLOW}[WARN]${NC} $*" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $*" ;;
    esac
}

# Check 1: YAML Syntax
check_yaml_syntax() {
    log INFO "Checking YAML syntax for $EE_VARIABLES"
    # Create temporary yamllint config
    cat > /tmp/yamllint.yml <<EOF
extends: relaxed
rules:
  line-length:
    max: 120
    allow-non-breakable-words: true
    allow-non-breakable-inline-mappings: true
  trailing-spaces: enable
  new-line-at-end-of-file: enable
EOF
    if ! yamllint -c /tmp/yamllint.yml "$EE_VARIABLES"; then
        log ERROR "YAML syntax check failed"
        rm -f /tmp/yamllint.yml
        return 1
    fi
    rm -f /tmp/yamllint.yml
    log INFO "YAML syntax check passed"
}

# Check 2: Required Fields
check_required_fields() {
    log INFO "Checking required fields for example: $EXAMPLE_NAME"
    local missing=false
    
    # Check base configuration
    for field in ".base_image.name" ".package_manager.path"; do
        if ! yq --yaml-output "$field" "$EE_VARIABLES" > /dev/null 2>&1; then
            log ERROR "Missing required field: ${field#.}"
            missing=true
        fi
    done
    
    # Check example specific configuration
    local example_path=".example_environments.${EXAMPLE_NAME}"
    for field in ".dependencies.galaxy" ".dependencies.python" ".dependencies.system" ".validation.required_tools" ".validation.required_access"; do
        if ! yq --yaml-output "${example_path}${field}" "$EE_VARIABLES" > /dev/null 2>&1; then
            log ERROR "Missing required field for example ${EXAMPLE_NAME}: ${field#.}"
            missing=true
        fi
    done
    
    if [ "$missing" = true ]; then
        return 1
    fi
    log INFO "Required fields check passed"
}

# Check 3: Required Tools
check_required_tools() {
    log INFO "Checking required tools for example: $EXAMPLE_NAME"
    local missing=false
    
    # Get required tools from ee-variables.yml
    local tools
    tools=$(yq --yaml-output ".example_environments.${EXAMPLE_NAME}.validation.required_tools[]" "$EE_VARIABLES")
    
    for tool in $tools; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log ERROR "Required tool not found: $tool"
            missing=true
        else
            log INFO "Found required tool: $tool"
        fi
    done
    
    if [ "$missing" = true ]; then
        return 1
    fi
    log INFO "Required tools check passed"
}

# Check 4: Dependencies
check_dependencies() {
    log INFO "Checking dependencies for example: $EXAMPLE_NAME"
    
    # Get dependency files from ee-variables.yml
    local galaxy_file
    local python_file
    local system_file
    
    galaxy_file=$(yq --yaml-output ".example_environments.${EXAMPLE_NAME}.dependencies.galaxy" "$EE_VARIABLES")
    python_file=$(yq --yaml-output ".example_environments.${EXAMPLE_NAME}.dependencies.python" "$EE_VARIABLES")
    system_file=$(yq --yaml-output ".example_environments.${EXAMPLE_NAME}.dependencies.system" "$EE_VARIABLES")
    
    # Check files exist
    for file in "$galaxy_file" "$python_file" "$system_file"; do
        if [ ! -f "$file" ]; then
            log ERROR "Dependency file not found: $file"
            return 1
        fi
    done
    
    # Check Python dependencies
    if [ -f "$python_file" ]; then
        log INFO "Validating Python requirements from $python_file"
        if ! pip check > /dev/null 2>&1; then
            log ERROR "Python dependencies have conflicts"
            return 1
        fi
    fi
    
    # Check system packages
    if [ -f "$system_file" ]; then
        log INFO "Validating system dependencies from $system_file"
        if ! bindep -b > /dev/null 2>&1; then
            log WARN "Some system dependencies may be missing"
        fi
    fi
    
    log INFO "Dependencies check passed"
}

# Check 5: Registry Access
check_registry_access() {
    log INFO "Checking registry access for example: $EXAMPLE_NAME"
    local missing=false
    
    # Get required registries from ee-variables.yml
    local registries
    registries=$(yq --yaml-output ".example_environments.${EXAMPLE_NAME}.validation.required_access[]" "$EE_VARIABLES")
    
    for registry in $registries; do
        if ! podman login "$registry" >/dev/null 2>&1; then
            log ERROR "Cannot access registry: $registry"
            missing=true
        else
            log INFO "Successfully authenticated with registry: $registry"
        fi
    done
    
    if [ "$missing" = true ]; then
        return 1
    fi
    log INFO "Registry access check passed"
}

# Check 6: Build Test
test_build() {
    log INFO "Testing example build"
    
    # Extract base image
    local base_image
    base_image=$(yq --yaml-output ".base_image.name" "$EE_VARIABLES" | tr -d '\n')
    
    if ! podman pull "$base_image"; then
        log ERROR "Failed to pull base image: $base_image"
        return 1
    fi
    
    log INFO "Successfully pulled base image: $base_image"
}

# Main verification process
main() {
    local failed=false
    
    # Run all checks
    check_yaml_syntax || failed=true
    check_required_fields || failed=true
    check_required_tools || failed=true
    check_dependencies || failed=true
    check_registry_access || failed=true
    test_build || failed=true
    
    if [ "$failed" = true ]; then
        log ERROR "Verification failed for example: $EXAMPLE_NAME"
        exit 1
    fi
    
    log INFO "All verification checks passed for example: $EXAMPLE_NAME"
}

main 