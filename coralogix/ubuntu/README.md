# OpenTelemetry Collector for Ubuntu Systemd Deployment

This directory contains OpenTelemetry Collector configurations designed for deployment as systemd services on Ubuntu machines for comprehensive host monitoring.

## Files

- `agent.yaml` - Configuration for the OpenTelemetry Agent (deployed on each host) - **RECOMMENDED**
- `collector.yaml` - Configuration for the OpenTelemetry Collector (centralized collection) - **OPTIONAL**
- `otel-agent.service` - Systemd service file for the agent
- `otel-collector.service` - Systemd service file for the collector

## Features

### Agent Configuration (`agent.yaml`)
- **Host Metrics Collection**: Comprehensive system metrics including CPU, memory, disk, filesystem, network, load, paging, processes, and uptime
- **System Logs Collection**: Collects logs from `/var/log/syslog`, `/var/log/auth.log`, `/var/log/kern.log`, and other system logs
- **OTLP Receiver**: Accepts telemetry data from applications via OTLP (gRPC and HTTP)
- **Resource Detection**: Automatically detects host information and adds resource attributes
- **Coralogix Integration**: Exports all telemetry data to Coralogix platform

### Collector Configuration (`collector.yaml`)
- **Multi-Protocol Support**: OTLP, Jaeger, and Zipkin receivers for traces
- **Metrics Processing**: Includes span metrics processor for generating RED metrics from traces
- **Sampling**: Probabilistic sampling for traces to reduce data volume
- **Centralized Collection**: Aggregates data from multiple agents and applications
- **Coralogix Integration**: Exports processed telemetry data to Coralogix platform

## Prerequisites

1. **OpenTelemetry Collector Binary**: Download the OpenTelemetry Collector Contrib binary
2. **Coralogix Credentials**: Set up environment variables for Coralogix integration
3. **System Permissions**: Ensure the collector has necessary permissions to read system files

## Architecture Decision

### **Agent-Only Deployment (Recommended)**
For most Ubuntu host monitoring scenarios, use **only the agent**:
- ✅ Simpler architecture
- ✅ Direct data flow to Coralogix
- ✅ Lower resource usage
- ✅ Easier to manage and troubleshoot
- ✅ Perfect for single-host or small-scale deployments

### **Agent + Collector Deployment (Optional)**
Use collector only when you need:
- 🔄 Data aggregation from multiple agents
- 🔄 Centralized sampling and processing
- 🔄 Multiple data destinations
- 🔄 Complex data transformations

## Architecture Comparison

| Aspect | Agent-Only | Agent + Collector |
|--------|------------|-------------------|
| **Complexity** | ✅ Simple | ❌ More complex |
| **Resource Usage** | ✅ Lower | ❌ Higher |
| **Data Flow** | Agent → Coralogix | Agent → Collector → Coralogix |
| **Management** | ✅ Easy | ❌ More components |
| **Scalability** | ✅ Good for <100 hosts | ✅ Better for 100+ hosts |
| **Data Processing** | ❌ Limited | ✅ Advanced processing |
| **Fault Tolerance** | ✅ Direct connection | ❌ Single point of failure |
| **Use Case** | **Most deployments** | Large-scale deployments |

## Quick Start (Agent-Only - Recommended)

For most use cases, you only need the agent:

```bash
# Download and run the agent-only installation script
sudo ./install-agent-only.sh
```

This will:
- Install OpenTelemetry Collector Contrib
- Set up the agent with host monitoring
- Configure systemd service
- Start the agent service

## Full Installation (Agent + Optional Collector)

### 1. Download OpenTelemetry Collector

```bash
# Download the latest OpenTelemetry Collector Contrib binary
wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/latest/download/otelcol-contrib_linux_amd64.tar.gz

# Extract the binary
tar -xzf otelcol-contrib_linux_amd64.tar.gz
sudo mv otelcol-contrib /usr/local/bin/
sudo chmod +x /usr/local/bin/otelcol-contrib
```

### 2. Create Configuration Directory

```bash
sudo mkdir -p /etc/otelcol
sudo mkdir -p /var/lib/otelcol
sudo chown -R otelcol:otelcol /var/lib/otelcol
```

### 3. Create otelcol User

```bash
sudo useradd --system --no-create-home --shell /bin/false otelcol
```

### 4. Copy Configuration Files

```bash
# Copy agent configuration
sudo cp agent.yaml /etc/otelcol/

# Copy collector configuration (if deploying collector)
sudo cp collector.yaml /etc/otelcol/
```

### 5. Set Environment Variables

Create environment file for Coralogix credentials:

```bash
sudo tee /etc/otelcol/coralogix.env > /dev/null <<EOF
CORALOGIX_DOMAIN=your-domain.coralogix.com
CORALOGIX_PRIVATE_KEY=your-private-key
CORALOGIX_APP_NAME=ubuntu-host
CORALOGIX_SUBSYSTEM=system
EOF

sudo chmod 600 /etc/otelcol/coralogix.env
```

### 6. Install Systemd Service Files

```bash
# Install agent service
sudo cp otel-agent.service /etc/systemd/system/

# Install collector service (if deploying collector)
sudo cp otel-collector.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload
```

### 7. Enable and Start Services

```bash
# For agent-only deployment (RECOMMENDED)
sudo systemctl enable otel-agent
sudo systemctl start otel-agent

# For collector deployment (OPTIONAL - only if you need centralized collection)
sudo systemctl enable otel-collector
sudo systemctl start otel-collector
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CORALOGIX_DOMAIN` | Your Coralogix domain | Required |
| `CORALOGIX_PRIVATE_KEY` | Your Coralogix private key | Required |
| `CORALOGIX_APP_NAME` | Application name in Coralogix | `ubuntu-host` |
| `CORALOGIX_SUBSYSTEM` | Subsystem name in Coralogix | `system` |

### Customizing Metrics Collection

The hostmetrics receiver can be customized by modifying the `scrapers` section in the configuration:

```yaml
hostmetrics:
  collection_interval: 30s  # Adjust collection frequency
  scrapers:
    cpu:
      metrics:
        system.cpu.utilization:
          enabled: true
    # Add or remove scrapers as needed
```

### Customizing Log Collection

The filelog receiver can be customized by modifying the `include` section:

```yaml
filelog:
  include:
    - /var/log/syslog
    - /var/log/auth.log
    - /var/log/your-app/*.log  # Add your application logs
```

## Monitoring

### Health Checks

- **Agent**: `curl http://localhost:13133/`
- **Collector**: `curl http://localhost:13133/`

### Debugging

- **ZPages**: Visit `http://localhost:55679` for debugging information
- **Prometheus Metrics**: Visit `http://localhost:8888/metrics` for internal metrics
- **Logs**: Check systemd logs with `journalctl -u otel-agent` or `journalctl -u otel-collector`

### Service Management

```bash
# Check status
sudo systemctl status otel-agent
sudo systemctl status otel-collector

# View logs
sudo journalctl -u otel-agent -f
sudo journalctl -u otel-collector -f

# Restart services
sudo systemctl restart otel-agent
sudo systemctl restart otel-collector

# Stop services
sudo systemctl stop otel-agent
sudo systemctl stop otel-collector
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure the otelcol user has read access to log files and system directories
2. **Connection Issues**: Verify Coralogix credentials and network connectivity
3. **High Memory Usage**: Adjust the memory limiter settings in the configuration
4. **Missing Metrics**: Check if the required scrapers are enabled in hostmetrics receiver

### Log Analysis

Check the collector logs for errors:

```bash
sudo journalctl -u otel-agent --since "1 hour ago" | grep -i error
sudo journalctl -u otel-collector --since "1 hour ago" | grep -i error
```

### Configuration Validation

Test your configuration before deploying:

```bash
otelcol-contrib --config=/etc/otelcol/agent.yaml --dry-run
otelcol-contrib --config=/etc/otelcol/collector.yaml --dry-run
```

## Security Considerations

1. **File Permissions**: Ensure configuration files have appropriate permissions (600)
2. **Network Security**: Consider firewall rules for exposed ports
3. **Credential Management**: Use secure methods to manage Coralogix credentials
4. **Log Rotation**: Implement log rotation to prevent disk space issues

## Performance Tuning

1. **Batch Size**: Adjust batch processor settings based on your data volume
2. **Collection Interval**: Balance between data freshness and resource usage
3. **Memory Limits**: Configure memory limiter based on available system resources
4. **Sampling**: Use probabilistic sampling for traces to reduce data volume
