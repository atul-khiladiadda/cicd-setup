#!/bin/bash

###############################################################################
# WireGuard Uninstall Script for Ubuntu
# 
# This script safely removes WireGuard VPN from your system:
# - Stops and disables WireGuard service
# - Removes WireGuard packages
# - Cleans up configuration files
# - Removes firewall rules
# - Optionally backs up configuration
#
# Usage: sudo ./uninstall-wireguard.sh
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root or with sudo"
    exit 1
fi

print_header "WireGuard VPN Uninstall"

# Check if WireGuard is installed
if ! command -v wg &> /dev/null; then
    print_warning "WireGuard is not installed on this system"
    exit 0
fi

print_warning "This will completely remove WireGuard VPN from your system"
echo "The following will be removed:"
echo "  - WireGuard service"
echo "  - WireGuard packages"
echo "  - All configuration files"
echo "  - Client configurations"
echo "  - Firewall rules"
echo ""

# Ask for confirmation
read -p "Do you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_info "Uninstall cancelled"
    exit 0
fi

# Ask about backup
echo ""
read -p "Do you want to backup configuration before removal? (yes/no): " BACKUP

if [ "$BACKUP" = "yes" ]; then
    print_header "Creating Backup"
    
    BACKUP_FILE="wireguard-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$BACKUP_FILE" /etc/wireguard/ 2>/dev/null || true
    
    if [ -f "$BACKUP_FILE" ]; then
        print_success "Backup created: $BACKUP_FILE"
        echo "Location: $(pwd)/$BACKUP_FILE"
    else
        print_warning "Backup creation failed or no configuration to backup"
    fi
fi

# Stop WireGuard service
print_header "Stopping WireGuard Service"

WG_INTERFACE="wg0"

if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
    print_info "Stopping WireGuard service..."
    systemctl stop wg-quick@$WG_INTERFACE
    print_success "WireGuard service stopped"
else
    print_info "WireGuard service is not running"
fi

# Disable WireGuard service
if systemctl is-enabled --quiet wg-quick@$WG_INTERFACE 2>/dev/null; then
    print_info "Disabling WireGuard service..."
    systemctl disable wg-quick@$WG_INTERFACE
    print_success "WireGuard service disabled"
fi

# Remove WireGuard interface
print_info "Removing WireGuard interface..."
ip link delete $WG_INTERFACE 2>/dev/null || print_info "Interface already removed"

# Remove UFW rules
print_header "Removing Firewall Rules"

if command -v ufw &> /dev/null; then
    print_info "Removing UFW rules..."
    
    # Remove WireGuard port rule
    ufw delete allow 51820/udp 2>/dev/null && print_success "Removed UFW rule for port 51820/udp" || print_info "No UFW rule to remove"
else
    print_info "UFW not installed, skipping"
fi

# Get network interface
SERVER_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

# Remove iptables rules
print_info "Removing iptables rules..."

iptables -D FORWARD -i $WG_INTERFACE -j ACCEPT 2>/dev/null || true
iptables -t nat -D POSTROUTING -o $SERVER_INTERFACE -j MASQUERADE 2>/dev/null || true

print_success "Firewall rules removed"

# Remove WireGuard packages
print_header "Removing WireGuard Packages"

print_info "Uninstalling WireGuard..."
apt-get remove -y wireguard wireguard-tools 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

print_success "WireGuard packages removed"

# Remove configuration files
print_header "Removing Configuration Files"

print_info "Removing WireGuard configuration directory..."

if [ -d "/etc/wireguard" ]; then
    rm -rf /etc/wireguard
    print_success "Configuration files removed"
else
    print_info "No configuration directory found"
fi

# Disable IP forwarding (optional - only if not needed by other services)
print_header "IP Forwarding"

read -p "Do you want to disable IP forwarding? (yes/no): " DISABLE_FORWARD

if [ "$DISABLE_FORWARD" = "yes" ]; then
    if grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        sed -i '/net.ipv4.ip_forward=1/d' /etc/sysctl.conf
        sysctl -p
        print_success "IP forwarding disabled"
    else
        print_info "IP forwarding was not enabled in sysctl.conf"
    fi
else
    print_info "IP forwarding left enabled (other services may need it)"
fi

# Verify removal
print_header "Verification"

if command -v wg &> /dev/null; then
    print_warning "WireGuard command still available (may need system reboot)"
else
    print_success "WireGuard has been completely removed"
fi

if [ -d "/etc/wireguard" ]; then
    print_warning "Configuration directory still exists"
else
    print_success "Configuration directory removed"
fi

# Summary
print_header "Uninstall Complete!"

echo ""
echo "WireGuard VPN has been removed from your system"
echo ""

if [ -f "$BACKUP_FILE" ]; then
    echo "Configuration backup saved to:"
    echo "  $(pwd)/$BACKUP_FILE"
    echo ""
    echo "To restore in the future:"
    echo "  sudo tar -xzf $BACKUP_FILE -C /"
    echo ""
fi

print_info "If you want to reinstall WireGuard, run:"
echo "  sudo ./setup-wireguard.sh"
echo ""

print_success "Uninstall completed successfully!"
