#!/bin/bash

#===============================================================================
# Script: obtain-ssl-static.sh
# Description: Obtain SSL certificate for static websites (React, HTML)
#              Configures Nginx to serve files from a directory
# Usage: sudo ./obtain-ssl-static.sh <domain> <web_root> [email] [--staging]
#
# Examples:
#   sudo ./obtain-ssl-static.sh example.com /var/www/example admin@example.com
#   sudo ./obtain-ssl-static.sh "example.com,www.example.com" /var/www/example admin@example.com
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
    echo "Usage: $0 <domain> <web_root> [email] [--staging]"
    echo ""
    echo "For: Static websites (React builds, HTML sites)"
    echo ""
    echo "Arguments:"
    echo "  domain    - Domain name(s) for the certificate"
    echo "              Single: example.com"
    echo "              Multiple: \"example.com,www.example.com\""
    echo "  web_root  - Directory containing your static files"
    echo "              e.g., /var/www/example or /var/www/myapp/build"
    echo "  email     - Email for Let's Encrypt notifications (optional)"
    echo "  --staging - Use Let's Encrypt staging server (for testing)"
    echo ""
    echo "Examples:"
    echo "  $0 example.com /var/www/example"
    echo "  $0 example.com /var/www/example admin@example.com"
    echo "  $0 myreactapp.com /var/www/myreactapp admin@example.com"
    echo "  $0 example.com /var/www/example admin@example.com --staging"
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
if [[ $# -lt 2 ]]; then
    log_error "Missing required arguments"
    print_usage
    exit 1
fi

DOMAIN="$1"
WEB_ROOT="$2"
EMAIL="${3:-}"
STAGING=""

# Check for --staging flag
for arg in "$@"; do
    if [[ "$arg" == "--staging" ]]; then
        STAGING="--staging"
        log_warn "Using Let's Encrypt STAGING server (certificates will NOT be trusted)"
    fi
done

# Remove --staging from email if passed as email
if [[ "$EMAIL" == "--staging" ]]; then
    EMAIL=""
fi

#-------------------------------------------------------------------------------
# Validate domain format
#-------------------------------------------------------------------------------
PRIMARY_DOMAIN=$(echo "$DOMAIN" | cut -d',' -f1)
if [[ ! "$PRIMARY_DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$ ]]; then
    log_error "Invalid domain format: $PRIMARY_DOMAIN"
    exit 1
fi

NGINX_CONF_NAME=$(echo "$PRIMARY_DOMAIN" | tr '.' '-')

log_info "SSL Certificate for Static Site"
echo "  Domain(s): ${DOMAIN}"
echo "  Web Root: ${WEB_ROOT}"
echo "  Email: ${EMAIL:-'(not provided)'}"
echo "  Mode: ${STAGING:-'Production'}"
echo ""

#-------------------------------------------------------------------------------
# Check prerequisites
#-------------------------------------------------------------------------------
if ! command -v certbot &> /dev/null; then
    log_error "Certbot is not installed. Run setup-certbot.sh first."
    exit 1
fi

if ! command -v nginx &> /dev/null; then
    log_error "Nginx is not installed."
    exit 1
fi

#-------------------------------------------------------------------------------
# Create web root directory
#-------------------------------------------------------------------------------
log_step "Creating web root directory..."
mkdir -p "${WEB_ROOT}"
chown -R www-data:www-data "${WEB_ROOT}" 2>/dev/null || chown -R ubuntu:ubuntu "${WEB_ROOT}"

#-------------------------------------------------------------------------------
# Build server_name directive
#-------------------------------------------------------------------------------
IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAIN"
SERVER_NAMES=""
for d in "${DOMAIN_ARRAY[@]}"; do
    d=$(echo "$d" | xargs)
    SERVER_NAMES="$SERVER_NAMES $d"
done
SERVER_NAMES=$(echo "$SERVER_NAMES" | xargs)

#-------------------------------------------------------------------------------
# Create Nginx configuration for static site
#-------------------------------------------------------------------------------
log_step "Creating Nginx configuration..."

cat > /etc/nginx/sites-available/${NGINX_CONF_NAME} << EOF
# Nginx configuration for ${PRIMARY_DOMAIN} (Static Site)
# Generated by obtain-ssl-static.sh on $(date)

server {
    listen 80;
    listen [::]:80;
    server_name ${SERVER_NAMES};

    root ${WEB_ROOT};
    index index.html index.htm;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json application/xml image/svg+xml;

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|pdf)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # React Router / SPA support - serve index.html for all routes
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }
}
EOF

#-------------------------------------------------------------------------------
# Enable site
#-------------------------------------------------------------------------------
log_step "Enabling Nginx site..."

rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
ln -sf /etc/nginx/sites-available/${NGINX_CONF_NAME} /etc/nginx/sites-enabled/

nginx -t
systemctl reload nginx

#-------------------------------------------------------------------------------
# Build and run certbot command
#-------------------------------------------------------------------------------
log_step "Obtaining SSL certificate..."

CERTBOT_CMD="certbot --nginx"

for d in "${DOMAIN_ARRAY[@]}"; do
    d=$(echo "$d" | xargs)
    CERTBOT_CMD="$CERTBOT_CMD -d $d"
done

if [[ -n "$EMAIL" ]]; then
    CERTBOT_CMD="$CERTBOT_CMD --email $EMAIL"
else
    CERTBOT_CMD="$CERTBOT_CMD --register-unsafely-without-email"
fi

[[ -n "$STAGING" ]] && CERTBOT_CMD="$CERTBOT_CMD --staging"

CERTBOT_CMD="$CERTBOT_CMD --non-interactive --agree-tos --redirect"

echo "Running: $CERTBOT_CMD"
eval $CERTBOT_CMD

#-------------------------------------------------------------------------------
# Final summary
#-------------------------------------------------------------------------------
echo ""
echo "=============================================="
log_info "SSL Certificate configured successfully!"
echo "=============================================="
echo ""
echo "Type: Static Site (React/HTML)"
echo "Domain(s): ${DOMAIN}"
echo "Web Root: ${WEB_ROOT}"
echo ""
echo "Your site is now accessible via HTTPS:"
for d in "${DOMAIN_ARRAY[@]}"; do
    d=$(echo "$d" | xargs)
    echo "  - https://${d}"
done
echo ""
echo "Nginx config: /etc/nginx/sites-available/${NGINX_CONF_NAME}"
echo ""
if [[ -n "$STAGING" ]]; then
    log_warn "This is a STAGING certificate - browsers will show security warnings!"
fi
echo ""

