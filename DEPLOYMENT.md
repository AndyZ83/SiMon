# Deployment Guide

## GitHub Repository Setup

### 1. Create GitHub Repository

1. Create a new repository on GitHub
2. Clone this project to your local machine
3. Push to your GitHub repository

### 2. Update Installation Script

Edit `install.sh` and replace the placeholder URLs:

```bash
# Replace these lines in install.sh:
GITHUB_REPO="https://github.com/YOUR_USERNAME/YOUR_REPO.git"
GITHUB_RAW_URL="https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main"

# With your actual repository:
GITHUB_REPO="https://github.com/yourusername/network-monitor.git"
GITHUB_RAW_URL="https://raw.githubusercontent.com/yourusername/network-monitor/main"
```

### 3. Update README.md

Replace the installation command in README.md:

```bash
# Replace:
bash -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh)"

# With:
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yourusername/network-monitor/main/install.sh)"
```

## Proxmox Deployment

### Prerequisites

- Proxmox VE 6.0 or later
- Root access to Proxmox host
- Internet connectivity
- Available container ID (default: 200)

### Installation Steps

1. **SSH to your Proxmox host**

2. **Run the one-line installer:**
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/yourusername/network-monitor/main/install.sh)"
   ```

3. **Wait for installation to complete** (approximately 5-10 minutes)

4. **Access the dashboard:**
   - URL will be displayed at the end of installation
   - Default: `http://[CONTAINER-IP]:3000`
   - Username: `admin`
   - Password: `networkmonitor123`

### Post-Installation Configuration

1. **Customize monitoring targets:**
   ```bash
   pct enter 200
   cd /opt/network-monitor
   nano .env
   docker compose restart
   ```

2. **Change default passwords:**
   ```bash
   # Edit .env file
   INFLUXDB_PASSWORD=your-secure-password
   GRAFANA_PASSWORD=your-secure-password
   
   # Restart services
   docker compose down
   docker compose up -d
   ```

## Container Management

### Basic Commands

```bash
# Enter container
pct enter 200

# Start/Stop container
pct start 200
pct stop 200

# View container status
pct list

# Container resource usage
pct status 200
```

### Service Management

```bash
# Inside container (/opt/network-monitor)
docker compose ps              # View services
docker compose logs -f         # View logs
docker compose restart         # Restart all services
docker compose down            # Stop all services
docker compose up -d           # Start all services
```

### Monitoring Commands

```bash
# View collector logs
docker compose logs network-collector

# View InfluxDB logs
docker compose logs influxdb

# View Grafana logs
docker compose logs grafana

# Check data collection
docker exec -it network-monitor-influxdb influx query 'from(bucket:"network_metrics") |> range(start:-1h) |> limit(n:10)'
```

## Customization Examples

### ISP Gateway Monitoring

```bash
# Edit .env
TARGET1=192.168.1.1
TARGET1_NAME=ISP Gateway
TARGET2=8.8.8.8
TARGET2_NAME=Google DNS
COLLECTION_INTERVAL=15
```

### High-Frequency Monitoring

```bash
# Edit .env for more frequent testing
COLLECTION_INTERVAL=10  # Every 10 seconds
RETENTION_DAYS=7        # Keep 7 days of data
```

### Multiple Location Monitoring

```bash
# Monitor different geographic locations
TARGET1=8.8.8.8
TARGET1_NAME=Google US
TARGET2=1.1.1.1
TARGET2_NAME=Cloudflare Global
```

## Backup and Restore

### Backup Configuration

```bash
# Backup entire container
vzdump 200 --storage local

# Backup just the configuration
pct exec 200 -- tar -czf /tmp/network-monitor-config.tar.gz -C /opt network-monitor
pct pull 200 /tmp/network-monitor-config.tar.gz ./network-monitor-backup.tar.gz
```

### Restore Configuration

```bash
# Push configuration to new container
pct push 200 ./network-monitor-backup.tar.gz /tmp/
pct exec 200 -- tar -xzf /tmp/network-monitor-backup.tar.gz -C /opt
```

## Security Considerations

### Network Security

```bash
# Restrict container network access if needed
pct set 200 --net0 name=eth0,bridge=vmbr0,firewall=1,ip=dhcp,fw_macfilter=1
```

### Password Security

1. Change default passwords immediately after installation
2. Use strong passwords for production deployments
3. Consider using environment variable files with restricted permissions

### Container Security

```bash
# Update container regularly
pct exec 200 -- apt update && apt upgrade -y

# Update Docker images
pct exec 200 -- docker compose pull
pct exec 200 -- docker compose up -d
```

## Performance Tuning

### Resource Allocation

```bash
# Increase container resources if needed
pct set 200 --memory 4096 --cores 4

# Monitor resource usage
pct exec 200 -- htop
pct exec 200 -- df -h
```

### Data Retention

```bash
# Adjust retention for performance
# Edit .env
RETENTION_DAYS=14  # Reduce for better performance
RETENTION_DAYS=90  # Increase for longer history
```

### Collection Frequency

```bash
# Balance between data granularity and system load
COLLECTION_INTERVAL=60   # Less frequent, lower load
COLLECTION_INTERVAL=15   # More frequent, higher load
```

## Troubleshooting

### Common Issues

1. **Container won't start:**
   ```bash
   pct start 200 --debug
   ```

2. **Services not starting:**
   ```bash
   pct exec 200 -- docker compose logs
   ```

3. **No data in dashboard:**
   ```bash
   pct exec 200 -- docker compose logs network-collector
   ```

4. **Dashboard not accessible:**
   ```bash
   pct exec 200 -- docker compose ps
   pct exec 200 -- netstat -tlnp | grep 3000
   ```

### Log Locations

```bash
# Container logs
/var/log/pct/
/var/lib/lxc/200/

# Application logs (inside container)
docker compose logs
/var/lib/docker/containers/
```

This deployment guide provides comprehensive instructions for setting up and managing your network monitoring solution on Proxmox with GitHub integration.