#!/bin/bash

###############################################################################
# Remove OpenVPN Client
# 
# Revokes a client certificate and removes configuration
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
    print_error "Usage: sudo ./remove-client.sh <client-name>"
    exit 1
fi

CLIENT_NAME="$1"
OPENVPN_DIR="/etc/openvpn"
EASYRSA_DIR="$OPENVPN_DIR/easy-rsa"
CLIENT_DIR="$OPENVPN_DIR/clients"
CLIENT_CONF="$CLIENT_DIR/$CLIENT_NAME.ovpn"

print_header "Removing OpenVPN Client: $CLIENT_NAME"

# Check if client exists
if [ ! -f "$CLIENT_CONF" ]; then
    print_error "Client '$CLIENT_NAME' not found!"
    exit 1
fi

# Change to Easy-RSA directory
cd $EASYRSA_DIR

# Revoke client certificate
print_info "Revoking client certificate..."
./easyrsa --batch revoke $CLIENT_NAME
print_success "Certificate revoked"

# Generate new CRL
print_info "Generating Certificate Revocation List (CRL)..."
./easyrsa gen-crl
print_success "CRL generated"

# Copy CRL to server directory
cp $EASYRSA_DIR/pki/crl.pem $OPENVPN_DIR/server/
chmod 644 $OPENVPN_DIR/server/crl.pem

# Update server config to use CRL
if ! grep -q "crl-verify" $OPENVPN_DIR/server/server.conf; then
    echo "crl-verify $OPENVPN_DIR/server/crl.pem" >> $OPENVPN_DIR/server/server.conf
    print_info "Added CRL verification to server config"
fi

# Remove client config file
print_info "Removing client configuration file..."
rm -f "$CLIENT_CONF"

# Restart OpenVPN to apply changes
print_info "Restarting OpenVPN server..."
systemctl restart openvpn-server@server

sleep 2

if systemctl is-active --quiet openvpn-server@server; then
    print_success "OpenVPN server restarted successfully"
else
    print_error "Failed to restart OpenVPN server"
    exit 1
fi

print_success "Client '$CLIENT_NAME' removed and certificate revoked!"
echo ""
echo "The client can no longer connect to the VPN."
