#!/bin/bash

###############################################################################
# List OpenVPN Clients
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

print_header "OpenVPN - Client List"

OPENVPN_DIR="/etc/openvpn"
CLIENT_DIR="$OPENVPN_DIR/clients"
SERVER_DIR="$OPENVPN_DIR/server"
STATUS_LOG="$SERVER_DIR/openvpn-status.log"

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
for conf in $CLIENT_DIR/*.ovpn; do
    if [ -f "$conf" ]; then
        CLIENT_NAME=$(basename "$conf" .ovpn)
        echo "• $CLIENT_NAME"
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

if [ -f "$STATUS_LOG" ]; then
    echo "Connected Clients:"
    echo "==================="
    echo ""
    
    # Extract and display connected clients
    CONNECTED=$(grep -A 100 "CLIENT LIST" "$STATUS_LOG" | grep -B 100 "ROUTING TABLE" | grep -v "CLIENT LIST" | grep -v "ROUTING TABLE" | grep -v "^$" | grep -v "Common Name" | grep -v "Updated" || echo "")
    
    if [ -z "$CONNECTED" ]; then
        echo "No clients currently connected"
    else
        echo "$CONNECTED"
    fi
    echo ""
    
    # Show routing table
    echo "Routing Information:"
    echo "===================="
    echo ""
    ROUTING=$(grep -A 100 "ROUTING TABLE" "$STATUS_LOG" | grep -v "ROUTING TABLE" | grep -v "^$" | grep -v "Virtual Address" | grep -v "GLOBAL STATS" | head -n 20 || echo "")
    
    if [ -z "$ROUTING" ]; then
        echo "No routing information available"
    else
        echo "$ROUTING"
    fi
else
    echo "Status log not found. OpenVPN may not be running."
    echo "Check service status: sudo systemctl status openvpn-server@server"
fi

echo ""
