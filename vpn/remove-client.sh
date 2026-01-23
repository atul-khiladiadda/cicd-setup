#!/bin/bash

###############################################################################
# Remove WireGuard VPN Client
# 
# Removes a client from the VPN server
#
# Usage: sudo ./remove-client.sh <client-name>
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root or with sudo"
    exit 1
fi

# Check if client name provided
if [ -z "$1" ]; then
    print_error "Usage: sudo ./remove-client.sh <client-name>"
    exit 1
fi

CLIENT_NAME="$1"
WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
CLIENT_DIR="$WG_DIR/clients"
CLIENT_CONF="$CLIENT_DIR/$CLIENT_NAME.conf"

# Check if client exists
if [ ! -f "$CLIENT_CONF" ]; then
    print_error "Client '$CLIENT_NAME' not found!"
    exit 1
fi

print_info "Removing client: $CLIENT_NAME"

# Get client public key
CLIENT_PUBLIC_KEY=$(grep "PublicKey" "$CLIENT_CONF" | awk '{print $3}')

# Remove client from server config
print_info "Removing from server configuration..."
sed -i "/# Client: $CLIENT_NAME/,/^$/d" $WG_DIR/$WG_INTERFACE.conf

# Remove client config file
print_info "Removing client configuration file..."
rm -f "$CLIENT_CONF"

# Restart WireGuard
print_info "Restarting WireGuard..."
systemctl restart wg-quick@$WG_INTERFACE

print_success "Client '$CLIENT_NAME' removed successfully!"
