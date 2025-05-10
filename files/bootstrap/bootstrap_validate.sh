#!/bin/bash

# Check if requirements.yml exists
if [ ! -f requirements.yml ]; then
  echo "Error: requirements.yml file not found."
  exit 1
else
  echo "requirements.yml file found."
fi

# Logging functions
log_info() { echo "[INFO] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
log_warn() { echo "[WARN] $*" >&2; }
log_debug() { [[ "${VERBOSE:-0}" == "1" ]] && echo "[DEBUG] $*" >&2; }

# Error handling
trap 'log_error "Error on line $LINENO"' ERR

# Default values
VERBOSE=0
CHECK_ALL=1
CHECK_ENV=0
CHECK_DEPS=0
CHECK_CONFIG=0
CHECK_EXAMPLES=0
EXAMPLE_NAME=""

# Required configuration files
REQUIRED_FILES=(
    "execution-environment.yml"
    "ansible-navigator.yml"
    "ee-variables.yml"
    "requirements.yml"
    "requirements.txt"
    "bindep.txt"
)

# Valid example names
VALID_EXAMPLES=(
    "openshift_virt"
    "aws_cloud"
    "gcp_cloud"
)

# Usage function
show_usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options]

Validate the Ansible Execution Environment configuration and dependencies.

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --env-only          Only check environment setup
    --deps-only         Only check dependencies
    --config-only       Only check configuration files
    --example NAME      Validate specific example (openshift_virt, aws_cloud, gcp_cloud)
    --examples-only     Only validate examples
EOF
}

# Function to validate environment setup
validate_environment() {
    log_info "Validating environment setup"
    
    # Check virtual environment
    if [[ ! -d "${PROJECT_ROOT}/.venv" ]]; then
        log_error "Virtual environment not found"
        return 1
    fi
    
    # Check environment variables
    local required_vars=()  # Empty by default
    local recommended_vars=(
        "ANSIBLE_HUB_TOKEN"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    # Check recommended variables
    local missing_recommended=()
    for var in "${recommended_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_recommended+=("$var")
        fi
    done
    
    if [[ ${#missing_recommended[@]} -gt 0 ]]; then
        log_warn "Missing recommended environment variables: ${missing_recommended[*]}"
        log_warn "These variables may be needed for full functionality"
    fi
    
    log_info "Environment validation passed"
}

# Function to validate dependencies
validate_dependencies() {
    log_info "Validating dependencies"
    
    # Check Python packages
    if [[ -f "${PROJECT_ROOT}/requirements.txt" ]]; then
        log_info "Checking Python packages"
        if ! pip3 freeze | grep -q -f "${PROJECT_ROOT}/requirements.txt"; then
            log_error "Missing Python packages"
            return 1
        fi
    fi
    
    # Check Ansible collections
    if [[ -f "${PROJECT_ROOT}/requirements.yml" ]]; then
        log_info "Checking Ansible collections"
        if ! ansible-galaxy collection list | grep -q "ansible-automation-platform"; then
            log_error "Missing required Ansible collections"
            return 1
        fi
    fi
    
    log_info "Dependency validation passed"
}

# Function to validate configuration files
validate_configuration() {
    log_info "Validating configuration files"
    
    # Check required files exist
    local missing_files=()
    for file in "${REQUIRED_FILES[@]}"; do
        if [[ ! -f "${PROJECT_ROOT}/${file}" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Missing required files: ${missing_files[*]}"
        return 1
    fi
    
    # Validate YAML files
    if command -v yamllint >/dev/null 2>&1; then
        log_info "Validating YAML files"
        for yml_file in "${PROJECT_ROOT}"/*.yml; do
            # Skip files with Jinja2 templating
            if grep -qE '{[%{]' "$yml_file"; then
                log_warn "Skipping yamllint for template file: $yml_file"
                continue
            fi
            yamllint -c "${PROJECT_ROOT}/.yamllint.yml" "$yml_file" || {
                log_error "YAML validation failed for $yml_file"
                return 1
            }
        done
    else
        log_warn "yamllint not found, skipping YAML validation"
    fi
    
    log_info "Configuration validation passed"
}

# Function to validate example configuration
validate_example() {
    local example_name="$1"
    log_info "Validating example: $example_name"
    
    # Check if example exists in ee-variables.yml
    if ! yq --yaml-output ".example_environments.${example_name}" "${PROJECT_ROOT}/ee-variables.yml" >/dev/null 2>&1; then
        log_error "Example $example_name not found in ee-variables.yml"
        return 1
    fi
    
    # Validate example dependencies exist
    local dep_files=(
        "files/${example_name//_/-}-requirements.yml"
        "files/${example_name//_/-}-requirements.txt"
        "files/${example_name//_/-}-bindep.txt"
    )
    
    local missing_deps=()
    for file in "${dep_files[@]}"; do
        if [[ ! -f "${PROJECT_ROOT}/${file}" ]]; then
            missing_deps+=("$file")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependency files for $example_name: ${missing_deps[*]}"
        return 1
    fi
    
    # Check required tools
    local tools
    tools=$(yq --yaml-output ".example_environments.${example_name}.validation.required_tools[]" "${PROJECT_ROOT}/ee-variables.yml")
    
    local missing_tools=()
    for tool in $tools; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_warn "Missing tools for $example_name: ${missing_tools[*]}"
    fi
    
    # Check registry access
    local registries
    registries=$(yq --yaml-output ".example_environments.${example_name}.validation.required_access[]" "${PROJECT_ROOT}/ee-variables.yml")
    
    local registry_errors=0
    for registry in $registries; do
        if ! podman login "$registry" >/dev/null 2>&1; then
            log_warn "Cannot access registry: $registry"
            ((registry_errors++))
        fi
    done
    
    if [[ "$registry_errors" -gt 0 ]]; then
        log_warn "Some registries are not accessible"
    fi
    
    log_info "Example validation completed: $example_name"
}

# Function to validate all examples
validate_examples() {
    log_info "Validating all examples"
    local exit_code=0
    
    for example in "${VALID_EXAMPLES[@]}"; do
        validate_example "$example" || exit_code=$?
    done
    
    return "$exit_code"
}

# Semantic version validation for TARGET_TAG in .env
validate_target_tag() {
    local env_file="${PROJECT_ROOT:-.}/.env"
    local tag
    if [[ -f "$env_file" ]]; then
        tag=$(grep -E '^TARGET_TAG=' "$env_file" | cut -d'=' -f2 | tr -d '"')
        tag="$(echo "$tag" | xargs)"  # Trim whitespace
        if [[ -z "$tag" ]]; then
            log_error "TARGET_TAG is not set in .env."
            exit 1
        fi
        if [[ ! "$tag" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
            log_error "TARGET_TAG '$tag' is not a valid semantic version (expected format: vMAJOR.MINOR.PATCH, e.g., v0.0.1)."
            exit 1
        fi
        log_debug "TARGET_TAG '$tag' is valid."
    else
        log_error ".env file not found for TARGET_TAG validation."
        exit 1
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=1
                ;;
            --env-only)
                CHECK_ALL=0
                CHECK_ENV=1
                ;;
            --deps-only)
                CHECK_ALL=0
                CHECK_DEPS=1
                ;;
            --config-only)
                CHECK_ALL=0
                CHECK_CONFIG=1
                ;;
            --examples-only)
                CHECK_ALL=0
                CHECK_EXAMPLES=1
                ;;
            --example)
                CHECK_ALL=0
                CHECK_EXAMPLES=1
                EXAMPLE_NAME="$2"
                # Validate example name
                local valid_example=0
                for e in "${VALID_EXAMPLES[@]}"; do
                    if [[ "$EXAMPLE_NAME" == "$e" ]]; then
                        valid_example=1
                        break
                    fi
                done
                if [[ "$valid_example" -eq 0 ]]; then
                    log_error "Invalid example name: $EXAMPLE_NAME"
                    show_usage
                    exit 1
                fi
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
}

# Main function
main() {
    parse_args "$@"
    local exit_code=0
    
    log_info "Starting validation checks"
    
    # Validate TARGET_TAG semantic versioning
    validate_target_tag

    if [[ "${CHECK_ALL}" == "1" || "${CHECK_ENV}" == "1" ]]; then
        validate_environment || exit_code=$?
    fi
    
    if [[ "${CHECK_ALL}" == "1" || "${CHECK_DEPS}" == "1" ]]; then
        validate_dependencies || exit_code=$?
    fi
    
    if [[ "${CHECK_ALL}" == "1" || "${CHECK_CONFIG}" == "1" ]]; then
        validate_configuration || exit_code=$?
    fi
    
    if [[ "${CHECK_ALL}" == "1" || "${CHECK_EXAMPLES}" == "1" ]]; then
        if [[ -n "${EXAMPLE_NAME}" ]]; then
            validate_example "${EXAMPLE_NAME}" || exit_code=$?
        else
            validate_examples || exit_code=$?
        fi
    fi
    
    if [[ "${exit_code}" == "0" ]]; then
        log_info "All validation checks passed"
    else
        log_error "Some validation checks failed"
    fi
    
    return "${exit_code}"
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi