#!/bin/bash

#===============================================================================
# Script: setup-certbot.sh
# Description: Install Certbot and configure automatic SSL renewal
# Usage: sudo ./setup-certbot.sh
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

#-------------------------------------------------------------------------------
# Check if running as root
#-------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

log_info "Starting Certbot installation..."

#-------------------------------------------------------------------------------
# Update system packages
#-------------------------------------------------------------------------------
log_step "Updating system packages..."
apt-get update -y

#-------------------------------------------------------------------------------
# Install Certbot and Nginx plugin
#-------------------------------------------------------------------------------
log_step "Installing Certbot and Nginx plugin..."
apt-get install -y certbot python3-certbot-nginx

#-------------------------------------------------------------------------------
# Verify installation
#-------------------------------------------------------------------------------
CERTBOT_VERSION=$(certbot --version 2>&1)
log_info "Certbot installed: ${CERTBOT_VERSION}"

#-------------------------------------------------------------------------------
# Setup automatic renewal
#-------------------------------------------------------------------------------
log_step "Setting up automatic renewal..."

# Certbot creates a systemd timer by default on Ubuntu
# Let's verify it's enabled
if systemctl is-enabled certbot.timer &>/dev/null; then
    log_info "Certbot auto-renewal timer is already enabled"
else
    systemctl enable certbot.timer
    systemctl start certbot.timer
    log_info "Certbot auto-renewal timer enabled"
fi

# Show timer status
systemctl status certbot.timer --no-pager || true

#-------------------------------------------------------------------------------
# Create renewal hook for Nginx reload
#-------------------------------------------------------------------------------
log_step "Creating Nginx reload hook..."

mkdir -p /etc/letsencrypt/renewal-hooks/deploy

cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh << 'EOF'
#!/bin/bash
# Reload Nginx after certificate renewal
systemctl reload nginx
EOF

chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
log_info "Nginx reload hook created"

#-------------------------------------------------------------------------------
# Test renewal (dry run)
#-------------------------------------------------------------------------------
log_step "Testing renewal process (dry run)..."
certbot renew --dry-run || log_warn "Dry run failed - this is normal if no certificates exist yet"

#-------------------------------------------------------------------------------
# Final summary
#-------------------------------------------------------------------------------
echo ""
echo "=============================================="
log_info "Certbot installation complete!"
echo "=============================================="
echo ""
echo "Certbot Version: ${CERTBOT_VERSION}"
echo ""
echo "Auto-renewal: Enabled (runs twice daily)"
echo ""
echo "Next steps:"
echo "  1. Run ./obtain-ssl.sh to get SSL certificates"
echo "  2. Or manually: sudo certbot --nginx -d yourdomain.com"
echo ""
echo "Useful commands:"
echo "  - List certificates:  sudo certbot certificates"
echo "  - Renew manually:     sudo certbot renew"
echo "  - Test renewal:       sudo certbot renew --dry-run"
echo ""


