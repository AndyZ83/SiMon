#!/bin/bash

# Network Performance Monitor - One-Line Installer for Proxmox
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/your-repo/network-monitor/main/install.sh)"

set -e

# Configuration
CONTAINER_ID=${CONTAINER_ID:-200}
CONTAINER_NAME="network-monitor"
TEMPLATE="ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
STORAGE="local-lvm"
MEMORY="2048"
DISK_SIZE="10G"
CORES="2"
PASSWORD="networkmonitor123"
NET_BRIDGE="vmbr0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Network Performance Monitor - One-Line Installer ===${NC}"
echo -e "${BLUE}This will create a complete network monitoring solution with Grafana + InfluxDB${NC}"
echo

# Check if running on Proxmox
if ! command -v pct &> /dev/null; then
    echo -e "${RED}Error: This script must be run on a Proxmox host${NC}"
    exit 1
fi

# Check if container ID is already in use
if pct list | grep -q "^${CONTAINER_ID} "; then
    echo -e "${YELLOW}Warning: Container ID ${CONTAINER_ID} already exists${NC}"
    read -p "Do you want to destroy the existing container and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Stopping and destroying existing container...${NC}"
        pct stop ${CONTAINER_ID} || true
        pct destroy ${CONTAINER_ID} || true
    else
        echo -e "${RED}Installation cancelled${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Creating LXC container...${NC}"

# Create the container
pct create ${CONTAINER_ID} ${TEMPLATE} \
    --hostname ${CONTAINER_NAME} \
    --memory ${MEMORY} \
    --cores ${CORES} \
    --rootfs ${STORAGE}:${DISK_SIZE} \
    --password ${PASSWORD} \
    --net0 name=eth0,bridge=${NET_BRIDGE},firewall=1,ip=dhcp \
    --features nesting=1 \
    --unprivileged 1 \
    --onboot 1 \
    --startup order=3

echo -e "${GREEN}Starting container...${NC}"
pct start ${CONTAINER_ID}

# Wait for container to be ready
echo -e "${YELLOW}Waiting for container to be ready...${NC}"
sleep 15

echo -e "${GREEN}Installing Docker and dependencies...${NC}"

# Install Docker and dependencies
pct exec ${CONTAINER_ID} -- bash -c "
    apt update
    apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable docker
    systemctl start docker
"

echo -e "${GREEN}Setting up network monitor application...${NC}"

# Create app directory
pct exec ${CONTAINER_ID} -- bash -c "mkdir -p /opt/network-monitor"

echo -e "${YELLOW}Creating configuration files...${NC}"

# Create docker-compose.yml
pct exec ${CONTAINER_ID} -- bash -c "cat > /opt/network-monitor/docker-compose.yml << 'EOF'
version: '3.8'

services:
  influxdb:
    image: influxdb:2.7-alpine
    container_name: network-monitor-influxdb
    restart: unless-stopped
    ports:
      - \"8086:8086\"
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=\${INFLUXDB_USERNAME:-admin}
      - DOCKER_INFLUXDB_INIT_PASSWORD=\${INFLUXDB_PASSWORD:-networkmonitor123}
      - DOCKER_INFLUXDB_INIT_ORG=\${INFLUXDB_ORG:-NetworkMonitoring}
      - DOCKER_INFLUXDB_INIT_BUCKET=\${INFLUXDB_BUCKET:-network_metrics}
      - DOCKER_INFLUXDB_INIT_RETENTION=\${RETENTION_DAYS:-30}d
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=\${INFLUXDB_TOKEN:-network-monitor-token-change-me}
    volumes:
      - influxdb-data:/var/lib/influxdb2
      - influxdb-config:/etc/influxdb2
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:10.2.0
    container_name: network-monitor-grafana
    restart: unless-stopped
    ports:
      - \"3000:3000\"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=\${GRAFANA_PASSWORD:-networkmonitor123}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_INSTALL_PLUGINS=grafana-worldmap-panel
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./grafana/datasources:/etc/grafana/provisioning/datasources
    networks:
      - monitoring
    depends_on:
      - influxdb

  network-collector:
    build: .
    container_name: network-monitor-collector
    restart: unless-stopped
    environment:
      - TARGET1=\${TARGET1:-8.8.8.8}
      - TARGET1_NAME=\${TARGET1_NAME:-Google DNS}
      - TARGET2=\${TARGET2:-1.1.1.1}
      - TARGET2_NAME=\${TARGET2_NAME:-Cloudflare DNS}
      - INFLUXDB_URL=http://influxdb:8086
      - INFLUXDB_TOKEN=\${INFLUXDB_TOKEN:-network-monitor-token-change-me}
      - INFLUXDB_ORG=\${INFLUXDB_ORG:-NetworkMonitoring}
      - INFLUXDB_BUCKET=\${INFLUXDB_BUCKET:-network_metrics}
      - COLLECTION_INTERVAL=\${COLLECTION_INTERVAL:-30}
    networks:
      - monitoring
    depends_on:
      - influxdb
    cap_add:
      - NET_RAW

volumes:
  grafana-data:
  influxdb-data:
  influxdb-config:

networks:
  monitoring:
    driver: bridge
EOF"

# Create Dockerfile
pct exec ${CONTAINER_ID} -- bash -c "cat > /opt/network-monitor/Dockerfile << 'EOF'
FROM python:3.11-alpine

# Install system dependencies
RUN apk add --no-cache \
    iputils \
    curl \
    bash \
    && pip install --no-cache-dir \
    influxdb-client \
    requests \
    psutil

# Create app directory
WORKDIR /app

# Copy collector script
COPY collector.py .
COPY entrypoint.sh .

# Make scripts executable
RUN chmod +x entrypoint.sh

# Run as non-root user
RUN adduser -D -s /bin/bash collector
USER collector

ENTRYPOINT [\"./entrypoint.sh\"]
EOF"

# Create collector.py
pct exec ${CONTAINER_ID} -- bash -c "cat > /opt/network-monitor/collector.py << 'EOF'
#!/usr/bin/env python3

import os
import time
import logging
import subprocess
import json
from datetime import datetime
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS
import requests

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class NetworkMonitor:
    def __init__(self):
        self.influx_url = os.getenv('INFLUXDB_URL', 'http://influxdb:8086')
        self.influx_token = os.getenv('INFLUXDB_TOKEN')
        self.influx_org = os.getenv('INFLUXDB_ORG', 'NetworkMonitoring')
        self.influx_bucket = os.getenv('INFLUXDB_BUCKET', 'network_metrics')
        
        self.target1 = os.getenv('TARGET1', '8.8.8.8')
        self.target1_name = os.getenv('TARGET1_NAME', 'Google DNS')
        self.target2 = os.getenv('TARGET2', '1.1.1.1')
        self.target2_name = os.getenv('TARGET2_NAME', 'Cloudflare DNS')
        
        self.collection_interval = int(os.getenv('COLLECTION_INTERVAL', '30'))
        
        # Initialize InfluxDB client
        self.client = InfluxDBClient(
            url=self.influx_url,
            token=self.influx_token,
            org=self.influx_org
        )
        self.write_api = self.client.write_api(write_options=SYNCHRONOUS)
        
        logger.info(f\"Monitoring targets: {self.target1_name} ({self.target1}), {self.target2_name} ({self.target2})\")
        logger.info(f\"Collection interval: {self.collection_interval} seconds\")

    def ping_target(self, target, target_name):
        \"\"\"Perform ping test and return metrics\"\"\"
        try:
            # Perform ping test (10 packets)
            result = subprocess.run(
                ['ping', '-c', '10', '-i', '0.2', target],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode != 0:
                logger.warning(f\"Ping to {target_name} ({target}) failed\")
                return {
                    'target': target,
                    'target_name': target_name,
                    'success': False,
                    'packet_loss': 100.0,
                    'avg_rtt': None,
                    'min_rtt': None,
                    'max_rtt': None,
                    'stddev_rtt': None
                }

            # Parse ping output
            output_lines = result.stdout.split('\n')
            
            # Extract packet loss
            packet_loss = 0.0
            for line in output_lines:
                if '% packet loss' in line:
                    packet_loss = float(line.split('%')[0].split()[-1])
                    break
            
            # Extract RTT statistics
            rtt_stats = None
            for line in output_lines:
                if 'min/avg/max/stddev' in line or 'min/avg/max/mdev' in line:
                    rtt_part = line.split('=')[-1].strip()
                    rtt_values = rtt_part.split('/')
                    if len(rtt_values) >= 4:
                        rtt_stats = {
                            'min': float(rtt_values[0]),
                            'avg': float(rtt_values[1]),
                            'max': float(rtt_values[2]),
                            'stddev': float(rtt_values[3].split()[0])
                        }
                    break
            
            if not rtt_stats:
                # Fallback parsing for different ping output formats
                rtt_stats = {'min': 0, 'avg': 0, 'max': 0, 'stddev': 0}
            
            return {
                'target': target,
                'target_name': target_name,
                'success': True,
                'packet_loss': packet_loss,
                'avg_rtt': rtt_stats['avg'],
                'min_rtt': rtt_stats['min'],
                'max_rtt': rtt_stats['max'],
                'stddev_rtt': rtt_stats['stddev']
            }
            
        except subprocess.TimeoutExpired:
            logger.error(f\"Ping to {target_name} ({target}) timed out\")
            return {
                'target': target,
                'target_name': target_name,
                'success': False,
                'packet_loss': 100.0,
                'avg_rtt': None,
                'min_rtt': None,
                'max_rtt': None,
                'stddev_rtt': None
            }
        except Exception as e:
            logger.error(f\"Error pinging {target_name} ({target}): {e}\")
            return {
                'target': target,
                'target_name': target_name,
                'success': False,
                'packet_loss': 100.0,
                'avg_rtt': None,
                'min_rtt': None,
                'max_rtt': None,
                'stddev_rtt': None
            }

    def perform_speed_test(self):
        \"\"\"Perform a basic speed test using curl\"\"\"
        try:
            # Download speed test (download 10MB file)
            start_time = time.time()
            result = subprocess.run([
                'curl', '-s', '-o', '/dev/null', '-w', '%{speed_download}',
                'http://speedtest.tele2.net/10MB.zip'
            ], capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                download_speed_bps = float(result.stdout.strip())
                download_speed_mbps = (download_speed_bps * 8) / (1024 * 1024)  # Convert to Mbps
            else:
                download_speed_mbps = 0
                
            # Upload speed test (upload small file)
            upload_result = subprocess.run([
                'curl', '-s', '-o', '/dev/null', '-w', '%{speed_upload}',
                '-F', 'file=@/dev/zero', '--form-string', 'size=1048576',
                'httpbin.org/post'
            ], capture_output=True, text=True, timeout=30)
            
            if upload_result.returncode == 0:
                upload_speed_bps = float(upload_result.stdout.strip())
                upload_speed_mbps = (upload_speed_bps * 8) / (1024 * 1024)  # Convert to Mbps
            else:
                upload_speed_mbps = 0
                
            return {
                'download_speed_mbps': round(download_speed_mbps, 2),
                'upload_speed_mbps': round(upload_speed_mbps, 2)
            }
            
        except Exception as e:
            logger.error(f\"Speed test failed: {e}\")
            return {
                'download_speed_mbps': 0,
                'upload_speed_mbps': 0
            }

    def write_metrics(self, metrics):
        \"\"\"Write metrics to InfluxDB\"\"\"
        try:
            points = []
            timestamp = datetime.utcnow()
            
            # Write ping metrics for each target
            for target_metrics in metrics['ping_results']:
                point = Point(\"network_performance\") \
                    .tag(\"target\", target_metrics['target']) \
                    .tag(\"target_name\", target_metrics['target_name']) \
                    .field(\"success\", target_metrics['success']) \
                    .field(\"packet_loss\", target_metrics['packet_loss']) \
                    .time(timestamp)
                
                if target_metrics['avg_rtt'] is not None:
                    point = point.field(\"avg_rtt\", target_metrics['avg_rtt']) \
                               .field(\"min_rtt\", target_metrics['min_rtt']) \
                               .field(\"max_rtt\", target_metrics['max_rtt']) \
                               .field(\"stddev_rtt\", target_metrics['stddev_rtt'])
                
                points.append(point)
            
            # Write speed test metrics
            speed_point = Point(\"network_speed\") \
                .field(\"download_speed_mbps\", metrics['speed_test']['download_speed_mbps']) \
                .field(\"upload_speed_mbps\", metrics['speed_test']['upload_speed_mbps']) \
                .time(timestamp)
            points.append(speed_point)
            
            # Write all points
            self.write_api.write(
                bucket=self.influx_bucket,
                org=self.influx_org,
                record=points
            )
            
            logger.info(\"Metrics written to InfluxDB successfully\")
            
        except Exception as e:
            logger.error(f\"Failed to write metrics to InfluxDB: {e}\")

    def collect_metrics(self):
        \"\"\"Collect all network metrics\"\"\"
        logger.info(\"Starting metrics collection...\")
        
        # Perform ping tests
        ping_results = [
            self.ping_target(self.target1, self.target1_name),
            self.ping_target(self.target2, self.target2_name)
        ]
        
        # Perform speed test (less frequently)
        speed_test = self.perform_speed_test()
        
        metrics = {
            'ping_results': ping_results,
            'speed_test': speed_test,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        # Log summary
        for result in ping_results:
            if result['success']:
                logger.info(f\"{result['target_name']}: {result['avg_rtt']:.1f}ms RTT, {result['packet_loss']:.1f}% loss\")
            else:
                logger.warning(f\"{result['target_name']}: FAILED\")
        
        logger.info(f\"Speed: {speed_test['download_speed_mbps']:.1f} Mbps down, {speed_test['upload_speed_mbps']:.1f} Mbps up\")
        
        return metrics

    def run(self):
        \"\"\"Main monitoring loop\"\"\"
        logger.info(\"Starting network monitoring...\")
        
        while True:
            try:
                # Collect metrics
                metrics = self.collect_metrics()
                
                # Write to InfluxDB
                self.write_metrics(metrics)
                
                # Wait for next collection
                time.sleep(self.collection_interval)
                
            except KeyboardInterrupt:
                logger.info(\"Monitoring stopped by user\")
                break
            except Exception as e:
                logger.error(f\"Error in monitoring loop: {e}\")
                time.sleep(10)  # Wait before retrying

if __name__ == \"__main__\":
    monitor = NetworkMonitor()
    monitor.run()
EOF"

# Create entrypoint.sh
pct exec ${CONTAINER_ID} -- bash -c "cat > /opt/network-monitor/entrypoint.sh << 'EOF'
#!/bin/bash

echo \"Starting Network Monitor Collector...\"
echo \"Targets: \$TARGET1_NAME (\$TARGET1), \$TARGET2_NAME (\$TARGET2)\"
echo \"Collection interval: \${COLLECTION_INTERVAL}s\"
echo \"Retention: \${RETENTION_DAYS} days\"

# Wait for InfluxDB to be ready
echo \"Waiting for InfluxDB to be ready...\"
while ! curl -f -s \$INFLUXDB_URL/health > /dev/null; do
    echo \"InfluxDB not ready, waiting...\"
    sleep 5
done

echo \"InfluxDB is ready, starting collector...\"
exec python3 collector.py
EOF"

# Create .env file
pct exec ${CONTAINER_ID} -- bash -c "cat > /opt/network-monitor/.env << 'EOF'
# Network Monitoring Configuration

# Monitoring Targets
TARGET1=8.8.8.8
TARGET1_NAME=Google DNS
TARGET2=1.1.1.1
TARGET2_NAME=Cloudflare DNS

# Data Retention (days)
RETENTION_DAYS=30

# Collection Settings
COLLECTION_INTERVAL=30

# InfluxDB Configuration
INFLUXDB_USERNAME=admin
INFLUXDB_PASSWORD=networkmonitor123
INFLUXDB_ORG=NetworkMonitoring
INFLUXDB_BUCKET=network_metrics
INFLUXDB_TOKEN=network-monitor-token-change-me

# Grafana Configuration
GRAFANA_PASSWORD=networkmonitor123
EOF"

# Create Grafana configuration directories and files
pct exec ${CONTAINER_ID} -- bash -c "
mkdir -p /opt/network-monitor/grafana/datasources
mkdir -p /opt/network-monitor/grafana/dashboards
"

# Create datasource configuration
pct exec ${CONTAINER_ID} -- bash -c "cat > /opt/network-monitor/grafana/datasources/influxdb.yml << 'EOF'
apiVersion: 1

datasources:
  - name: InfluxDB
    type: influxdb
    access: proxy
    url: http://influxdb:8086
    jsonData:
      version: Flux
      organization: NetworkMonitoring
      defaultBucket: network_metrics
      tlsSkipVerify: true
    secureJsonData:
      token: network-monitor-token-change-me
    isDefault: true
EOF"

# Create dashboard provisioning
pct exec ${CONTAINER_ID} -- bash -c "cat > /opt/network-monitor/grafana/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF"

# Create the main dashboard
pct exec ${CONTAINER_ID} -- bash -c "cat > /opt/network-monitor/grafana/dashboards/network-monitoring.json << 'EOF'
{
  \"annotations\": {
    \"list\": [
      {
        \"builtIn\": 1,
        \"datasource\": {
          \"type\": \"datasource\",
          \"uid\": \"grafana\"
        },
        \"enable\": true,
        \"hide\": true,
        \"iconColor\": \"rgba(0, 211, 255, 1)\",
        \"name\": \"Annotations & Alerts\",
        \"type\": \"dashboard\"
      }
    ]
  },
  \"editable\": true,
  \"fiscalYearStartMonth\": 0,
  \"graphTooltip\": 0,
  \"id\": null,
  \"links\": [],
  \"liveNow\": false,
  \"panels\": [
    {
      \"datasource\": {
        \"type\": \"influxdb\",
        \"uid\": \"InfluxDB\"
      },
      \"fieldConfig\": {
        \"defaults\": {
          \"color\": {
            \"mode\": \"palette-classic\"
          },
          \"custom\": {
            \"axisLabel\": \"\",
            \"axisPlacement\": \"auto\",
            \"barAlignment\": 0,
            \"drawStyle\": \"line\",
            \"fillOpacity\": 10,
            \"gradientMode\": \"none\",
            \"hideFrom\": {
              \"legend\": false,
              \"tooltip\": false,
              \"vis\": false
            },
            \"lineInterpolation\": \"linear\",
            \"lineWidth\": 2,
            \"pointSize\": 5,
            \"scaleDistribution\": {
              \"type\": \"linear\"
            },
            \"showPoints\": \"never\",
            \"spanNulls\": false,
            \"stacking\": {
              \"group\": \"A\",
              \"mode\": \"none\"
            },
            \"thresholdsStyle\": {
              \"mode\": \"off\"
            }
          },
          \"mappings\": [],
          \"thresholds\": {
            \"mode\": \"absolute\",
            \"steps\": [
              {
                \"color\": \"green\",
                \"value\": null
              },
              {
                \"color\": \"red\",
                \"value\": 80
              }
            ]
          },
          \"unit\": \"ms\"
        },
        \"overrides\": []
      },
      \"gridPos\": {
        \"h\": 8,
        \"w\": 12,
        \"x\": 0,
        \"y\": 0
      },
      \"id\": 1,
      \"options\": {
        \"legend\": {
          \"calcs\": [],
          \"displayMode\": \"list\",
          \"placement\": \"bottom\"
        },
        \"tooltip\": {
          \"mode\": \"single\",
          \"sort\": \"none\"
        }
      },
      \"targets\": [
        {
          \"datasource\": {
            \"type\": \"influxdb\",
            \"uid\": \"InfluxDB\"
          },
          \"query\": \"from(bucket: \\\"network_metrics\\\")\\n  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)\\n  |> filter(fn: (r) => r[\\\"_measurement\\\"] == \\\"network_performance\\\")\\n  |> filter(fn: (r) => r[\\\"_field\\\"] == \\\"avg_rtt\\\")\\n  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)\\n  |> yield(name: \\\"mean\\\")\",
          \"refId\": \"A\"
        }
      ],
      \"title\": \"Average Round Trip Time (RTT)\",
      \"type\": \"timeseries\"
    },
    {
      \"datasource\": {
        \"type\": \"influxdb\",
        \"uid\": \"InfluxDB\"
      },
      \"fieldConfig\": {
        \"defaults\": {
          \"color\": {
            \"mode\": \"palette-classic\"
          },
          \"custom\": {
            \"axisLabel\": \"\",
            \"axisPlacement\": \"auto\",
            \"barAlignment\": 0,
            \"drawStyle\": \"line\",
            \"fillOpacity\": 10,
            \"gradientMode\": \"none\",
            \"hideFrom\": {
              \"legend\": false,
              \"tooltip\": false,
              \"vis\": false
            },
            \"lineInterpolation\": \"linear\",
            \"lineWidth\": 2,
            \"pointSize\": 5,
            \"scaleDistribution\": {
              \"type\": \"linear\"
            },
            \"showPoints\": \"never\",
            \"spanNulls\": false,
            \"stacking\": {
              \"group\": \"A\",
              \"mode\": \"none\"
            },
            \"thresholdsStyle\": {
              \"mode\": \"off\"
            }
          },
          \"mappings\": [],
          \"max\": 100,
          \"min\": 0,
          \"thresholds\": {
            \"mode\": \"absolute\",
            \"steps\": [
              {
                \"color\": \"green\",
                \"value\": null
              },
              {
                \"color\": \"yellow\",
                \"value\": 1
              },
              {
                \"color\": \"red\",
                \"value\": 5
              }
            ]
          },
          \"unit\": \"percent\"
        },
        \"overrides\": []
      },
      \"gridPos\": {
        \"h\": 8,
        \"w\": 12,
        \"x\": 12,
        \"y\": 0
      },
      \"id\": 2,
      \"options\": {
        \"legend\": {
          \"calcs\": [],
          \"displayMode\": \"list\",
          \"placement\": \"bottom\"
        },
        \"tooltip\": {
          \"mode\": \"single\",
          \"sort\": \"none\"
        }
      },
      \"targets\": [
        {
          \"datasource\": {
            \"type\": \"influxdb\",
            \"uid\": \"InfluxDB\"
          },
          \"query\": \"from(bucket: \\\"network_metrics\\\")\\n  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)\\n  |> filter(fn: (r) => r[\\\"_measurement\\\"] == \\\"network_performance\\\")\\n  |> filter(fn: (r) => r[\\\"_field\\\"] == \\\"packet_loss\\\")\\n  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)\\n  |> yield(name: \\\"mean\\\")\",
          \"refId\": \"A\"
        }
      ],
      \"title\": \"Packet Loss Percentage\",
      \"type\": \"timeseries\"
    },
    {
      \"datasource\": {
        \"type\": \"influxdb\",
        \"uid\": \"InfluxDB\"
      },
      \"fieldConfig\": {
        \"defaults\": {
          \"color\": {
            \"mode\": \"palette-classic\"
          },
          \"custom\": {
            \"axisLabel\": \"\",
            \"axisPlacement\": \"auto\",
            \"barAlignment\": 0,
            \"drawStyle\": \"line\",
            \"fillOpacity\": 10,
            \"gradientMode\": \"none\",
            \"hideFrom\": {
              \"legend\": false,
              \"tooltip\": false,
              \"vis\": false
            },
            \"lineInterpolation\": \"linear\",
            \"lineWidth\": 2,
            \"pointSize\": 5,
            \"scaleDistribution\": {
              \"type\": \"linear\"
            },
            \"showPoints\": \"never\",
            \"spanNulls\": false,
            \"stacking\": {
              \"group\": \"A\",
              \"mode\": \"none\"
            },
            \"thresholdsStyle\": {
              \"mode\": \"off\"
            }
          },
          \"mappings\": [],
          \"thresholds\": {
            \"mode\": \"absolute\",
            \"steps\": [
              {
                \"color\": \"green\",
                \"value\": null
              },
              {
                \"color\": \"red\",
                \"value\": 80
              }
            ]
          },
          \"unit\": \"Mbits\"
        },
        \"overrides\": []
      },
      \"gridPos\": {
        \"h\": 8,
        \"w\": 24,
        \"x\": 0,
        \"y\": 8
      },
      \"id\": 3,
      \"options\": {
        \"legend\": {
          \"calcs\": [],
          \"displayMode\": \"list\",
          \"placement\": \"bottom\"
        },
        \"tooltip\": {
          \"mode\": \"single\",
          \"sort\": \"none\"
        }
      },
      \"targets\": [
        {
          \"datasource\": {
            \"type\": \"influxdb\",
            \"uid\": \"InfluxDB\"
          },
          \"query\": \"from(bucket: \\\"network_metrics\\\")\\n  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)\\n  |> filter(fn: (r) => r[\\\"_measurement\\\"] == \\\"network_speed\\\")\\n  |> filter(fn: (r) => r[\\\"_field\\\"] == \\\"download_speed_mbps\\\" or r[\\\"_field\\\"] == \\\"upload_speed_mbps\\\")\\n  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)\\n  |> yield(name: \\\"mean\\\")\",
          \"refId\": \"A\"
        }
      ],
      \"title\": \"Internet Speed (Download/Upload)\",
      \"type\": \"timeseries\"
    },
    {
      \"datasource\": {
        \"type\": \"influxdb\",
        \"uid\": \"InfluxDB\"
      },
      \"fieldConfig\": {
        \"defaults\": {
          \"color\": {
            \"mode\": \"thresholds\"
          },
          \"mappings\": [
            {
              \"options\": {
                \"0\": {
                  \"color\": \"red\",
                  \"index\": 1,
                  \"text\": \"OFFLINE\"
                },
                \"1\": {
                  \"color\": \"green\",
                  \"index\": 0,
                  \"text\": \"ONLINE\"
                }
              },
              \"type\": \"value\"
            }
          ],
          \"thresholds\": {
            \"mode\": \"absolute\",
            \"steps\": [
              {
                \"color\": \"green\",
                \"value\": null
              },
              {
                \"color\": \"red\",
                \"value\": 0
              }
            ]
          }
        },
        \"overrides\": []
      },
      \"gridPos\": {
        \"h\": 4,
        \"w\": 12,
        \"x\": 0,
        \"y\": 16
      },
      \"id\": 4,
      \"options\": {
        \"colorMode\": \"background\",
        \"graphMode\": \"none\",
        \"justifyMode\": \"center\",
        \"orientation\": \"horizontal\",
        \"reduceOptions\": {
          \"calcs\": [
            \"lastNotNull\"
          ],
          \"fields\": \"\",
          \"values\": false
        },
        \"textMode\": \"auto\"
      },
      \"pluginVersion\": \"10.2.0\",
      \"targets\": [
        {
          \"datasource\": {
            \"type\": \"influxdb\",
            \"uid\": \"InfluxDB\"
          },
          \"query\": \"from(bucket: \\\"network_metrics\\\")\\n  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)\\n  |> filter(fn: (r) => r[\\\"_measurement\\\"] == \\\"network_performance\\\")\\n  |> filter(fn: (r) => r[\\\"_field\\\"] == \\\"success\\\")\\n  |> last()\\n  |> map(fn: (r) => ({ r with _value: if r._value then 1 else 0 }))\",
          \"refId\": \"A\"
        }
      ],
      \"title\": \"Connection Status\",
      \"type\": \"stat\"
    },
    {
      \"datasource\": {
        \"type\": \"influxdb\",
        \"uid\": \"InfluxDB\"
      },
      \"fieldConfig\": {
        \"defaults\": {
          \"color\": {
            \"mode\": \"palette-classic\"
          },
          \"custom\": {
            \"hideFrom\": {
              \"legend\": false,
              \"tooltip\": false,
              \"vis\": false
            }
          },
          \"mappings\": []
        },
        \"overrides\": []
      },
      \"gridPos\": {
        \"h\": 4,
        \"w\": 12,
        \"x\": 12,
        \"y\": 16
      },
      \"id\": 5,
      \"options\": {
        \"legend\": {
          \"displayMode\": \"list\",
          \"placement\": \"right\"
        },
        \"pieType\": \"pie\",
        \"reduceOptions\": {
          \"calcs\": [
            \"lastNotNull\"
          ],
          \"fields\": \"\",
          \"values\": false
        },
        \"tooltip\": {
          \"mode\": \"single\",
          \"sort\": \"none\"
        }
      },
      \"targets\": [
        {
          \"datasource\": {
            \"type\": \"influxdb\",
            \"uid\": \"InfluxDB\"
          },
          \"query\": \"from(bucket: \\\"network_metrics\\\")\\n  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)\\n  |> filter(fn: (r) => r[\\\"_measurement\\\"] == \\\"network_performance\\\")\\n  |> filter(fn: (r) => r[\\\"_field\\\"] == \\\"success\\\")\\n  |> group(columns: [\\\"target_name\\\"])\\n  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)\\n  |> yield(name: \\\"mean\\\")\",
          \"refId\": \"A\"
        }
      ],
      \"title\": \"Target Availability\",
      \"type\": \"piechart\"
    }
  ],
  \"refresh\": \"30s\",
  \"schemaVersion\": 37,
  \"style\": \"dark\",
  \"tags\": [
    \"network\",
    \"monitoring\",
    \"isp\"
  ],
  \"templating\": {
    \"list\": []
  },
  \"time\": {
    \"from\": \"now-1h\",
    \"to\": \"now\"
  },
  \"timepicker\": {},
  \"timezone\": \"\",
  \"title\": \"Network Performance Monitor - ISP Report\",
  \"uid\": \"network-monitor\",
  \"version\": 1,
  \"weekStart\": \"\"
}
EOF"

# Set proper permissions
pct exec ${CONTAINER_ID} -- bash -c "
cd /opt/network-monitor
chmod +x entrypoint.sh
chown -R root:root .
"

echo -e "${GREEN}Building and starting the monitoring stack...${NC}"

# Build and start the stack
pct exec ${CONTAINER_ID} -- bash -c "
cd /opt/network-monitor
docker compose up -d
"

# Wait for services to start
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 30

# Get container IP
CONTAINER_IP=$(pct exec ${CONTAINER_ID} -- ip route get 1 | awk '{print $7; exit}')

echo
echo -e "${GREEN}=== Installation Complete! ===${NC}"
echo
echo -e "${GREEN}Container Details:${NC}"
echo "  Container ID: ${CONTAINER_ID}"
echo "  Container Name: ${CONTAINER_NAME}"
echo "  IP Address: ${CONTAINER_IP}"
echo "  Root Password: ${PASSWORD}"
echo
echo -e "${GREEN}Access URLs:${NC}"
echo "  Grafana: http://${CONTAINER_IP}:3000"
echo "    Username: admin"
echo "    Password: networkmonitor123"
echo
echo "  InfluxDB: http://${CONTAINER_IP}:8086"
echo "    Username: admin"
echo "    Password: networkmonitor123"
echo
echo -e "${GREEN}Configuration:${NC}"
echo "  Edit /opt/network-monitor/.env in the container to customize:"
echo "  - Monitoring targets (TARGET1, TARGET2)"
echo "  - Collection interval"
echo "  - Data retention period"
echo
echo -e "${YELLOW}To customize configuration:${NC}"
echo "  1. pct enter ${CONTAINER_ID}"
echo "  2. cd /opt/network-monitor"
echo "  3. nano .env"
echo "  4. docker compose restart"
echo
echo -e "${GREEN}The network monitor is now running and collecting data!${NC}"
echo -e "${BLUE}Dashboard will be available in ~2 minutes after initial data collection.${NC}"