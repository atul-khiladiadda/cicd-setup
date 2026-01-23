#!/bin/bash

###############################################################################
# WireGuard VPN Setup Script for Ubuntu EC2
# 
# This script helps you:
# - Install WireGuard VPN server
# - Generate server and client configurations
# - Set up firewall rules and IP forwarding
# - Create client configuration files
#
# Usage: sudo ./setup-wireguard.sh
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

print_header "WireGuard VPN Setup for Ubuntu EC2"

# Get server information
print_info "Detecting server configuration..."
SERVER_PUBLIC_IP=$(curl -s ifconfig.me || wget -qO- ifconfig.me)
SERVER_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

echo "Server Public IP: $SERVER_PUBLIC_IP"
echo "Server Interface: $SERVER_INTERFACE"
echo ""

# Configuration
WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
WG_PORT=51820
WG_SUBNET="10.8.0.0/24"
SERVER_WG_IP="10.8.0.1"

# Install WireGuard
print_header "Installing WireGuard"

if command -v wg &> /dev/null; then
    print_success "WireGuard is already installed"
else
    print_info "Installing WireGuard..."
    apt-get update
    apt-get install -y wireguard wireguard-tools qrencode
    print_success "WireGuard installed successfully"
fi

# Enable IP forwarding
print_header "Configuring IP Forwarding"

if grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    print_success "IP forwarding already enabled"
else
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
    print_success "IP forwarding enabled"
fi

# Generate server keys
print_header "Generating Server Keys"

cd $WG_DIR

if [ -f "server_private.key" ]; then
    print_warning "Server keys already exist, skipping generation"
    SERVER_PRIVATE_KEY=$(cat server_private.key)
    SERVER_PUBLIC_KEY=$(cat server_public.key)
else
    wg genkey | tee server_private.key | wg pubkey > server_public.key
    chmod 600 server_private.key
    SERVER_PRIVATE_KEY=$(cat server_private.key)
    SERVER_PUBLIC_KEY=$(cat server_public.key)
    print_success "Server keys generated"
fi

# Create server configuration
print_header "Creating Server Configuration"

cat > $WG_DIR/$WG_INTERFACE.conf << EOF
[Interface]
Address = $SERVER_WG_IP/24
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY

# IP forwarding
PostUp = iptables -A FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -t nat -A POSTROUTING -o $SERVER_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -t nat -D POSTROUTING -o $SERVER_INTERFACE -j MASQUERADE

# Client configurations will be added below
EOF

chmod 600 $WG_DIR/$WG_INTERFACE.conf
print_success "Server configuration created: $WG_DIR/$WG_INTERFACE.conf"

# Configure firewall
print_header "Configuring Firewall"

if command -v ufw &> /dev/null; then
    print_info "Configuring UFW firewall..."
    ufw allow $WG_PORT/udp comment 'WireGuard VPN'
    print_success "Firewall rule added for port $WG_PORT/udp"
else
    print_warning "UFW not found, please manually open port $WG_PORT/udp in your security group"
fi

# Start WireGuard
print_header "Starting WireGuard Service"

systemctl enable wg-quick@$WG_INTERFACE
systemctl start wg-quick@$WG_INTERFACE

if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
    print_success "WireGuard service started and enabled"
else
    print_error "Failed to start WireGuard service"
    exit 1
fi

# Create client directory
mkdir -p $WG_DIR/clients
chmod 700 $WG_DIR/clients

# Summary
print_header "WireGuard VPN Setup Complete!"

echo ""
echo "=============================================="
echo "Server Configuration Summary"
echo "=============================================="
echo ""
echo "Server Public IP: $SERVER_PUBLIC_IP"
echo "Server Public Key: $SERVER_PUBLIC_KEY"
echo "VPN Port: $WG_PORT"
echo "VPN Subnet: $WG_SUBNET"
echo "Server VPN IP: $SERVER_WG_IP"
echo ""
echo "Configuration file: $WG_DIR/$WG_INTERFACE.conf"
echo "Client configs directory: $WG_DIR/clients/"
echo ""

print_header "Next Steps"

echo "1. Add a VPN client:"
echo "   sudo ./add-client.sh client-name"
echo ""
echo "2. Check VPN status:"
echo "   sudo wg show"
echo ""
echo "3. View active connections:"
echo "   sudo wg show $WG_INTERFACE"
echo ""
echo "4. Make sure to open UDP port $WG_PORT in your EC2 security group:"
echo "   Type: Custom UDP"
echo "   Port: $WG_PORT"
echo "   Source: Your IP or 0.0.0.0/0"
echo ""

print_success "WireGuard VPN server is ready!"
