#!/bin/bash

# OpenTelemetry Agent Installation Script for Ubuntu (Agent-Only)
# This script installs only the OpenTelemetry Agent for direct Coralogix integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
OTEL_VERSION="0.133.0"
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

install_agent() {
    log_info "Installing OpenTelemetry Agent (Agent-Only Deployment)..."
    
    # Download and install OpenTelemetry Collector
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    wget -q "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol-contrib_linux_amd64.tar.gz"
    tar -xzf "otelcol-contrib_linux_amd64.tar.gz"
    cp otelcol-contrib "$OTEL_BINARY"
    chmod +x "$OTEL_BINARY"
    
    cd /
    rm -rf "$TEMP_DIR"
    
    # Create user and directories
    if ! getent group "$OTEL_GROUP" > /dev/null 2>&1; then
        groupadd --system "$OTEL_GROUP"
    fi
    
    if ! getent passwd "$OTEL_USER" > /dev/null 2>&1; then
        useradd --system --no-create-home --shell /bin/false --gid "$OTEL_GROUP" "$OTEL_USER"
    fi
    
    mkdir -p "$OTEL_CONFIG_DIR" "$OTEL_HOME"
    chown "$OTEL_USER:$OTEL_GROUP" "$OTEL_HOME"
    chmod 755 "$OTEL_HOME"
    
    # Install configuration
    cp agent.yaml "$OTEL_CONFIG_DIR/"
    chown "$OTEL_USER:$OTEL_GROUP" "$OTEL_CONFIG_DIR/agent.yaml"
    chmod 644 "$OTEL_CONFIG_DIR/agent.yaml"
    
    # Create environment file
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
    
    # Install systemd service
    cp otel-agent.service /etc/systemd/system/
    systemctl daemon-reload
    
    # Enable and start service
    systemctl enable otel-agent
    systemctl start otel-agent
    
    # Wait and check status
    sleep 2
    if systemctl is-active --quiet otel-agent; then
        log_info "✅ Agent service started successfully!"
    else
        log_error "❌ Failed to start agent service"
        systemctl status otel-agent --no-pager
        exit 1
    fi
}

show_status() {
    log_info "🎉 OpenTelemetry Agent installation completed!"
    echo
    log_info "Service Status:"
    systemctl status otel-agent --no-pager
    echo
    log_info "Next Steps:"
    echo "1. Configure your Coralogix credentials:"
    echo "   sudo nano $OTEL_CONFIG_DIR/coralogix.env"
    echo
    echo "2. Restart the service after configuration:"
    echo "   sudo systemctl restart otel-agent"
    echo
    log_info "Useful Commands:"
    echo "  Check status:    systemctl status otel-agent"
    echo "  View logs:       journalctl -u otel-agent -f"
    echo "  Restart:         systemctl restart otel-agent"
    echo "  Stop:            systemctl stop otel-agent"
    echo
    log_info "Health Checks:"
    echo "  Agent health:    curl http://localhost:13133/"
    echo "  Metrics:         curl http://localhost:8888/metrics"
    echo "  ZPages:          http://localhost:55679"
    echo
    log_warn "⚠️  Don't forget to configure your Coralogix credentials!"
}

main() {
    log_info "🚀 Starting OpenTelemetry Agent installation (Agent-Only)..."
    echo
    log_info "This will install only the OpenTelemetry Agent that directly sends"
    log_info "data to Coralogix. This is the recommended approach for most deployments."
    echo
    
    check_root
    install_agent
    show_status
}

# Run main function
main "$@"
