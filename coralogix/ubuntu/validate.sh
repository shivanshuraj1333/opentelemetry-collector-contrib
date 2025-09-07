#!/bin/bash

# OpenTelemetry Collector Configuration Validation Script
# This script validates the YAML configurations before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_yaml_syntax() {
    local file=$1
    local name=$2
    
    log_info "Validating YAML syntax for $name..."
    
    if command -v yamllint > /dev/null 2>&1; then
        if yamllint "$file"; then
            log_info "YAML syntax is valid for $name"
        else
            log_error "YAML syntax errors found in $name"
            return 1
        fi
    else
        log_warn "yamllint not found, skipping YAML syntax validation"
    fi
}

check_otel_config() {
    local file=$1
    local name=$2
    
    log_info "Validating OpenTelemetry configuration for $name..."
    
    # Check if otelcol-contrib binary exists
    if ! command -v otelcol-contrib > /dev/null 2>&1; then
        log_warn "otelcol-contrib binary not found, skipping configuration validation"
        log_warn "Install OpenTelemetry Collector to validate configurations"
        return 0
    fi
    
    # Validate configuration
    if otelcol-contrib --config="$file" --dry-run 2>/dev/null; then
        log_info "OpenTelemetry configuration is valid for $name"
    else
        log_error "OpenTelemetry configuration validation failed for $name"
        log_error "Run: otelcol-contrib --config='$file' --dry-run"
        return 1
    fi
}

check_required_files() {
    log_info "Checking required files..."
    
    local files=("agent.yaml" "collector.yaml" "otel-agent.service" "otel-collector.service")
    local missing_files=()
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Missing required files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        return 1
    else
        log_info "All required files present"
    fi
}

check_environment_variables() {
    log_info "Checking environment variable references..."
    
    local files=("agent.yaml" "collector.yaml")
    local env_vars=("CORALOGIX_DOMAIN" "CORALOGIX_PRIVATE_KEY" "CORALOGIX_APP_NAME" "CORALOGIX_SUBSYSTEM")
    
    for file in "${files[@]}"; do
        log_info "Checking environment variables in $file..."
        for var in "${env_vars[@]}"; do
            if grep -q "\${env:$var}" "$file"; then
                log_info "  ✓ $var referenced in $file"
            else
                log_warn "  ⚠ $var not referenced in $file"
            fi
        done
    done
}

check_systemd_services() {
    log_info "Validating systemd service files..."
    
    local services=("otel-agent.service" "otel-collector.service")
    
    for service in "${services[@]}"; do
        log_info "Validating $service..."
        
        # Check if systemd-analyze is available
        if command -v systemd-analyze > /dev/null 2>&1; then
            if systemd-analyze verify "$service" 2>/dev/null; then
                log_info "  ✓ $service is valid"
            else
                log_error "  ✗ $service has validation errors"
                systemd-analyze verify "$service"
                return 1
            fi
        else
            log_warn "systemd-analyze not available, skipping systemd validation"
        fi
    done
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --yaml-only    Only validate YAML syntax"
    echo "  --otel-only    Only validate OpenTelemetry configuration"
    echo "  --help         Show this help message"
    echo
    echo "Examples:"
    echo "  $0                    # Validate all configurations"
    echo "  $0 --yaml-only        # Only check YAML syntax"
    echo "  $0 --otel-only        # Only check OpenTelemetry config"
}

main() {
    local yaml_only=false
    local otel_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --yaml-only)
                yaml_only=true
                shift
                ;;
            --otel-only)
                otel_only=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log_info "Starting configuration validation..."
    
    # Always check required files
    check_required_files
    
    if [[ "$yaml_only" == true ]]; then
        check_yaml_syntax "agent.yaml" "Agent"
        check_yaml_syntax "collector.yaml" "Collector"
    elif [[ "$otel_only" == true ]]; then
        check_otel_config "agent.yaml" "Agent"
        check_otel_config "collector.yaml" "Collector"
    else
        # Full validation
        check_yaml_syntax "agent.yaml" "Agent"
        check_yaml_syntax "collector.yaml" "Collector"
        check_otel_config "agent.yaml" "Agent"
        check_otel_config "collector.yaml" "Collector"
        check_environment_variables
        check_systemd_services
    fi
    
    log_info "Configuration validation completed!"
}

# Run main function
main "$@"
