#!/bin/bash

###############################################################################
# OpenVPN Server Setup Script for Ubuntu EC2
# 
# This script helps you:
# - Install OpenVPN and Easy-RSA
# - Set up Certificate Authority (CA)
# - Generate server certificates and keys
# - Configure OpenVPN server
# - Set up firewall rules and IP forwarding
#
# Usage: sudo ./setup-openvpn.sh
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

print_header "OpenVPN Server Setup for Ubuntu EC2"

# Get server information
print_info "Detecting server configuration..."
SERVER_PUBLIC_IP=$(curl -s ifconfig.me || wget -qO- ifconfig.me)
SERVER_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

echo "Server Public IP: $SERVER_PUBLIC_IP"
echo "Server Interface: $SERVER_INTERFACE"
echo ""

# Configuration
OPENVPN_DIR="/etc/openvpn"
EASYRSA_DIR="/etc/openvpn/easy-rsa"
SERVER_DIR="$OPENVPN_DIR/server"
CLIENT_DIR="$OPENVPN_DIR/clients"
VPN_PORT=1194
VPN_PROTOCOL="udp"
VPN_SUBNET="10.8.0.0"
VPN_NETMASK="255.255.255.0"

# Install OpenVPN and Easy-RSA
print_header "Installing OpenVPN and Easy-RSA"

if command -v openvpn &> /dev/null; then
    print_success "OpenVPN is already installed"
else
    print_info "Installing OpenVPN..."
    apt-get update
    apt-get install -y openvpn easy-rsa
    print_success "OpenVPN installed successfully"
fi

# Set up Easy-RSA
print_header "Setting up Easy-RSA (Certificate Authority)"

mkdir -p $SERVER_DIR $CLIENT_DIR
make-cadir $EASYRSA_DIR 2>/dev/null || print_warning "Easy-RSA directory already exists"
cd $EASYRSA_DIR

# Configure Easy-RSA vars
cat > vars << EOF
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "California"
set_var EASYRSA_REQ_CITY       "San Francisco"
set_var EASYRSA_REQ_ORG        "MyOrganization"
set_var EASYRSA_REQ_EMAIL      "admin@example.com"
set_var EASYRSA_REQ_OU         "IT"
set_var EASYRSA_ALGO           "ec"
set_var EASYRSA_DIGEST         "sha512"
EOF

print_success "Easy-RSA configured"

# Initialize PKI
print_header "Initializing Public Key Infrastructure (PKI)"

if [ -d "pki" ]; then
    print_warning "PKI already exists, skipping initialization"
else
    ./easyrsa init-pki
    print_success "PKI initialized"
fi

# Build CA
print_info "Building Certificate Authority..."
if [ -f "pki/ca.crt" ]; then
    print_warning "CA already exists, skipping"
else
    ./easyrsa --batch build-ca nopass
    print_success "Certificate Authority created"
fi

# Generate server certificate and key
print_info "Generating server certificate and key..."
if [ -f "pki/issued/server.crt" ]; then
    print_warning "Server certificate already exists, skipping"
else
    ./easyrsa --batch build-server-full server nopass
    print_success "Server certificate generated"
fi

# Generate Diffie-Hellman parameters
print_info "Generating Diffie-Hellman parameters (this may take a while)..."
if [ -f "pki/dh.pem" ]; then
    print_warning "DH parameters already exist, skipping"
else
    ./easyrsa gen-dh
    print_success "Diffie-Hellman parameters generated"
fi

# Generate TLS auth key
print_info "Generating TLS authentication key..."
if [ -f "$SERVER_DIR/ta.key" ]; then
    print_warning "TLS auth key already exists, skipping"
else
    openvpn --genkey secret $SERVER_DIR/ta.key
    print_success "TLS authentication key generated"
fi

# Copy server certificates and keys
print_info "Copying certificates and keys to server directory..."
cp pki/ca.crt $SERVER_DIR/
cp pki/issued/server.crt $SERVER_DIR/
cp pki/private/server.key $SERVER_DIR/
cp pki/dh.pem $SERVER_DIR/
chmod 600 $SERVER_DIR/server.key
print_success "Certificates copied"

# Enable IP forwarding
print_header "Configuring IP Forwarding"

if grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    print_success "IP forwarding already enabled"
else
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
    print_success "IP forwarding enabled"
fi

# Create OpenVPN server configuration
print_header "Creating OpenVPN Server Configuration"

cat > $SERVER_DIR/server.conf << EOF
# OpenVPN Server Configuration
port $VPN_PORT
proto $VPN_PROTOCOL
dev tun

# SSL/TLS root certificate (ca), certificate (cert), and private key (key)
ca $SERVER_DIR/ca.crt
cert $SERVER_DIR/server.crt
key $SERVER_DIR/server.key
dh $SERVER_DIR/dh.pem

# Network configuration
server $VPN_SUBNET $VPN_NETMASK
ifconfig-pool-persist $SERVER_DIR/ipp.txt

# Push routes to clients
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"

# Client configuration
client-to-client
keepalive 10 120

# Security
tls-auth $SERVER_DIR/ta.key 0
cipher AES-256-GCM
auth SHA256
dh $SERVER_DIR/dh.pem

# Performance
comp-lzo
persist-key
persist-tun

# Logging
status $SERVER_DIR/openvpn-status.log
log-append $SERVER_DIR/openvpn.log
verb 3

# User/Group
user nobody
group nogroup
EOF

print_success "Server configuration created: $SERVER_DIR/server.conf"

# Configure firewall with iptables
print_header "Configuring Firewall"

# Add iptables rules
iptables -A FORWARD -i tun0 -j ACCEPT
iptables -A FORWARD -i tun0 -o $SERVER_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $SERVER_INTERFACE -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -t nat -A POSTROUTING -s $VPN_SUBNET/24 -o $SERVER_INTERFACE -j MASQUERADE

# Save iptables rules
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
else
    apt-get install -y iptables-persistent
    netfilter-persistent save
fi

print_success "Firewall rules configured"

# Configure UFW if present
if command -v ufw &> /dev/null; then
    print_info "Configuring UFW firewall..."
    ufw allow $VPN_PORT/$VPN_PROTOCOL comment 'OpenVPN'
    print_success "UFW rule added for port $VPN_PORT/$VPN_PROTOCOL"
fi

# Enable and start OpenVPN
print_header "Starting OpenVPN Service"

systemctl enable openvpn-server@server
systemctl start openvpn-server@server

sleep 2

if systemctl is-active --quiet openvpn-server@server; then
    print_success "OpenVPN service started and enabled"
else
    print_error "Failed to start OpenVPN service"
    print_info "Checking logs..."
    journalctl -u openvpn-server@server --no-pager -n 20
    exit 1
fi

# Summary
print_header "OpenVPN Server Setup Complete!"

echo ""
echo "=============================================="
echo "Server Configuration Summary"
echo "=============================================="
echo ""
echo "Server Public IP: $SERVER_PUBLIC_IP"
echo "VPN Port: $VPN_PORT"
echo "VPN Protocol: $VPN_PROTOCOL"
echo "VPN Subnet: $VPN_SUBNET/24"
echo ""
echo "Configuration file: $SERVER_DIR/server.conf"
echo "Client configs directory: $CLIENT_DIR/"
echo "Certificate Authority: $EASYRSA_DIR/pki/ca.crt"
echo ""

print_header "Next Steps"

echo "1. Add VPN clients:"
echo "   sudo ./add-client.sh client-name"
echo ""
echo "2. Check VPN status:"
echo "   sudo systemctl status openvpn-server@server"
echo ""
echo "3. View active connections:"
echo "   cat $SERVER_DIR/openvpn-status.log"
echo ""
echo "4. Make sure to open port $VPN_PORT/$VPN_PROTOCOL in your EC2 security group:"
echo "   Type: Custom $VPN_PROTOCOL"
echo "   Port: $VPN_PORT"
echo "   Source: Your IP or 0.0.0.0/0"
echo ""

print_success "OpenVPN server is ready!"
