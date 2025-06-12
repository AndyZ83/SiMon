#!/bin/bash

# Network Performance Monitor - Interactive Proxmox Installation Wizard with Rollback
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/AndyZ83/SiMon/main/install.sh)"

set -e

# GitHub Repository Configuration
GITHUB_REPO="https://github.com/AndyZ83/SiMon.git"
GITHUB_RAW_URL="https://raw.githubusercontent.com/AndyZ83/SiMon/main"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Global variables for rollback
CONTAINER_CREATED=false
CONTAINER_STARTED=false
INSTALLATION_FAILED=false

# Default values
DEFAULT_CONTAINER_ID="200"
DEFAULT_CONTAINER_NAME="network-monitor"
DEFAULT_STORAGE="local-lvm"
DEFAULT_MEMORY="2048"
DEFAULT_DISK_SIZE="10"
DEFAULT_CORES="2"
DEFAULT_PASSWORD="networkmonitor123"
DEFAULT_NET_BRIDGE="vmbr0"

# Rollback function
perform_rollback() {
    local exit_code=$1
    echo
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}                            ${BOLD}${RED}INSTALLATION FAILED${NC}                             ${RED}║${NC}"
    echo -e "${RED}║${NC}                          ${YELLOW}Performing automatic rollback...${NC}                    ${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    if [ "$CONTAINER_CREATED" = true ]; then
        echo -e "${YELLOW}Cleaning up container ${CONTAINER_ID}...${NC}"
        
        # Stop container if it was started
        if [ "$CONTAINER_STARTED" = true ]; then
            echo -e "${BLUE}Stopping container...${NC}"
            pct stop ${CONTAINER_ID} 2>/dev/null || true
            sleep 3
        fi
        
        # Destroy container
        echo -e "${BLUE}Destroying container...${NC}"
        pct destroy ${CONTAINER_ID} 2>/dev/null || true
        sleep 2
        
        # Verify cleanup
        if pct list | grep -q "^${CONTAINER_ID} "; then
            echo -e "${RED}Warning: Container ${CONTAINER_ID} still exists. Manual cleanup may be required.${NC}"
            echo -e "${YELLOW}Run: pct stop ${CONTAINER_ID} && pct destroy ${CONTAINER_ID}${NC}"
        else
            echo -e "${GREEN}Container ${CONTAINER_ID} successfully removed${NC}"
        fi
    fi
    
    echo
    echo -e "${YELLOW}Rollback completed. System restored to previous state.${NC}"
    echo -e "${BLUE}You can run the installer again to retry.${NC}"
    echo
    exit $exit_code
}

# Error trap for automatic rollback
trap 'INSTALLATION_FAILED=true; perform_rollback 1' ERR

# Function to display header
show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${BOLD}${GREEN}Network Performance Monitor${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                     ${BLUE}Interactive Proxmox Installer${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}Professional ISP Reporting Solution with Auto-Rollback${NC}                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} • Real-time latency and packet loss monitoring                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} • Grafana dashboards with InfluxDB backend                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} • Automated speed testing and historical data retention                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} • Automatic cleanup on installation failure                             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} • Source: ${GITHUB_REPO}${NC}                ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Function to get user input with default value
get_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    echo -e "${YELLOW}${prompt}${NC}"
    if [ -n "$default" ]; then
        echo -e "${CYAN}Default: ${default}${NC}"
    fi
    echo -n "Enter value: "
    read -r input
    
    if [ -z "$input" ]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$input\""
    fi
}

# Function to get yes/no input
get_yes_no() {
    local prompt="$1"
    local default="$2"
    
    while true; do
        echo -e "${YELLOW}${prompt}${NC}"
        if [ "$default" = "y" ]; then
            echo -n "Enter choice [Y/n]: "
        else
            echo -n "Enter choice [y/N]: "
        fi
        read -r input
        
        if [ -z "$input" ]; then
            input="$default"
        fi
        
        case "$input" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo -e "${RED}Please enter y or n${NC}" ;;
        esac
    done
}

# Function to validate storage
validate_storage() {
    local storage="$1"
    if pvesm status | grep -q "^$storage "; then
        return 0
    else
        return 1
    fi
}

# Function to validate container ID
validate_container_id() {
    local id="$1"
    if [[ "$id" =~ ^[0-9]+$ ]] && [ "$id" -ge 100 ] && [ "$id" -le 999999999 ]; then
        return 0
    else
        return 1
    fi
}

# Function to validate disk size
validate_disk_size() {
    local size="$1"
    if [[ "$size" =~ ^[0-9]+$ ]] && [ "$size" -ge 8 ] && [ "$size" -le 1000 ]; then
        return 0
    else
        return 1
    fi
}

# Function to list available storages with details
list_storages() {
    echo -e "${CYAN}Available storage locations:${NC}"
    pvesm status | grep -E "(local-lvm|local|dir|zfs|ceph)" | while read -r line; do
        storage_name=$(echo "$line" | awk '{print $1}')
        storage_type=$(echo "$line" | awk '{print $2}')
        storage_status=$(echo "$line" | awk '{print $3}')
        if [ "$storage_status" = "active" ]; then
            echo -e "  • ${GREEN}${storage_name}${NC} (${storage_type})"
        else
            echo -e "  • ${YELLOW}${storage_name}${NC} (${storage_type}) - ${storage_status}"
        fi
    done
    echo
}

# Function to get available templates using pveam
get_available_templates() {
    echo -e "${BLUE}Scanning for available templates...${NC}"
    
    # Update template list first
    echo -e "${BLUE}Updating template repository...${NC}"
    pveam update >/dev/null 2>&1 || true
    
    # Get list of available templates from pveam
    local available_templates=()
    
    # Check what's already downloaded
    if [ -d "/var/lib/vz/template/cache" ]; then
        while IFS= read -r -d '' template_file; do
            if [ -f "$template_file" ]; then
                template_name=$(basename "$template_file")
                if [[ "$template_name" == *ubuntu* ]] || [[ "$template_name" == *debian* ]]; then
                    available_templates+=("$template_name (downloaded)")
                fi
            fi
        done < <(find /var/lib/vz/template/cache -name "*.tar.*" -print0 2>/dev/null)
    fi
    
    # Get downloadable templates
    local downloadable=$(pveam available 2>/dev/null | grep -E "(ubuntu|debian)" | grep -E "(22\.04|20\.04|11\.|12\.)" | head -5 | awk '{print $2}' | sed 's/.*://')
    
    if [ -n "$downloadable" ]; then
        while IFS= read -r template; do
            if [ -n "$template" ]; then
                # Check if already in downloaded list
                local already_listed=false
                for downloaded in "${available_templates[@]}"; do
                    if [[ "$downloaded" == "$template"* ]]; then
                        already_listed=true
                        break
                    fi
                done
                if [ "$already_listed" = false ]; then
                    available_templates+=("$template (available for download)")
                fi
            fi
        done <<< "$downloadable"
    fi
    
    # If no templates found, provide fallback options
    if [ ${#available_templates[@]} -eq 0 ]; then
        available_templates+=(
            "ubuntu-22.04-standard_22.04-1_amd64.tar.zst (fallback)"
            "ubuntu-20.04-standard_20.04-1_amd64.tar.zst (fallback)"
            "debian-11-standard_11.7-1_amd64.tar.zst (fallback)"
        )
    fi
    
    printf '%s\n' "${available_templates[@]}"
}

# Function to list available templates
list_templates() {
    echo -e "${CYAN}Available templates:${NC}"
    get_available_templates | while read -r template; do
        if [ -n "$template" ]; then
            if [[ "$template" == *"(downloaded)"* ]]; then
                echo -e "  • ${GREEN}${template}${NC}"
            elif [[ "$template" == *"(available for download)"* ]]; then
                echo -e "  • ${YELLOW}${template}${NC}"
            else
                echo -e "  • ${BLUE}${template}${NC}"
            fi
        fi
    done
    echo
}

# Function to ensure template is available using pveam
ensure_template_available() {
    local requested_template="$1"
    
    # Clean template name (remove status indicators)
    local clean_template=$(echo "$requested_template" | sed 's/ (downloaded)//g' | sed 's/ (available for download)//g' | sed 's/ (fallback)//g')
    
    echo -e "${BLUE}Ensuring template availability: ${clean_template}${NC}"
    
    # Check if template is already downloaded
    if [ -f "/var/lib/vz/template/cache/${clean_template}" ]; then
        echo -e "${GREEN}Template already available: ${clean_template}${NC}"
        FINAL_TEMPLATE="$clean_template"
        return 0
    fi
    
    # Try to download using pveam
    echo -e "${BLUE}Downloading template: ${clean_template}${NC}"
    
    # First, update the template list
    pveam update >/dev/null 2>&1 || true
    
    # Try to download the specific template
    if pveam download local "$clean_template" 2>/dev/null; then
        echo -e "${GREEN}Template downloaded successfully: ${clean_template}${NC}"
        if [ -f "/var/lib/vz/template/cache/${clean_template}" ]; then
            FINAL_TEMPLATE="$clean_template"
            return 0
        fi
    fi
    
    echo -e "${YELLOW}Failed to download specific template, trying alternatives...${NC}"
    
    # Try alternative templates in order of preference
    local alternatives=(
        "ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
        "ubuntu-20.04-standard_20.04-1_amd64.tar.zst"
        "debian-11-standard_11.7-1_amd64.tar.zst"
        "debian-12-standard_12.2-1_amd64.tar.zst"
    )
    
    for alt_template in "${alternatives[@]}"; do
        echo -e "${BLUE}Trying alternative: ${alt_template}${NC}"
        
        # Check if already exists
        if [ -f "/var/lib/vz/template/cache/${alt_template}" ]; then
            echo -e "${GREEN}Found existing template: ${alt_template}${NC}"
            FINAL_TEMPLATE="$alt_template"
            return 0
        fi
        
        # Try to download
        if pveam download local "$alt_template" 2>/dev/null; then
            echo -e "${GREEN}Downloaded alternative template: ${alt_template}${NC}"
            if [ -f "/var/lib/vz/template/cache/${alt_template}" ]; then
                FINAL_TEMPLATE="$alt_template"
                return 0
            fi
        fi
    done
    
    echo -e "${RED}Failed to download any suitable template${NC}"
    echo -e "${YELLOW}Please manually download a template using:${NC}"
    echo -e "${CYAN}pveam update${NC}"
    echo -e "${CYAN}pveam available | grep -E '(ubuntu|debian)'${NC}"
    echo -e "${CYAN}pveam download local <template-name>${NC}"
    return 1
}

# Function to list network bridges
list_bridges() {
    echo -e "${CYAN}Available network bridges:${NC}"
    if ip link show 2>/dev/null | grep -E "^[0-9]+: vmbr" >/dev/null; then
        ip link show | grep -E "^[0-9]+: vmbr" | awk -F': ' '{print "  • " $2}' | awk '{print $1}'
    else
        echo "  • vmbr0 (default)"
        echo "  • vmbr1"
    fi
    echo
}

# Check if running on Proxmox
check_proxmox() {
    if ! command -v pct &> /dev/null; then
        echo -e "${RED}Error: This script must be run on a Proxmox VE host${NC}"
        echo -e "${YELLOW}Please run this script directly on your Proxmox server${NC}"
        exit 1
    fi
    
    if ! command -v pvesm &> /dev/null; then
        echo -e "${RED}Error: Proxmox storage management tools not found${NC}"
        exit 1
    fi
    
    if ! command -v pveam &> /dev/null; then
        echo -e "${RED}Error: Proxmox template management tools not found${NC}"
        exit 1
    fi
}

# Function to check and cleanup existing container
check_existing_container() {
    if pct list | grep -q "^${CONTAINER_ID} "; then
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${NC}                        ${BOLD}${YELLOW}EXISTING CONTAINER DETECTED${NC}                        ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${YELLOW}Container ID ${CONTAINER_ID} already exists.${NC}"
        echo -e "${BLUE}Current container details:${NC}"
        pct config ${CONTAINER_ID} | head -10
        echo
        
        if get_yes_no "Do you want to automatically remove the existing container and continue?" "y"; then
            echo -e "${YELLOW}Removing existing container ${CONTAINER_ID}...${NC}"
            
            # Stop container if running
            if pct status ${CONTAINER_ID} | grep -q "running"; then
                echo -e "${BLUE}Stopping container...${NC}"
                pct stop ${CONTAINER_ID} || true
                sleep 3
            fi
            
            # Destroy container
            echo -e "${BLUE}Destroying container...${NC}"
            pct destroy ${CONTAINER_ID} || true
            sleep 2
            
            # Verify removal
            if pct list | grep -q "^${CONTAINER_ID} "; then
                echo -e "${RED}Failed to remove existing container${NC}"
                exit 1
            else
                echo -e "${GREEN}Existing container successfully removed${NC}"
            fi
        else
            echo -e "${YELLOW}Installation cancelled. Please choose a different container ID or manually remove the existing container.${NC}"
            exit 0
        fi
    fi
}

# Main configuration wizard
run_wizard() {
    show_header
    
    echo -e "${GREEN}Welcome to the Network Monitor Installation Wizard!${NC}"
    echo -e "${BLUE}This wizard will guide you through the installation process.${NC}"
    echo -e "${YELLOW}Features automatic rollback on failure and existing container cleanup.${NC}"
    echo
    
    # Container ID
    while true; do
        get_input "Container ID (100-999999999):" "$DEFAULT_CONTAINER_ID" "CONTAINER_ID"
        if validate_container_id "$CONTAINER_ID"; then
            break
        else
            echo -e "${RED}Invalid container ID. Please enter a number between 100 and 999999999${NC}"
        fi
    done
    
    # Check for existing container and handle cleanup
    check_existing_container
    
    # Container Name
    get_input "Container hostname:" "$DEFAULT_CONTAINER_NAME" "CONTAINER_NAME"
    
    # Storage
    echo
    list_storages
    while true; do
        get_input "Storage location for container:" "$DEFAULT_STORAGE" "STORAGE"
        if validate_storage "$STORAGE"; then
            break
        else
            echo -e "${RED}Storage '$STORAGE' not found or not available${NC}"
            echo -e "${YELLOW}Please choose from the available storage locations above${NC}"
        fi
    done
    
    # Template
    echo
    list_templates
    echo -e "${YELLOW}Select a template (you can copy-paste from the list above):${NC}"
    get_input "Container template:" "ubuntu-22.04-standard_22.04-1_amd64.tar.zst" "TEMPLATE_INPUT"
    
    # Resources
    echo
    echo -e "${CYAN}Container Resources Configuration:${NC}"
    get_input "Memory (MB):" "$DEFAULT_MEMORY" "MEMORY"
    get_input "CPU cores:" "$DEFAULT_CORES" "CORES"
    
    # Disk size with validation
    while true; do
        get_input "Disk size in GB (minimum 8GB):" "$DEFAULT_DISK_SIZE" "DISK_SIZE"
        if validate_disk_size "$DISK_SIZE"; then
            break
        else
            echo -e "${RED}Invalid disk size. Please enter a number between 8 and 1000 (GB)${NC}"
        fi
    done
    
    # Network
    echo
    list_bridges
    get_input "Network bridge:" "$DEFAULT_NET_BRIDGE" "NET_BRIDGE"
    
    # Security
    echo
    echo -e "${CYAN}Security Configuration:${NC}"
    get_input "Root password for container:" "$DEFAULT_PASSWORD" "PASSWORD"
    
    # Monitoring Configuration
    echo
    echo -e "${CYAN}Monitoring Configuration:${NC}"
    get_input "Primary monitoring target (IP/hostname):" "8.8.8.8" "TARGET1"
    get_input "Primary target name:" "Google DNS" "TARGET1_NAME"
    get_input "Secondary monitoring target (IP/hostname):" "1.1.1.1" "TARGET2"
    get_input "Secondary target name:" "Cloudflare DNS" "TARGET2_NAME"
    get_input "Collection interval (seconds):" "30" "COLLECTION_INTERVAL"
    get_input "Data retention (days):" "30" "RETENTION_DAYS"
    
    # Summary
    show_header
    echo -e "${GREEN}Installation Summary:${NC}"
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} Container Configuration:                                                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   • ID: ${CONTAINER_ID}                                                           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   • Name: ${CONTAINER_NAME}                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   • Storage: ${STORAGE}                                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   • Template: ${TEMPLATE_INPUT}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   • Resources: ${MEMORY}MB RAM, ${CORES} CPU cores, ${DISK_SIZE}GB disk                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   • Network: ${NET_BRIDGE}                                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} Monitoring Configuration:                                                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   • Primary: ${TARGET1_NAME} (${TARGET1})                                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   • Secondary: ${TARGET2_NAME} (${TARGET2})                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   • Interval: ${COLLECTION_INTERVAL}s, Retention: ${RETENTION_DAYS} days                           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} Safety Features:                                                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   • Automatic rollback on failure                                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   • Existing container cleanup                                           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   • Build error recovery                                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    if ! get_yes_no "Proceed with installation?" "y"; then
        echo -e "${YELLOW}Installation cancelled by user${NC}"
        exit 0
    fi
}

# Installation function with comprehensive error handling
perform_installation() {
    echo
    echo -e "${GREEN}Starting installation with automatic rollback protection...${NC}"
    
    # Ensure template is available using pveam
    if ! ensure_template_available "$TEMPLATE_INPUT"; then
        echo -e "${RED}Failed to ensure template availability${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Creating LXC container...${NC}"
    echo -e "${BLUE}Using storage: ${STORAGE}${NC}"
    echo -e "${BLUE}Using template: ${FINAL_TEMPLATE}${NC}"
    echo -e "${BLUE}Container specs: ${MEMORY}MB RAM, ${CORES} cores, ${DISK_SIZE}GB disk${NC}"
    
    # Verify template file exists before creating container
    if [ ! -f "/var/lib/vz/template/cache/${FINAL_TEMPLATE}" ]; then
        echo -e "${RED}Error: Template file not found: /var/lib/vz/template/cache/${FINAL_TEMPLATE}${NC}"
        echo -e "${YELLOW}Available templates:${NC}"
        ls -la /var/lib/vz/template/cache/ | grep -E "(ubuntu|debian)" || echo "No templates found"
        exit 1
    fi
    
    # Create the container using the verified template
    if ! pct create ${CONTAINER_ID} "local:vztmpl/${FINAL_TEMPLATE}" \
        --hostname ${CONTAINER_NAME} \
        --memory ${MEMORY} \
        --cores ${CORES} \
        --rootfs ${STORAGE}:${DISK_SIZE} \
        --password ${PASSWORD} \
        --net0 name=eth0,bridge=${NET_BRIDGE},firewall=1,ip=dhcp \
        --features nesting=1 \
        --unprivileged 1 \
        --onboot 1 \
        --startup order=3; then
        
        echo -e "${YELLOW}Failed to create container with local:vztmpl/ prefix, trying alternative...${NC}"
        
        # Try without the local:vztmpl/ prefix
        if ! pct create ${CONTAINER_ID} "${FINAL_TEMPLATE}" \
            --hostname ${CONTAINER_NAME} \
            --memory ${MEMORY} \
            --cores ${CORES} \
            --rootfs ${STORAGE}:${DISK_SIZE} \
            --password ${PASSWORD} \
            --net0 name=eth0,bridge=${NET_BRIDGE},firewall=1,ip=dhcp \
            --features nesting=1 \
            --unprivileged 1 \
            --onboot 1 \
            --startup order=3; then
            
            echo -e "${RED}Failed to create container with both path formats${NC}"
            exit 1
        fi
    fi
    
    CONTAINER_CREATED=true
    echo -e "${GREEN}Container created successfully!${NC}"
    
    echo -e "${GREEN}Starting container...${NC}"
    pct start ${CONTAINER_ID}
    CONTAINER_STARTED=true
    
    # Wait for container to be ready
    echo -e "${YELLOW}Waiting for container to be ready...${NC}"
    sleep 15
    
    # Check if container is running
    if ! pct status ${CONTAINER_ID} | grep -q "running"; then
        echo -e "${RED}Error: Container failed to start${NC}"
        echo -e "${YELLOW}Container status:${NC}"
        pct status ${CONTAINER_ID}
        exit 1
    fi
    
    echo -e "${GREEN}Installing Docker, Git and dependencies...${NC}"
    
    # Install Docker and dependencies with better error handling
    if ! pct exec ${CONTAINER_ID} -- bash -c "
        export DEBIAN_FRONTEND=noninteractive
        apt update
        apt install -y apt-transport-https ca-certificates curl gnupg lsb-release git
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        systemctl enable docker
        systemctl start docker
    "; then
        echo -e "${RED}Failed to install Docker and dependencies${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Cloning network monitor from GitHub...${NC}"
    
    # Clone the repository and configure
    if ! pct exec ${CONTAINER_ID} -- bash -c "
        cd /opt
        git clone ${GITHUB_REPO} network-monitor
        cd network-monitor
        
        # Create custom .env file with user settings
        cat > .env << EOF
# Network Monitoring Configuration - Generated by Installation Wizard

# Monitoring Targets
TARGET1=${TARGET1}
TARGET1_NAME=${TARGET1_NAME}
TARGET2=${TARGET2}
TARGET2_NAME=${TARGET2_NAME}

# Data Retention (days)
RETENTION_DAYS=${RETENTION_DAYS}

# Collection Settings
COLLECTION_INTERVAL=${COLLECTION_INTERVAL}

# InfluxDB Configuration
INFLUXDB_USERNAME=admin
INFLUXDB_PASSWORD=networkmonitor123
INFLUXDB_ORG=NetworkMonitoring
INFLUXDB_BUCKET=network_metrics
INFLUXDB_TOKEN=network-monitor-token-change-me

# Grafana Configuration
GRAFANA_PASSWORD=networkmonitor123
EOF
        
        # Set proper permissions
        chmod +x entrypoint.sh
        chmod +x deploy-proxmox.sh 2>/dev/null || true
        chown -R root:root .
    "; then
        echo -e "${RED}Failed to clone repository or configure application${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Building and starting the monitoring stack...${NC}"
    echo -e "${BLUE}This may take a few minutes for the initial Docker image builds...${NC}"
    
    # Build and start the stack with better error handling
    if ! pct exec ${CONTAINER_ID} -- bash -c "
        cd /opt/network-monitor
        docker compose up -d --build
    "; then
        echo -e "${RED}Failed to build and start the monitoring stack${NC}"
        echo -e "${YELLOW}Checking Docker logs for more information...${NC}"
        pct exec ${CONTAINER_ID} -- docker compose -f /opt/network-monitor/docker-compose.yml logs || true
        exit 1
    fi
    
    # Wait for services to start
    echo -e "${YELLOW}Waiting for services to initialize...${NC}"
    sleep 60
    
    # Verify services are running
    echo -e "${GREEN}Verifying service status...${NC}"
    if ! pct exec ${CONTAINER_ID} -- docker compose -f /opt/network-monitor/docker-compose.yml ps | grep -q "Up"; then
        echo -e "${RED}Services failed to start properly${NC}"
        echo -e "${YELLOW}Service status:${NC}"
        pct exec ${CONTAINER_ID} -- docker compose -f /opt/network-monitor/docker-compose.yml ps || true
        echo -e "${YELLOW}Service logs:${NC}"
        pct exec ${CONTAINER_ID} -- docker compose -f /opt/network-monitor/docker-compose.yml logs --tail=50 || true
        exit 1
    fi
    
    # Get container IP
    CONTAINER_IP=$(pct exec ${CONTAINER_ID} -- ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "Unable to determine IP")
    
    echo -e "${GREEN}All services started successfully!${NC}"
}

# Success message
show_success() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                          ${BOLD}${GREEN}INSTALLATION SUCCESSFUL!${NC}                         ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                        ${BLUE}No rollback required - All good!${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Container Details:${NC}"
    echo -e "  • Container ID: ${BOLD}${CONTAINER_ID}${NC}"
    echo -e "  • Container Name: ${BOLD}${CONTAINER_NAME}${NC}"
    echo -e "  • IP Address: ${BOLD}${CONTAINER_IP}${NC}"
    echo -e "  • Root Password: ${BOLD}${PASSWORD}${NC}"
    echo -e "  • Template Used: ${BOLD}${FINAL_TEMPLATE}${NC}"
    echo
    echo -e "${CYAN}Access URLs:${NC}"
    echo -e "  • ${BOLD}Grafana Dashboard: ${GREEN}http://${CONTAINER_IP}:3000${NC}"
    echo -e "    Username: ${BOLD}admin${NC}"
    echo -e "    Password: ${BOLD}networkmonitor123${NC}"
    echo
    echo -e "  • ${BOLD}InfluxDB: ${GREEN}http://${CONTAINER_IP}:8086${NC}"
    echo -e "    Username: ${BOLD}admin${NC}"
    echo -e "    Password: ${BOLD}networkmonitor123${NC}"
    echo
    echo -e "${CYAN}Monitoring Configuration:${NC}"
    echo -e "  • Primary Target: ${BOLD}${TARGET1_NAME} (${TARGET1})${NC}"
    echo -e "  • Secondary Target: ${BOLD}${TARGET2_NAME} (${TARGET2})${NC}"
    echo -e "  • Collection Interval: ${BOLD}${COLLECTION_INTERVAL} seconds${NC}"
    echo -e "  • Data Retention: ${BOLD}${RETENTION_DAYS} days${NC}"
    echo
    echo -e "${YELLOW}Configuration Management:${NC}"
    echo -e "  1. ${BOLD}pct enter ${CONTAINER_ID}${NC}"
    echo -e "  2. ${BOLD}cd /opt/network-monitor${NC}"
    echo -e "  3. ${BOLD}nano .env${NC}"
    echo -e "  4. ${BOLD}docker compose restart${NC}"
    echo
    echo -e "${GREEN}Professional ISP Reporting Features:${NC}"
    echo -e "  ✓ Real-time latency monitoring"
    echo -e "  ✓ Packet loss tracking"
    echo -e "  ✓ Speed test measurements"
    echo -e "  ✓ Historical data retention"
    echo -e "  ✓ Professional Grafana dashboards"
    echo -e "  ✓ Export capabilities for ISP reports"
    echo -e "  ✓ Automatic rollback protection"
    echo
    echo -e "${BLUE}The network monitor is now running and collecting data!${NC}"
    echo -e "${BLUE}Dashboard will be available in ~2 minutes after initial data collection.${NC}"
    echo
    echo -e "${CYAN}GitHub Repository: ${GITHUB_REPO}${NC}"
}

# Main execution
main() {
    # Check prerequisites
    check_proxmox
    
    # Run configuration wizard
    run_wizard
    
    # Perform installation
    perform_installation
    
    # If we get here, installation was successful
    INSTALLATION_FAILED=false
    
    # Show success message
    show_success
}

# Run main function
main "$@"