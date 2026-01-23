#!/bin/bash

###############################################################################
# OpenVPN Uninstall Script for Ubuntu
# 
# This script safely removes OpenVPN from your system:
# - Stops and disables OpenVPN service
# - Removes OpenVPN and Easy-RSA packages
# - Cleans up configuration files and certificates
# - Removes firewall rules
# - Optionally backs up configuration
#
# Usage: sudo ./uninstall-openvpn.sh
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

print_header "OpenVPN Uninstall"

# Check if OpenVPN is installed
if ! command -v openvpn &> /dev/null; then
    print_warning "OpenVPN is not installed on this system"
    exit 0
fi

print_warning "This will completely remove OpenVPN from your system"
echo "The following will be removed:"
echo "  - OpenVPN service"
echo "  - OpenVPN and Easy-RSA packages"
echo "  - All configuration files and certificates"
echo "  - Certificate Authority (CA)"
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
read -p "Do you want to backup configuration and CA before removal? (yes/no): " BACKUP

if [ "$BACKUP" = "yes" ]; then
    print_header "Creating Backup"
    
    BACKUP_FILE="openvpn-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$BACKUP_FILE" /etc/openvpn/ 2>/dev/null || true
    
    if [ -f "$BACKUP_FILE" ]; then
        print_success "Backup created: $BACKUP_FILE"
        echo "Location: $(pwd)/$BACKUP_FILE"
        echo ""
        print_warning "IMPORTANT: This backup contains your Certificate Authority!"
        print_warning "Store it securely if you may need to restore OpenVPN later."
    else
        print_warning "Backup creation failed or no configuration to backup"
    fi
fi

# Stop OpenVPN service
print_header "Stopping OpenVPN Service"

if systemctl is-active --quiet openvpn-server@server; then
    print_info "Stopping OpenVPN service..."
    systemctl stop openvpn-server@server
    print_success "OpenVPN service stopped"
else
    print_info "OpenVPN service is not running"
fi

# Disable OpenVPN service
if systemctl is-enabled --quiet openvpn-server@server 2>/dev/null; then
    print_info "Disabling OpenVPN service..."
    systemctl disable openvpn-server@server
    print_success "OpenVPN service disabled"
fi

# Remove OpenVPN interface
print_info "Removing OpenVPN interface..."
ip link delete tun0 2>/dev/null || print_info "Interface already removed"

# Remove UFW rules
print_header "Removing Firewall Rules"

if command -v ufw &> /dev/null; then
    print_info "Removing UFW rules..."
    
    # Remove OpenVPN port rule
    ufw delete allow 1194/udp 2>/dev/null && print_success "Removed UFW rule for port 1194/udp" || print_info "No UFW rule to remove"
    ufw delete allow 1194/tcp 2>/dev/null && print_success "Removed UFW rule for port 1194/tcp" || print_info "No TCP rule to remove"
else
    print_info "UFW not installed, skipping"
fi

# Get network interface
SERVER_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

# Remove iptables rules
print_info "Removing iptables rules..."

iptables -D FORWARD -i tun0 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i tun0 -o $SERVER_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i $SERVER_INTERFACE -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o $SERVER_INTERFACE -j MASQUERADE 2>/dev/null || true

# Save iptables rules
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
fi

print_success "Firewall rules removed"

# Remove OpenVPN packages
print_header "Removing OpenVPN Packages"

print_info "Uninstalling OpenVPN and Easy-RSA..."
apt-get remove -y openvpn easy-rsa 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

print_success "OpenVPN packages removed"

# Remove configuration files
print_header "Removing Configuration Files"

print_info "Removing OpenVPN configuration directory..."

if [ -d "/etc/openvpn" ]; then
    rm -rf /etc/openvpn
    print_success "Configuration files and CA removed"
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

if command -v openvpn &> /dev/null; then
    print_warning "OpenVPN command still available (may need system reboot)"
else
    print_success "OpenVPN has been completely removed"
fi

if [ -d "/etc/openvpn" ]; then
    print_warning "Configuration directory still exists"
else
    print_success "Configuration directory removed"
fi

# Summary
print_header "Uninstall Complete!"

echo ""
echo "OpenVPN has been removed from your system"
echo ""

if [ -f "$BACKUP_FILE" ]; then
    echo "Configuration backup saved to:"
    echo "  $(pwd)/$BACKUP_FILE"
    echo ""
    echo "⚠️  IMPORTANT: This backup contains your Certificate Authority"
    echo "   Store it securely if you may reinstall OpenVPN later"
    echo ""
    echo "To restore in the future:"
    echo "  sudo tar -xzf $BACKUP_FILE -C /"
    echo "  sudo systemctl enable openvpn-server@server"
    echo "  sudo systemctl start openvpn-server@server"
    echo ""
fi

print_info "If you want to reinstall OpenVPN, run:"
echo "  sudo ./setup-openvpn.sh"
echo ""

print_success "Uninstall completed successfully!"
