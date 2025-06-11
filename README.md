# Network Performance Monitor for Proxmox

A comprehensive containerized solution for monitoring internet connectivity and performance, designed for ISP reporting and network troubleshooting.

## Features

- **Real-time Network Monitoring**: Continuous ping tests, latency measurement, and packet loss detection
- **Speed Testing**: Automated download/upload speed measurements
- **Professional Dashboards**: Grafana dashboards optimized for ISP reporting
- **Data Retention**: Configurable data retention policies
- **Multi-Target Monitoring**: Monitor up to 2 configurable targets (DNS/IP addresses)
- **Proxmox Integration**: Easy deployment script for Proxmox LXC containers

## Quick Deployment on Proxmox

1. **Download and run the deployment script:**
   ```bash
   curl -O https://raw.githubusercontent.com/your-repo/network-monitor/main/deploy-proxmox.sh
   chmod +x deploy-proxmox.sh
   sudo ./deploy-proxmox.sh
   ```

2. **Access the monitoring dashboard:**
   - Grafana: `http://[CONTAINER_IP]:3000`
   - Username: `admin`
   - Password: `networkmonitor123`

## Configuration

### Environment Variables

Edit `/opt/network-monitor/.env` in the container:

```bash
# Monitoring Targets
TARGET1=8.8.8.8
TARGET1_NAME=Google DNS
TARGET2=1.1.1.1
TARGET2_NAME=Cloudflare DNS

# Data Retention (days)
RETENTION_DAYS=30

# Collection Settings (seconds)
COLLECTION_INTERVAL=30

# Credentials (change these!)
INFLUXDB_PASSWORD=networkmonitor123
GRAFANA_PASSWORD=networkmonitor123
```

### Restart after configuration changes:
```bash
pct enter [CONTAINER_ID]
cd /opt/network-monitor
docker compose restart
```

## Manual Installation

If you prefer manual installation:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-repo/network-monitor.git
   cd network-monitor
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. **Start the stack:**
   ```bash
   docker compose up -d
   ```

## Dashboard Features

The Grafana dashboard includes:
- **Real-time Connection Status**: Live status indicators for all monitored targets
- **Latency Monitoring**: RTT trends and statistics
- **Packet Loss Tracking**: Percentage packet loss over time
- **Speed Test Results**: Download/upload speed measurements
- **Historical Data**: Configurable time ranges for trend analysis
- **Availability Reports**: Uptime statistics for each target

## ISP Reporting

The dashboard is designed to provide professional data for ISP communications:
- Export data in CSV format for attachments
- Clear visualizations showing performance degradation
- Historical trends to demonstrate persistent issues
- Detailed metrics with timestamps for technical support

## Monitoring Targets

Common monitoring targets:
- **DNS Servers**: 8.8.8.8 (Google), 1.1.1.1 (Cloudflare)
- **ISP Gateways**: Your ISP's gateway or DNS servers
- **Critical Services**: Important services your network depends on
- **Geographic Locations**: Different geographic regions for latency comparison

## Data Storage

- **InfluxDB**: Time-series database for metrics storage
- **Retention Policy**: Configurable data retention (default: 30 days)
- **Data Export**: Built-in export functionality for reports
- **Backup**: Standard InfluxDB backup procedures apply

## Troubleshooting

### Container Issues
```bash
# Check container status
pct list

# View container logs
pct enter [CONTAINER_ID]
docker compose logs -f
```

### Network Issues
```bash
# Test connectivity from container
pct exec [CONTAINER_ID] -- ping -c 4 8.8.8.8

# Check if services are running
pct exec [CONTAINER_ID] -- docker compose ps
```

### Dashboard Issues
```bash
# Restart Grafana
pct exec [CONTAINER_ID] -- docker compose restart grafana

# Check InfluxDB connection
pct exec [CONTAINER_ID] -- docker compose logs influxdb
```

## Customization

### Adding More Targets
Modify the `collector.py` to add additional monitoring targets:
```python
# Add more targets to the servers list
targets = [
    {'ip': '8.8.8.8', 'name': 'Google DNS'},
    {'ip': '1.1.1.1', 'name': 'Cloudflare DNS'},
    {'ip': 'your.isp.gateway', 'name': 'ISP Gateway'}
]
```

### Custom Dashboards
- Import additional Grafana dashboards
- Modify existing panels
- Create custom alerting rules

## System Requirements

- **Proxmox VE**: 6.0 or later
- **Container Resources**: 2GB RAM, 2 CPU cores, 10GB storage minimum
- **Network**: Internet connectivity for monitoring targets

## License

MIT License - see LICENSE file for details

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review container logs
3. Verify network connectivity
4. Check Grafana/InfluxDB status