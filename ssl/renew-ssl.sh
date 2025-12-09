#!/bin/bash

#===============================================================================
# Script: renew-ssl.sh
# Description: Manually renew SSL certificates
# Usage: sudo ./renew-ssl.sh [--force] [--dry-run]
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

print_usage() {
    echo ""
    echo "Usage: $0 [--force] [--dry-run]"
    echo ""
    echo "Options:"
    echo "  --force    - Force renewal even if not due"
    echo "  --dry-run  - Test renewal without making changes"
    echo ""
    echo "Examples:"
    echo "  $0               # Normal renewal (only if due)"
    echo "  $0 --dry-run     # Test renewal process"
    echo "  $0 --force       # Force renewal now"
    echo ""
}

#-------------------------------------------------------------------------------
# Check if running as root
#-------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

#-------------------------------------------------------------------------------
# Parse arguments
#-------------------------------------------------------------------------------
FORCE=""
DRY_RUN=""

for arg in "$@"; do
    case $arg in
        --force)
            FORCE="--force-renewal"
            ;;
        --dry-run)
            DRY_RUN="--dry-run"
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
    esac
done

#-------------------------------------------------------------------------------
# Show current certificates
#-------------------------------------------------------------------------------
log_step "Current certificates:"
echo ""
certbot certificates
echo ""

#-------------------------------------------------------------------------------
# Run renewal
#-------------------------------------------------------------------------------
if [[ -n "$DRY_RUN" ]]; then
    log_step "Running renewal dry-run..."
else
    log_step "Running renewal..."
fi

CERTBOT_CMD="certbot renew"
[[ -n "$FORCE" ]] && CERTBOT_CMD="$CERTBOT_CMD $FORCE"
[[ -n "$DRY_RUN" ]] && CERTBOT_CMD="$CERTBOT_CMD $DRY_RUN"

echo "Running: $CERTBOT_CMD"
echo ""

eval $CERTBOT_CMD

#-------------------------------------------------------------------------------
# Reload Nginx (if not dry-run)
#-------------------------------------------------------------------------------
if [[ -z "$DRY_RUN" ]]; then
    log_step "Reloading Nginx..."
    systemctl reload nginx
fi

#-------------------------------------------------------------------------------
# Final summary
#-------------------------------------------------------------------------------
echo ""
echo "=============================================="
if [[ -n "$DRY_RUN" ]]; then
    log_info "Renewal dry-run complete!"
else
    log_info "Renewal process complete!"
fi
echo "=============================================="
echo ""
echo "Check renewal timer status:"
echo "  systemctl status certbot.timer"
echo ""
echo "View renewal logs:"
echo "  sudo journalctl -u certbot"
echo ""

