#!/bin/bash

# OpenTelemetry Collector Installation Script for Ubuntu
# This script installs and configures OpenTelemetry Collector as a systemd service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
OTEL_VERSION="0.131.1"
OTEL_USER="otelcol"
OTEL_GROUP="otelcol"
OTEL_HOME="/var/lib/otelcol"
OTEL_CONFIG_DIR="/etc/otelcol"
OTEL_BINARY="/usr/local/bin/otelcol-contrib"

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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_system() {
    log_info "Checking system requirements..."
    
    # Check if running on Ubuntu
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_warn "This script is designed for Ubuntu. Other distributions may work but are not tested."
    fi
    
    # Check available memory
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$MEMORY_GB" -lt 1 ]; then
        log_warn "System has less than 1GB RAM. Consider increasing memory for better performance."
    fi
    
    # Check available disk space
    DISK_GB=$(df / | awk 'NR==2{print int($4/1024/1024)}')
    if [ "$DISK_GB" -lt 5 ]; then
        log_warn "System has less than 5GB free disk space. Consider freeing up space."
    fi
}

install_dependencies() {
    log_info "Installing dependencies..."
    apt-get update
    apt-get install -y wget curl systemd
}

download_otel() {
    log_info "Downloading OpenTelemetry Collector Contrib v${OTEL_VERSION}..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download and extract
    wget -q "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol-contrib_linux_amd64.tar.gz"
    tar -xzf "otelcol-contrib_linux_amd64.tar.gz"
    
    # Install binary
    cp otelcol-contrib "$OTEL_BINARY"
    chmod +x "$OTEL_BINARY"
    
    # Cleanup
    cd /
    rm -rf "$TEMP_DIR"
    
    log_info "OpenTelemetry Collector installed to $OTEL_BINARY"
}

create_user() {
    log_info "Creating otelcol user and group..."
    
    # Create group if it doesn't exist
    if ! getent group "$OTEL_GROUP" > /dev/null 2>&1; then
        groupadd --system "$OTEL_GROUP"
    fi
    
    # Create user if it doesn't exist
    if ! getent passwd "$OTEL_USER" > /dev/null 2>&1; then
        useradd --system --no-create-home --shell /bin/false --gid "$OTEL_GROUP" "$OTEL_USER"
    fi
}

create_directories() {
    log_info "Creating directories..."
    
    # Create configuration directory
    mkdir -p "$OTEL_CONFIG_DIR"
    
    # Create data directory
    mkdir -p "$OTEL_HOME"
    chown "$OTEL_USER:$OTEL_GROUP" "$OTEL_HOME"
    chmod 755 "$OTEL_HOME"
}

install_configs() {
    log_info "Installing configuration files..."
    
    # Copy configuration files
    cp agent.yaml "$OTEL_CONFIG_DIR/"
    cp collector.yaml "$OTEL_CONFIG_DIR/"
    
    # Set permissions
    chown -R "$OTEL_USER:$OTEL_GROUP" "$OTEL_CONFIG_DIR"
    chmod 644 "$OTEL_CONFIG_DIR"/*.yaml
    
    log_info "Configuration files installed to $OTEL_CONFIG_DIR"
}

create_env_file() {
    log_info "Creating environment configuration file..."
    
    cat > "$OTEL_CONFIG_DIR/coralogix.env" << EOF
# Coralogix Configuration
# Replace these values with your actual Coralogix credentials

CORALOGIX_DOMAIN=your-domain.coralogix.com
CORALOGIX_PRIVATE_KEY=your-private-key
CORALOGIX_APP_NAME=ubuntu-host
CORALOGIX_SUBSYSTEM=system
EOF
    
    chown "$OTEL_USER:$OTEL_GROUP" "$OTEL_CONFIG_DIR/coralogix.env"
    chmod 600 "$OTEL_CONFIG_DIR/coralogix.env"
    
    log_warn "Please edit $OTEL_CONFIG_DIR/coralogix.env with your actual Coralogix credentials"
}

install_systemd_services() {
    log_info "Installing systemd service files..."
    
    # Copy service files
    cp otel-agent.service /etc/systemd/system/
    cp otel-collector.service /etc/systemd/system/
    
    # Reload systemd
    systemctl daemon-reload
    
    log_info "Systemd service files installed"
}

enable_services() {
    log_info "Enabling services..."
    
    # Enable agent service (recommended)
    systemctl enable otel-agent
    log_info "Agent service enabled (recommended for most deployments)"
    
    # Ask user if they want to enable collector service
    echo
    log_info "The collector service is optional and only needed for:"
    log_info "  - Large-scale deployments (100+ hosts)"
    log_info "  - Centralized data processing"
    log_info "  - Multiple data destinations"
    echo
    read -p "Do you want to enable the collector service? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl enable otel-collector
        log_info "Both agent and collector services enabled"
    else
        log_info "Only agent service enabled (recommended)"
    fi
}

start_services() {
    log_info "Starting services..."
    
    # Start agent service
    systemctl start otel-agent
    
    # Start collector service if enabled
    if systemctl is-enabled otel-collector > /dev/null 2>&1; then
        systemctl start otel-collector
    fi
    
    # Wait a moment for services to start
    sleep 2
    
    # Check status
    if systemctl is-active --quiet otel-agent; then
        log_info "Agent service started successfully"
    else
        log_error "Failed to start agent service"
        systemctl status otel-agent --no-pager
        exit 1
    fi
    
    if systemctl is-enabled otel-collector > /dev/null 2>&1; then
        if systemctl is-active --quiet otel-collector; then
            log_info "Collector service started successfully"
        else
            log_error "Failed to start collector service"
            systemctl status otel-collector --no-pager
            exit 1
        fi
    fi
}

show_status() {
    log_info "Service Status:"
    echo
    systemctl status otel-agent --no-pager
    echo
    
    if systemctl is-enabled otel-collector > /dev/null 2>&1; then
        systemctl status otel-collector --no-pager
        echo
    fi
    
    log_info "Useful commands:"
    echo "  Check status:    systemctl status otel-agent otel-collector"
    echo "  View logs:       journalctl -u otel-agent -f"
    echo "  Restart:         systemctl restart otel-agent otel-collector"
    echo "  Stop:            systemctl stop otel-agent otel-collector"
    echo
    log_info "Health checks:"
    echo "  Agent:           curl http://localhost:13133/"
    echo "  Collector:       curl http://localhost:13133/"
    echo "  Metrics:         curl http://localhost:8888/metrics"
    echo "  ZPages:          http://localhost:55679"
}

main() {
    log_info "Starting OpenTelemetry Collector installation..."
    
    check_root
    check_system
    install_dependencies
    download_otel
    create_user
    create_directories
    install_configs
    create_env_file
    install_systemd_services
    enable_services
    start_services
    show_status
    
    log_info "Installation completed successfully!"
    log_warn "Don't forget to configure your Coralogix credentials in $OTEL_CONFIG_DIR/coralogix.env"
}

# Run main function
main "$@"
