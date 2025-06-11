# Network Performance Monitor for Proxmox

A comprehensive containerized solution for monitoring internet connectivity and performance, designed for ISP reporting and network troubleshooting. This solution provides professional-grade monitoring with Grafana dashboards and InfluxDB data storage.

## 🚀 Quick Deployment on Proxmox

### One-Line Installation

Replace `YOUR_USERNAME` and `YOUR_REPO` with your actual GitHub repository details:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh)"
```

### What Gets Installed

- **LXC Container** on Proxmox with Ubuntu 22.04
- **Docker & Docker Compose** for containerization
- **InfluxDB 2.7** for time-series data storage
- **Grafana 10.2** with pre-configured dashboards
- **Python Network Collector** for continuous monitoring
- **Professional ISP Reporting Dashboards**

## 📊 Features

### Real-time Network Monitoring
- **Continuous Ping Tests**: Latency measurement and packet loss detection
- **Speed Testing**: Automated download/upload speed measurements
- **Multi-Target Monitoring**: Monitor up to 2 configurable targets simultaneously
- **Historical Data**: Configurable data retention (default: 30 days)

### Professional Dashboards
- **ISP Reporting Ready**: Professional visualizations for provider communications
- **Real-time Status**: Live connection status indicators
- **Trend Analysis**: Historical performance trends
- **Export Capabilities**: CSV export for technical support tickets

### Easy Configuration
- **Environment Variables**: Simple `.env` file configuration
- **Flexible Targets**: DNS servers, gateways, or any IP/hostname
- **Adjustable Intervals**: Customizable monitoring frequency
- **Data Retention**: Configurable storage duration

## 🔧 Configuration

### Default Settings
```bash
# Monitoring Targets
TARGET1=8.8.8.8
TARGET1_NAME=Google DNS
TARGET2=1.1.1.1
TARGET2_NAME=Cloudflare DNS

# Collection Settings
COLLECTION_INTERVAL=30  # seconds
RETENTION_DAYS=30       # days

# Credentials (change these!)
INFLUXDB_PASSWORD=networkmonitor123
GRAFANA_PASSWORD=networkmonitor123
```

### Customizing Monitoring Targets

1. **Access the container:**
   ```bash
   pct enter 200
   cd /opt/network-monitor
   ```

2. **Edit configuration:**
   ```bash
   nano .env
   ```

3. **Common monitoring targets:**
   ```bash
   # ISP Gateway
   TARGET1=192.168.1.1
   TARGET1_NAME=ISP Gateway
   
   # Critical Service
   TARGET2=your-server.com
   TARGET2_NAME=Production Server
   ```

4. **Restart services:**
   ```bash
   docker compose restart
   ```

## 📈 Dashboard Access

After installation, access your monitoring dashboard:

- **Grafana**: `http://[CONTAINER-IP]:3000`
  - Username: `admin`
  - Password: `networkmonitor123`

### Dashboard Features

1. **Connection Status Panel**: Real-time online/offline status
2. **Latency Monitoring**: RTT trends with min/max/avg values
3. **Packet Loss Tracking**: Percentage loss over time
4. **Speed Test Results**: Download/upload measurements
5. **Target Availability**: Uptime statistics per target
6. **Historical Analysis**: Configurable time ranges

## 🏢 ISP Reporting

This solution is specifically designed for professional ISP communications:

### Data Export
- **CSV Export**: Export metrics for email attachments
- **Screenshot Capability**: Professional dashboard screenshots
- **Time Range Selection**: Focus on problem periods
- **Detailed Metrics**: Timestamps, latency, packet loss, speeds

### Professional Visualizations
- **Clear Trend Lines**: Easy to identify performance degradation
- **Color-coded Status**: Green/yellow/red status indicators
- **Statistical Summaries**: Average, min, max values
- **Availability Reports**: Uptime percentages

## 🔧 Advanced Configuration

### Adding More Monitoring Targets

Modify `collector.py` to add additional targets:

```python
# Add more targets to monitor
targets = [
    {'ip': '8.8.8.8', 'name': 'Google DNS'},
    {'ip': '1.1.1.1', 'name': 'Cloudflare DNS'},
    {'ip': 'your.isp.gateway', 'name': 'ISP Gateway'},
    {'ip': 'critical-server.com', 'name': 'Critical Service'}
]
```

### Custom Grafana Dashboards

1. **Access Grafana**: `http://[CONTAINER-IP]:3000`
2. **Import Dashboards**: Use Grafana's import functionality
3. **Customize Panels**: Modify existing visualizations
4. **Create Alerts**: Set up email notifications for outages

### Data Backup

```bash
# Backup InfluxDB data
pct exec 200 -- docker exec network-monitor-influxdb influx backup /tmp/backup
pct exec 200 -- cp -r /var/lib/docker/volumes/network-monitor_influxdb-data /backup/

# Backup Grafana dashboards
pct exec 200 -- cp -r /var/lib/docker/volumes/network-monitor_grafana-data /backup/
```

## 🛠️ Troubleshooting

### Container Issues
```bash
# Check container status
pct list

# View container logs
pct enter 200
docker compose logs -f
```

### Network Connectivity
```bash
# Test from container
pct exec 200 -- ping -c 4 8.8.8.8

# Check service status
pct exec 200 -- docker compose ps
```

### Dashboard Not Loading
```bash
# Restart Grafana
pct exec 200 -- docker compose restart grafana

# Check InfluxDB connection
pct exec 200 -- docker compose logs influxdb
```

### Data Not Appearing
```bash
# Check collector logs
pct exec 200 -- docker compose logs network-collector

# Verify InfluxDB data
pct exec 200 -- docker exec -it network-monitor-influxdb influx query 'from(bucket:"network_metrics") |> range(start:-1h)'
```

## 📋 System Requirements

### Proxmox Host
- **Proxmox VE**: 6.0 or later
- **Available Container ID**: Default 200 (configurable)
- **Storage**: 10GB minimum for container
- **Network**: Internet connectivity for monitoring targets

### Container Resources
- **Memory**: 2GB RAM
- **CPU**: 2 cores
- **Storage**: 10GB disk space
- **Network**: Bridge network access

## 🔄 Updates and Maintenance

### Updating from GitHub
```bash
pct enter 200
cd /opt/network-monitor
git pull
docker compose down
docker compose up -d --build
```

### Regular Maintenance
- **Monitor disk usage**: InfluxDB data grows over time
- **Review retention settings**: Adjust `RETENTION_DAYS` as needed
- **Update containers**: Regular security updates
- **Backup configuration**: Save custom settings

## 📝 License

MIT License - see LICENSE file for details

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📞 Support

For issues and questions:
1. Check the troubleshooting section
2. Review container logs
3. Verify network connectivity
4. Check GitHub issues for similar problems

---

**Perfect for ISP Reporting**: This solution provides professional-grade network monitoring with the data and visualizations needed to make qualified claims to internet service providers about connection quality and performance issues.