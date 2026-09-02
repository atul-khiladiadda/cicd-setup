#!/bin/bash

###############################################################################
# OpenVPN Client Configuration Generator
# 
# Creates a new client configuration for OpenVPN
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
OPENVPN_DIR="/etc/openvpn"
EASYRSA_DIR="$OPENVPN_DIR/easy-rsa"
SERVER_DIR="$OPENVPN_DIR/server"
CLIENT_DIR="$OPENVPN_DIR/clients"
SERVER_PUBLIC_IP=$(curl -s ifconfig.me)
VPN_PORT=1194
VPN_PROTOCOL="udp"

print_header "Creating OpenVPN Client: $CLIENT_NAME"

# Check if client already exists
if [ -f "$CLIENT_DIR/$CLIENT_NAME.ovpn" ]; then
    print_error "Client '$CLIENT_NAME' already exists!"
    exit 1
fi

# Change to Easy-RSA directory
cd $EASYRSA_DIR

# Generate client certificate and key
print_info "Generating client certificate and key..."
./easyrsa --batch build-client-full $CLIENT_NAME nopass
print_success "Client certificate generated"

# Create client configuration directory
mkdir -p $CLIENT_DIR/$CLIENT_NAME

# Extract client certificates
print_info "Extracting certificates..."
cp pki/ca.crt $CLIENT_DIR/$CLIENT_NAME/
cp pki/issued/$CLIENT_NAME.crt $CLIENT_DIR/$CLIENT_NAME/
cp pki/private/$CLIENT_NAME.key $CLIENT_DIR/$CLIENT_NAME/
cp $SERVER_DIR/ta.key $CLIENT_DIR/$CLIENT_NAME/

# Create client configuration file
print_info "Creating client configuration file..."

cat > $CLIENT_DIR/$CLIENT_NAME.ovpn << EOF
# OpenVPN Client Configuration
client
dev tun
proto $VPN_PROTOCOL

# Server address and port
remote $SERVER_PUBLIC_IP $VPN_PORT

# Keep trying to connect indefinitely
resolv-retry infinite

# Don't bind to local address and port
nobind

# Persist certain state across restarts
persist-key
persist-tun

# Wireless networks often produce a lot of duplicate packets
# This can help minimize that
;mute-replay-warnings

# SSL/TLS parameters
remote-cert-tls server
cipher AES-256-GCM
auth SHA256

# Compression - intentionally absent (VORACLE attack).
# The server sets "allow-compression no", so adding comp-lzo or compress here
# would make this client fail to connect.

# Set log file verbosity
verb 3

# Silence repeating messages
;mute 20

# Certificate Authority
<ca>
$(cat $CLIENT_DIR/$CLIENT_NAME/ca.crt)
</ca>

# Client Certificate
<cert>
$(cat $CLIENT_DIR/$CLIENT_NAME/$CLIENT_NAME.crt)
</cert>

# Client Private Key
<key>
$(cat $CLIENT_DIR/$CLIENT_NAME/$CLIENT_NAME.key)
</key>

# TLS Authentication Key
<tls-auth>
$(cat $CLIENT_DIR/$CLIENT_NAME/ta.key)
</tls-auth>
key-direction 1
EOF

chmod 600 $CLIENT_DIR/$CLIENT_NAME.ovpn
print_success "Client configuration created: $CLIENT_DIR/$CLIENT_NAME.ovpn"

# Clean up individual certificate files
rm -rf $CLIENT_DIR/$CLIENT_NAME/

print_header "Client Configuration Complete"

echo ""
echo "Client Name: $CLIENT_NAME"
echo "Configuration file: $CLIENT_DIR/$CLIENT_NAME.ovpn"
echo ""

print_header "How to Connect"

echo "Method 1 - Download config file to your device:"
echo ""
echo "From your local machine, run:"
echo "  scp -i your-key.pem ubuntu@$SERVER_PUBLIC_IP:$CLIENT_DIR/$CLIENT_NAME.ovpn ."
echo ""

echo "Method 2 - Display config (copy/paste):"
echo "  cat $CLIENT_DIR/$CLIENT_NAME.ovpn"
echo ""

echo "Then import the .ovpn file into your OpenVPN client:"
echo ""
echo "• Windows: OpenVPN GUI - https://openvpn.net/community-downloads/"
echo "• macOS: Tunnelblick - https://tunnelblick.net/"
echo "• Linux: sudo apt install openvpn"
echo "          sudo openvpn --config $CLIENT_NAME.ovpn"
echo "• iOS: OpenVPN Connect (App Store)"
echo "• Android: OpenVPN for Android (Play Store)"
echo ""

print_success "Client '$CLIENT_NAME' created successfully!"
