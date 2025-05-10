#!/bin/bash
set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Constants
DEFAULT_TIMEOUT=300  # 5 minutes default timeout
RETRY_MAX=3         # Maximum number of retry attempts
RETRY_DELAY=5       # Initial retry delay in seconds
DEFAULT_IMAGE="quay.io/ansible/ansible-runner:latest"  # Fallback image
TEST_RESULTS_DIR="${PROJECT_ROOT}/test_results"
TEST_LOG_FILE="${TEST_RESULTS_DIR}/test_execution.log"

# Determine Python command from system
PYCMD=$(command -v python3 || command -v python || echo "python3")
if ! command -v "$PYCMD" >/dev/null 2>&1; then
    log_error "No Python interpreter found in system"
    exit 1
fi

# Logging functions
log_info() { echo "[INFO] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
log_warn() { echo "[WARN] $*" >&2; }
log_debug() { [[ "${VERBOSE:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }

# Error handling with stage tracking
trap 'handle_error $? $LINENO "${CURRENT_STAGE:-unknown}"' ERR
CURRENT_STAGE=""

handle_error() {
    local exit_code=$1
    local line_no=$2
    local stage=$3
    log_error "Error in stage '$stage' at line $line_no (exit code: $exit_code)"
    cleanup_and_exit "$exit_code"
}

# Enhanced timeout execution
execute_with_timeout() {
    local timeout=${1:-$DEFAULT_TIMEOUT}
    local cmd=$2
    local fallback=${3:-""}
    local stage=${4:-"unknown"}
    
    CURRENT_STAGE="$stage"
    log_debug "Executing command with ${timeout}s timeout: $cmd"
    
    if $cmd; then
        return 0
    else
        local status=$?
        if [[ $status -eq 124 ]]; then  # timeout exit code
            log_warn "Command timed out after ${timeout}s"
            if [[ -n "$fallback" ]]; then
                log_info "Attempting fallback command"
                $fallback
                return $?
            fi
        fi
        return $status
    fi
}

# Collection verification with retries
verify_collections() {
    local required_collections=(
        "amazon.aws"
        "community.general"
        "ansible.posix"
        "kubernetes.core"
        "community.libvirt"
    )
    
    log_info "Verifying required collections"
    
    local missing_collections=()
    for collection in "${required_collections[@]}"; do
        if ! ansible-galaxy collection list | grep -q "$collection"; then
            missing_collections+=("$collection")
        fi
    done
    
    if [[ ${#missing_collections[@]} -eq 0 ]]; then
        log_info "All required collections are installed"
        return 0
    else
        log_warn "Missing collections: ${missing_collections[*]}"
        return 1
    fi
}

# Environment validation
validate_environment() {
    CURRENT_STAGE="environment-validation"
    log_info "Validating environment"
    
    # Check for required tools
    local required_tools=(
        "podman"
        "ansible-builder"
        "ansible-navigator"
        "python3"
        "ansible-galaxy"
    )
    
    local missing_tools=()
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    # Validate environment file
    if [[ ! -f "${PROJECT_ROOT}/.env" ]]; then
        if [[ -f "${PROJECT_ROOT}/.env-example" ]]; then
            log_warn "No .env file found, copying from .env-example"
            cp "${PROJECT_ROOT}/.env-example" "${PROJECT_ROOT}/.env"
        else
            log_error "No .env or .env-example file found"
            return 1
        fi
    fi
    
    # Source environment variables
    source "${PROJECT_ROOT}/.env"
    
    # Create test results directory
    mkdir -p "${TEST_RESULTS_DIR}"
    
    log_info "Environment validation complete"
    return 0
}

# Get available examples
get_available_examples() {
    local examples_dir="${PROJECT_ROOT}/examples"
    local examples=()
    
    # Find all .yml files in examples directory except README.md
    while IFS= read -r file; do
        # Extract filename without extension and path
        local name
        name=$(basename "$file" .yml)
        examples+=("$name")
    done < <(find "$examples_dir" -name "*.yml" ! -name "README.md")
    
    echo "${examples[@]}"
}

# Transform example config to ansible-builder format
transform_config() {
    local input_file="$1"
    local output_file="$2"
    
    # Extract base image with fixed yq syntax
    local base_image
    base_image=$(yq '.base_image.name' "$input_file")
    
    # Use default if yq fails
    if [ -z "$base_image" ] || [ "$base_image" = "null" ]; then
        base_image="registry.access.redhat.com/ubi9/ubi-minimal:latest"
        log_warn "Could not read base image from config, using default: $base_image"
    fi
    
    # Create ansible-builder compatible configuration with essential elements only
    cat > "$output_file" << EOF
---
version: 3

dependencies:
  ansible_core:
    package_pip: ansible-core==2.15.0
  ansible_runner:
    package_pip: ansible-runner>=2.3.1
  galaxy: requirements.yml
  python: requirements.txt
  system: bindep.txt

images:
  base_image:
    name: $base_image

additional_build_steps:
  prepend_base:
    - ENV PKGMGR=microdnf
    - RUN \$PKGMGR update -y && \$PKGMGR install -y python3 python3-pip python3-devel gcc make which
  prepend_galaxy:
    - RUN python3 -m pip install --upgrade pip setuptools wheel
  append_final:
    - RUN pip3 check
    - RUN \$PKGMGR clean all && rm -rf /var/cache/\$PKGMGR
EOF

    log_debug "Generated execution environment config at $output_file"
}

# Process example file
process_example_file() {
    CURRENT_STAGE="example-processing"
    local example_name="$1"
    local output_dir="${PROJECT_ROOT}/_build"
    local output_file="${output_dir}/execution-environment.yml"
    local example_file="${PROJECT_ROOT}/examples/${example_name}.yml"
    
    if [[ ! -f "$example_file" ]]; then
        log_error "Example file not found: $example_file"
        return 1
    fi
    
    log_info "Processing example file: $example_file"
    
    # Create build directories
    mkdir -p "${output_dir}/configs"
    
    # Transform the example config
    transform_config "$example_file" "$output_file"
    
    # Create minimal requirements.txt with only essential packages
    cat > "${output_dir}/requirements.txt" << EOF
ansible-core==2.15.0
ansible-runner>=2.3.1
pip>=21.0.1
setuptools>=41.0.0
wheel>=0.36.0
EOF

    # Create minimal requirements.yml with only essential collections
    cat > "${output_dir}/requirements.yml" << EOF
---
collections:
  - ansible.posix
  - community.general
EOF

    # Create minimal bindep.txt with only essential packages
    cat > "${output_dir}/bindep.txt" << EOF
python3-devel [compile]
gcc [compile]
EOF

    # Copy ansible.cfg if it exists
    if [[ -f "${PROJECT_ROOT}/ansible.cfg" ]]; then
        cp "${PROJECT_ROOT}/ansible.cfg" "${output_dir}/configs/"
    fi
    
    return 0
}

# Show usage information
show_usage() {
    local examples
    examples=$(get_available_examples)
    
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Options:
    -v, --verbose             Enable verbose output
    -e, --example NAME        Select example environment (default: minimal-ee)
    -p, --push               Push image to configured registries
    -h, --help               Show this help message

Available Examples:
$(for example in $examples; do echo "    - $example"; done)

Note: Image will be tagged for all registries configured in TARGET_REGISTRIES
      Use -p flag to also push the images to the registries
EOF
}

# Tag and optionally push image
tag_and_push_image() {
    local image_name="$1"
    local should_push="${2:-false}"
    
    # Source environment variables for registry info
    if [[ ! -f "${PROJECT_ROOT}/.env" ]]; then
        log_error "No .env file found"
        return 1
    fi
    source "${PROJECT_ROOT}/.env"
    
    # Get base name and tag
    local base_name
    base_name=$(echo "$image_name" | cut -d':' -f1)
    local tag="${image_name##*:}"

    # Process each registry
    IFS=',' read -ra REGISTRIES <<< "$TARGET_REGISTRIES"
    for registry in "${REGISTRIES[@]}"; do
        # Clean registry URL (remove potential trailing slash)
        registry="${registry%/}"
        
        # Handle internal registry
        if [[ "$registry" == "$INTERNAL_REGISTRY" ]]; then
            local remote_image="${registry}/${base_name}:${tag}"
            
            log_info "Tagging image for internal registry: $remote_image"
            if ! podman tag "$image_name" "$remote_image"; then
                log_error "Failed to tag image for internal registry"
                continue
            fi
            
            if [[ "$should_push" == "true" ]]; then
                log_info "Logging into internal registry: ${registry}"
                # Use the app credentials for internal registry
                if ! podman login -u "$INTERNAL_REGISTRY_USER" -p "$INTERNAL_REGISTRY_PASSWORD" "$registry"; then
                    log_error "Failed to authenticate with internal registry"
                    continue
                fi
                
                log_info "Pushing image to internal registry: $remote_image"
                if ! podman push "$remote_image"; then
                    log_error "Failed to push image to internal registry"
                fi
                
                # Logout for security
                podman logout "$registry" || log_warn "Failed to logout from internal registry"
            fi
        else
            # Handle external registry (e.g., Quay.io)
            # Extract registry base URL (e.g., quay.io from quay.io/takinosh)
            local registry_base="${registry%%/*}"
            local remote_image="${registry}/${base_name}:${tag}"
            
            log_info "Tagging image for registry: $remote_image"
            if ! podman tag "$image_name" "$remote_image"; then
                log_error "Failed to tag image for registry: $registry"
                continue
            fi
            
            if [[ "$should_push" == "true" ]]; then
                if [[ -n "${QUAY_USERNAME:-}" && -n "${QUAY_PASSWORD:-}" ]]; then
                    log_info "Logging into registry: ${registry_base}"
                    if ! podman login -u "$QUAY_USERNAME" -p "$QUAY_PASSWORD" "$registry_base"; then
                        log_error "Failed to authenticate with registry: $registry_base"
                        continue
                    fi
                    
                    log_info "Pushing image to registry: $remote_image"
                    if ! podman push "$remote_image"; then
                        log_error "Failed to push image to registry: $registry"
                    fi
                    
                    # Logout for security
                    podman logout "$registry_base" || log_warn "Failed to logout from registry: $registry_base"
                fi
            fi
        fi
    done
    
    return 0
}

# Build execution environment image
build_ee_image() {
    CURRENT_STAGE="image-build"
    local image_name="${1:-ansible-ee:latest}"
    local example_name="${2:-minimal-ee}"
    
    log_info "Building execution environment image: $image_name from example: $example_name"
    
    # Process example file first
    if ! process_example_file "$example_name"; then
        log_error "Example processing failed"
        return 1
    fi
    
    # Set context to build directory
    cd "${PROJECT_ROOT}/_build" || return 1
    
    if ! ansible-builder build -t "$image_name" -f execution-environment.yml --container-runtime podman; then
        log_error "Image build failed"
        return 1
    fi
    
    log_info "Image build completed successfully"
    return 0
}

# Run test playbook with proper logging
run_test_playbook() {
    CURRENT_STAGE="test-playbook"
    local playbook="${1:-playbooks/test.yml}"
    local image="${2:-ansible-ee:latest}"
    
    # Use absolute path for playbook
    if [[ ! "$playbook" = /* ]]; then
        playbook="${PROJECT_ROOT}/${playbook}"
    fi
    
    log_info "Running test playbook: $playbook"
    
    # Create test execution log
    exec 3>&1 4>&2
    trap 'exec 1>&3 2>&4' EXIT
    
    # Return to project root before running ansible-navigator
    cd "${PROJECT_ROOT}" || return 1
    
    # Run playbook and capture output
    # Use --pull-policy=never to prevent trying to pull local images
    if ! ansible-navigator run "$playbook" \
        --mode stdout \
        --eei "$image" \
        --pull-policy never \
        --log-file "${TEST_LOG_FILE}" \
        --forks 10 \
        --timeout 300 \
        -v > >(tee -a "${TEST_RESULTS_DIR}/playbook_output.log") 2>&1; then
        
        log_error "Playbook execution failed"
        return 1
    fi
    
    return 0
}

# Generate test report
generate_test_report() {
    CURRENT_STAGE="report-generation"
    local report_file="${TEST_RESULTS_DIR}/test_report.md"
    
    {
        echo "# Test Execution Report"
        echo "## Test Information"
        echo "- Date: $(date)"
        echo "- Environment: ${ENVIRONMENT:-production}"
        echo "- Script Version: ${SCRIPT_VERSION:-1.0}"
        echo
        echo "## Test Results"
        echo "### Playbook Output"
        echo "\`\`\`"
        cat "${TEST_RESULTS_DIR}/playbook_output.log"
        echo "\`\`\`"
        echo
        echo "### Execution Log"
        echo "\`\`\`"
        cat "${TEST_LOG_FILE}"
        echo "\`\`\`"
    } > "$report_file"
    
    log_info "Test report generated: $report_file"
}

# Retry mechanism with exponential backoff
retry_command() {
    local cmd=$1
    local stage=$2
    local attempt=1
    local delay=$RETRY_DELAY
    
    while [[ $attempt -le $RETRY_MAX ]]; do
        log_info "Attempt $attempt of $RETRY_MAX for stage: $stage"
        if eval "$cmd"; then
            return 0
        else
            if [[ $attempt -eq $RETRY_MAX ]]; then
                log_error "Failed after $RETRY_MAX attempts"
                return 1
            fi
            log_warn "Attempt $attempt failed, retrying in ${delay}s"
            sleep "$delay"
            delay=$((delay * 2))
            attempt=$((attempt + 1))
        fi
    done
    return 1
}

# Main execution flow
main() {
    local exit_code=0
    local example_name="minimal-ee"  # Default to minimal example
    local push_to_repo=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=1
                ;;
            -e|--example)
                example_name="$2"
                shift
                ;;
            -p|--push)
                push_to_repo=true
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
    
    log_info "Starting end-to-end tests for example: $example_name"
    
    # Stage 1: Environment Setup
    validate_environment || {
        log_error "Environment validation failed"
        exit 1
    }
    
    # Stage 2: Collection Verification
    if verify_collections; then
        log_info "Using existing collections"
    else
        log_info "Installing missing collections"
        if ! ansible-galaxy collection install -r "${PROJECT_ROOT}/examples/${example_name}-requirements.yml"; then
            log_error "Collection installation failed"
            exit 1
        fi
    fi
    
    # Stage 3: Image Building
    IMAGE_NAME="${TARGET_NAME}:${TARGET_TAG}"
    if ! build_ee_image "$IMAGE_NAME" "$example_name"; then
        log_error "Image build failed - exiting"
        exit 1
    fi
    
    # Stage 4: Image Tagging and Push
    if ! tag_and_push_image "$IMAGE_NAME" "$push_to_repo"; then
        log_error "Image tagging/push failed"
        exit 1
    fi
    
    # Stage 5: Test Execution
    CURRENT_STAGE="test-execution"
    if ! run_test_playbook "playbooks/test.yml" "${IMAGE_NAME}"; then
        exit_code=1
    fi
    
    # Stage 6: Report Generation
    if ! generate_test_report; then
        log_warn "Failed to generate test report"
    fi
    
    # Cleanup and exit with proper image name
    cleanup_and_exit "$exit_code" "$IMAGE_NAME"
}

# Cleanup function
cleanup_and_exit() {
    local exit_code=${1:-0}
    local image_name=${2:-"ansible-ee-minimal-ee:latest"}
    
    log_info "Cleaning up test environment"
    
    # Remove temporary files
    rm -f "${TEST_RESULTS_DIR}/playbook_output.log"
    
    # Clean up containers and images if needed
    if [[ "${CLEANUP_IMAGES:-true}" == "true" ]]; then
        podman rmi "$image_name" || true
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "Tests completed successfully"
    else
        log_error "Tests failed with exit code $exit_code"
    fi
    
    exit "$exit_code"
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Source .env for TARGET_TAG and TARGET_NAME
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        source "${PROJECT_ROOT}/.env"
    else
        log_error ".env file not found. Please create one with TARGET_TAG and TARGET_NAME."
        exit 1
    fi
    if [[ -z "${TARGET_TAG:-}" || "${TARGET_TAG}" == "latest" ]]; then
        log_error "TARGET_TAG must be set to a unique value for each run (not 'latest')."
        exit 1
    fi
    if [[ -z "${TARGET_NAME:-}" ]]; then
        log_error "TARGET_NAME must be set in .env."
        exit 1
    fi
    main "$@"
fi