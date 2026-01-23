#!/bin/bash

###############################################################################
# WireGuard Client Configuration Generator
# 
# Creates a new client configuration for WireGuard VPN
#
# Usage: sudo ./add-client.sh <client-name>
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
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

# Check if client name provided
if [ -z "$1" ]; then
    print_error "Usage: sudo ./add-client.sh <client-name>"
    exit 1
fi

CLIENT_NAME="$1"
WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
WG_PORT=51820
SERVER_PUBLIC_IP=$(curl -s ifconfig.me)
SERVER_PUBLIC_KEY=$(cat $WG_DIR/server_public.key)
CLIENT_DIR="$WG_DIR/clients"

# Get next available IP
LAST_IP=$(grep -oP '(?<=AllowedIPs = 10\.8\.0\.)\d+' $WG_DIR/$WG_INTERFACE.conf | sort -n | tail -1)
if [ -z "$LAST_IP" ]; then
    CLIENT_IP="10.8.0.2"
else
    NEXT_IP=$((LAST_IP + 1))
    CLIENT_IP="10.8.0.$NEXT_IP"
fi

print_header "Creating WireGuard Client: $CLIENT_NAME"

# Check if client already exists
if [ -f "$CLIENT_DIR/$CLIENT_NAME.conf" ]; then
    print_error "Client '$CLIENT_NAME' already exists!"
    exit 1
fi

# Generate client keys
print_info "Generating client keys..."
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)
CLIENT_PRESHARED_KEY=$(wg genpsk)

print_success "Keys generated"

# Create client configuration file
print_info "Creating client configuration..."

cat > $CLIENT_DIR/$CLIENT_NAME.conf << EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
Endpoint = $SERVER_PUBLIC_IP:$WG_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

chmod 600 $CLIENT_DIR/$CLIENT_NAME.conf
print_success "Client configuration created: $CLIENT_DIR/$CLIENT_NAME.conf"

# Add client to server configuration
print_info "Adding client to server configuration..."

cat >> $WG_DIR/$WG_INTERFACE.conf << EOF

# Client: $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = $CLIENT_IP/32
EOF

print_success "Client added to server configuration"

# Restart WireGuard
print_info "Restarting WireGuard..."
systemctl restart wg-quick@$WG_INTERFACE
print_success "WireGuard restarted"

# Generate QR code
print_header "Client Configuration"

echo ""
echo "Client Name: $CLIENT_NAME"
echo "Client VPN IP: $CLIENT_IP"
echo "Configuration file: $CLIENT_DIR/$CLIENT_NAME.conf"
echo ""

print_info "QR Code (scan with WireGuard mobile app):"
echo ""
qrencode -t ansiutf8 < $CLIENT_DIR/$CLIENT_NAME.conf
echo ""

print_header "How to Connect"

echo "Method 1 - Mobile App (iOS/Android):"
echo "1. Install WireGuard app from App Store/Play Store"
echo "2. Scan the QR code above"
echo "3. Activate the VPN"
echo ""
echo "Method 2 - Desktop/Laptop:"
echo "1. Copy the config file to your device:"
echo "   scp -i your-key.pem ubuntu@$SERVER_PUBLIC_IP:$CLIENT_DIR/$CLIENT_NAME.conf ."
echo "2. Import into WireGuard app"
echo "3. Activate the VPN"
echo ""
echo "Method 3 - Linux Client:"
echo "1. Copy config to /etc/wireguard/ on client device"
echo "2. Run: sudo wg-quick up $CLIENT_NAME"
echo ""

print_success "Client '$CLIENT_NAME' created successfully!"
