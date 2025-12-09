#!/bin/bash

#===============================================================================
# Script: list-ssl.sh
# Description: List all SSL certificates and their status
# Usage: sudo ./list-ssl.sh
#===============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

#-------------------------------------------------------------------------------
# Check if running as root
#-------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root (use sudo)"
    exit 1
fi

echo ""
echo "=============================================="
log_info "SSL Certificates Status"
echo "=============================================="
echo ""

#-------------------------------------------------------------------------------
# List certificates
#-------------------------------------------------------------------------------
log_step "Installed Certificates:"
echo ""
certbot certificates
echo ""

#-------------------------------------------------------------------------------
# Show renewal timer status
#-------------------------------------------------------------------------------
log_step "Auto-Renewal Timer Status:"
echo ""
systemctl status certbot.timer --no-pager 2>/dev/null || echo "Certbot timer not found"
echo ""

#-------------------------------------------------------------------------------
# Show next renewal check
#-------------------------------------------------------------------------------
log_step "Next Renewal Check:"
echo ""
systemctl list-timers certbot.timer --no-pager 2>/dev/null || echo "Timer info not available"
echo ""

#-------------------------------------------------------------------------------
# Check certificate expiry dates
#-------------------------------------------------------------------------------
log_step "Certificate Expiry Details:"
echo ""

CERT_DIR="/etc/letsencrypt/live"
if [[ -d "$CERT_DIR" ]]; then
    for domain_dir in "$CERT_DIR"/*/; do
        if [[ -d "$domain_dir" ]]; then
            domain=$(basename "$domain_dir")
            cert_file="${domain_dir}cert.pem"
            
            if [[ -f "$cert_file" ]]; then
                expiry=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
                expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry" +%s 2>/dev/null)
                now_epoch=$(date +%s)
                days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
                
                if [[ $days_left -lt 7 ]]; then
                    echo -e "  ${RED}⚠ $domain${NC}"
                    echo -e "    Expires: $expiry (${RED}$days_left days left${NC})"
                elif [[ $days_left -lt 30 ]]; then
                    echo -e "  ${YELLOW}● $domain${NC}"
                    echo -e "    Expires: $expiry (${YELLOW}$days_left days left${NC})"
                else
                    echo -e "  ${GREEN}✓ $domain${NC}"
                    echo -e "    Expires: $expiry (${GREEN}$days_left days left${NC})"
                fi
                echo ""
            fi
        fi
    done
else
    echo "  No certificates found"
fi

echo ""
echo "=============================================="
echo ""
echo "Useful commands:"
echo "  - Renew certificates:     sudo certbot renew"
echo "  - Test renewal:           sudo certbot renew --dry-run"
echo "  - Get new certificate:    sudo ./obtain-ssl.sh <domain> <email>"
echo "  - View renewal logs:      sudo journalctl -u certbot"
echo ""


