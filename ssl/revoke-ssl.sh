#!/bin/bash

#===============================================================================
# Script: revoke-ssl.sh
# Description: Revoke and delete SSL certificate for a domain
# Usage: sudo ./revoke-ssl.sh <domain>
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
    echo "Usage: $0 <domain>"
    echo ""
    echo "Arguments:"
    echo "  domain - Primary domain of the certificate to revoke"
    echo ""
    echo "Example:"
    echo "  $0 example.com"
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
# Validate arguments
#-------------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
    log_error "Missing required arguments"
    print_usage
    exit 1
fi

DOMAIN="$1"
CERT_PATH="/etc/letsencrypt/live/${DOMAIN}"

#-------------------------------------------------------------------------------
# Check if certificate exists
#-------------------------------------------------------------------------------
if [[ ! -d "$CERT_PATH" ]]; then
    log_error "Certificate not found for domain: $DOMAIN"
    log_error "Path does not exist: $CERT_PATH"
    echo ""
    echo "Available certificates:"
    certbot certificates
    exit 1
fi

#-------------------------------------------------------------------------------
# Confirm revocation
#-------------------------------------------------------------------------------
echo ""
log_warn "You are about to REVOKE and DELETE the SSL certificate for: $DOMAIN"
log_warn "This action cannot be undone!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    log_info "Revocation cancelled"
    exit 0
fi

#-------------------------------------------------------------------------------
# Revoke certificate
#-------------------------------------------------------------------------------
log_step "Revoking certificate..."
certbot revoke --cert-path "${CERT_PATH}/cert.pem" --non-interactive || true

#-------------------------------------------------------------------------------
# Delete certificate files
#-------------------------------------------------------------------------------
log_step "Deleting certificate files..."
certbot delete --cert-name "$DOMAIN" --non-interactive

#-------------------------------------------------------------------------------
# Final summary
#-------------------------------------------------------------------------------
echo ""
echo "=============================================="
log_info "SSL Certificate revoked and deleted!"
echo "=============================================="
echo ""
echo "Domain: ${DOMAIN}"
echo ""
echo "Next steps:"
echo "  - Update your Nginx configuration to remove SSL"
echo "  - Or run obtain-ssl.sh to get a new certificate"
echo ""


