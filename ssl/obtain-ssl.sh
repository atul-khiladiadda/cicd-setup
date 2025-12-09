#!/bin/bash

#===============================================================================
# Script: obtain-ssl.sh
# Description: Interactive SSL certificate setup - guides you to the right script
# Usage: sudo ./obtain-ssl.sh
#
# For direct usage, use the specific scripts:
#   - obtain-ssl-static.sh  - For React, HTML static sites
#   - obtain-ssl-proxy.sh   - For Node.js, Next.js app servers
#===============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo ""
echo "=============================================="
echo -e "${CYAN}SSL Certificate Setup${NC}"
echo "=============================================="
echo ""
echo "Choose your application type:"
echo ""
echo "  1) Static Site (React build, HTML, Vue build)"
echo "     → Files served directly by Nginx from a directory"
echo "     → Use: obtain-ssl-static.sh"
echo ""
echo "  2) App Server (Node.js, Next.js, Express, API)"
echo "     → App running on a port, Nginx as reverse proxy"
echo "     → Use: obtain-ssl-proxy.sh"
echo ""
echo "=============================================="
echo ""

read -p "Enter your choice (1 or 2): " choice

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case $choice in
    1)
        echo ""
        echo -e "${GREEN}Selected: Static Site${NC}"
        echo ""
        echo "Usage:"
        echo "  sudo ./obtain-ssl-static.sh <domain> <web_root> [email] [--staging]"
        echo ""
        echo "Examples:"
        echo "  sudo ./obtain-ssl-static.sh example.com /var/www/example admin@example.com"
        echo "  sudo ./obtain-ssl-static.sh myreactapp.com /var/www/myreactapp/build admin@example.com"
        echo ""
        
        read -p "Would you like to run the script now? (y/n): " run_now
        if [[ "$run_now" =~ ^[Yy]$ ]]; then
            read -p "Enter domain(s): " domain
            read -p "Enter web root directory: " web_root
            read -p "Enter email (or press Enter to skip): " email
            read -p "Use staging? (y/n): " staging
            
            CMD="sudo ${SCRIPT_DIR}/obtain-ssl-static.sh \"$domain\" \"$web_root\""
            [[ -n "$email" ]] && CMD="$CMD \"$email\""
            [[ "$staging" =~ ^[Yy]$ ]] && CMD="$CMD --staging"
            
            echo ""
            echo "Running: $CMD"
            eval $CMD
        fi
        ;;
    2)
        echo ""
        echo -e "${GREEN}Selected: App Server${NC}"
        echo ""
        echo "Usage:"
        echo "  sudo ./obtain-ssl-proxy.sh <domain> <port> [email] [--staging]"
        echo ""
        echo "Examples:"
        echo "  sudo ./obtain-ssl-proxy.sh myapp.com 3000 admin@example.com"
        echo "  sudo ./obtain-ssl-proxy.sh api.example.com 4000 admin@example.com"
        echo ""
        
        read -p "Would you like to run the script now? (y/n): " run_now
        if [[ "$run_now" =~ ^[Yy]$ ]]; then
            read -p "Enter domain(s): " domain
            read -p "Enter app port (e.g., 3000): " port
            read -p "Enter email (or press Enter to skip): " email
            read -p "Use staging? (y/n): " staging
            
            CMD="sudo ${SCRIPT_DIR}/obtain-ssl-proxy.sh \"$domain\" \"$port\""
            [[ -n "$email" ]] && CMD="$CMD \"$email\""
            [[ "$staging" =~ ^[Yy]$ ]] && CMD="$CMD --staging"
            
            echo ""
            echo "Running: $CMD"
            eval $CMD
        fi
        ;;
    *)
        echo -e "${RED}Invalid choice. Please run the script again.${NC}"
        exit 1
        ;;
esac
