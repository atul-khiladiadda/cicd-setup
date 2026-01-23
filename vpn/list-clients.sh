#!/bin/bash

###############################################################################
# List WireGuard VPN Clients
# 
# Shows all configured clients and their connection status
#
# Usage: sudo ./list-clients.sh
###############################################################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

print_header "WireGuard VPN - Client List"

WG_DIR="/etc/wireguard"
CLIENT_DIR="$WG_DIR/clients"

# Check if clients directory exists
if [ ! -d "$CLIENT_DIR" ]; then
    echo "No clients directory found"
    exit 0
fi

# List all client configs
echo "Configured Clients:"
echo "==================="
echo ""

CLIENT_COUNT=0
for conf in $CLIENT_DIR/*.conf; do
    if [ -f "$conf" ]; then
        CLIENT_NAME=$(basename "$conf" .conf)
        CLIENT_IP=$(grep "Address" "$conf" | awk '{print $3}')
        echo "• $CLIENT_NAME"
        echo "  VPN IP: $CLIENT_IP"
        echo "  Config: $conf"
        echo ""
        CLIENT_COUNT=$((CLIENT_COUNT + 1))
    fi
done

if [ $CLIENT_COUNT -eq 0 ]; then
    echo "No clients configured yet"
    echo ""
    echo "Add a client with: sudo ./add-client.sh <client-name>"
else
    echo "Total clients: $CLIENT_COUNT"
fi

echo ""
print_header "Active Connections"

wg show

echo ""
