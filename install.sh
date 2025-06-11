#!/bin/bash

# Network Performance Monitor - GitHub-Integrated One-Line Installer for Proxmox
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh)"

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

# GitHub Repository Configuration
GITHUB_REPO="https://github.com/YOUR_USERNAME/YOUR_REPO.git"
GITHUB_RAW_URL="https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Network Performance Monitor - GitHub-Integrated Installer ===${NC}"
echo -e "${BLUE}This will create a complete network monitoring solution with Grafana + InfluxDB${NC}"
echo -e "${BLUE}Source: ${GITHUB_REPO}${NC}"
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

echo -e "${GREEN}Installing Docker, Git and dependencies...${NC}"

# Install Docker and dependencies
pct exec ${CONTAINER_ID} -- bash -c "
    apt update
    apt install -y apt-transport-https ca-certificates curl gnupg lsb-release git
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable docker
    systemctl start docker
"

echo -e "${GREEN}Cloning network monitor from GitHub...${NC}"

# Clone the repository
pct exec ${CONTAINER_ID} -- bash -c "
    cd /opt
    git clone ${GITHUB_REPO} network-monitor
    cd network-monitor
    
    # Create .env file if it doesn't exist
    if [ ! -f .env ]; then
        cp .env.example .env
    fi
    
    # Set proper permissions
    chmod +x entrypoint.sh
    chmod +x deploy-proxmox.sh
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
echo "  Grafana Dashboard: http://${CONTAINER_IP}:3000"
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
echo "  - Collection interval (COLLECTION_INTERVAL)"
echo "  - Data retention period (RETENTION_DAYS)"
echo
echo -e "${YELLOW}To customize configuration:${NC}"
echo "  1. pct enter ${CONTAINER_ID}"
echo "  2. cd /opt/network-monitor"
echo "  3. nano .env"
echo "  4. docker compose restart"
echo
echo -e "${GREEN}GitHub Repository Integration:${NC}"
echo "  Source Code: ${GITHUB_REPO}"
echo "  Updates: Pull latest changes with 'git pull' in /opt/network-monitor"
echo
echo -e "${GREEN}The network monitor is now running and collecting data!${NC}"
echo -e "${BLUE}Dashboard will be available in ~2 minutes after initial data collection.${NC}"
echo
echo -e "${YELLOW}Professional ISP Reporting Features:${NC}"
echo "  ✓ Real-time latency monitoring"
echo "  ✓ Packet loss tracking"
echo "  ✓ Speed test measurements"
echo "  ✓ Historical data retention"
echo "  ✓ Professional Grafana dashboards"
echo "  ✓ Export capabilities for ISP reports"