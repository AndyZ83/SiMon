#!/bin/bash

# Network Performance Monitor - Proxmox Deployment Script
# This script creates an LXC container on Proxmox for network monitoring

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
NC='\033[0m' # No Color

echo -e "${GREEN}=== Network Performance Monitor - Proxmox Deployment ===${NC}"
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
        echo -e "${RED}Deployment cancelled${NC}"
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
sleep 10

echo -e "${GREEN}Installing Docker and dependencies...${NC}"

# Install Docker and dependencies
pct exec ${CONTAINER_ID} -- bash -c "
    apt update
    apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin git
    systemctl enable docker
    systemctl start docker
"

echo -e "${GREEN}Setting up network monitor application...${NC}"

# Create app directory and copy files
pct exec ${CONTAINER_ID} -- bash -c "
    mkdir -p /opt/network-monitor
    cd /opt/network-monitor
"

# Copy project files to container
echo -e "${YELLOW}Copying project files...${NC}"

# Create temporary directory for transfer
TEMP_DIR="/tmp/network-monitor-$$"
mkdir -p "$TEMP_DIR"

# Copy current directory contents to temp
cp -r . "$TEMP_DIR/"

# Transfer to container
pct push ${CONTAINER_ID} "$TEMP_DIR" /opt/network-monitor --user root --group root

# Clean up temp directory
rm -rf "$TEMP_DIR"

# Set up environment and start services
pct exec ${CONTAINER_ID} -- bash -c "
    cd /opt/network-monitor
    
    # Create .env file if it doesn't exist
    if [ ! -f .env ]; then
        cp .env.example .env
    fi
    
    # Make sure the collector directory exists and has proper permissions
    mkdir -p grafana/dashboards grafana/datasources
    chown -R root:root .
    chmod +x entrypoint.sh
    
    # Build and start the stack
    docker compose up -d
"

# Get container IP
CONTAINER_IP=$(pct exec ${CONTAINER_ID} -- ip route get 1 | awk '{print $7; exit}')

echo
echo -e "${GREEN}=== Deployment Complete! ===${NC}"
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
echo "  1. SSH to Proxmox host"
echo "  2. pct enter ${CONTAINER_ID}"
echo "  3. cd /opt/network-monitor"
echo "  4. nano .env"
echo "  5. docker compose restart"
echo
echo -e "${GREEN}The network monitor is now running and collecting data!${NC}"