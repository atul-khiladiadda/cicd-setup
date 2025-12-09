#!/bin/bash

#===============================================================================
# Script: setup-dependencies.sh
# Description: Install Node.js, PM2, and other dependencies on Ubuntu EC2
# Usage: sudo ./setup-dependencies.sh [node_version]
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default Node.js version (LTS)
NODE_VERSION="${1:-20}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

#-------------------------------------------------------------------------------
# Check if running as root
#-------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

log_info "Starting dependency installation..."

#-------------------------------------------------------------------------------
# Update system packages
#-------------------------------------------------------------------------------
log_info "Updating system packages..."
apt-get update -y
apt-get upgrade -y

#-------------------------------------------------------------------------------
# Install essential build tools
#-------------------------------------------------------------------------------
log_info "Installing essential build tools..."
apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    jq

#-------------------------------------------------------------------------------
# Install Node.js via NodeSource
#-------------------------------------------------------------------------------
log_info "Installing Node.js v${NODE_VERSION}..."

# Remove any existing Node.js installation
apt-get remove -y nodejs npm 2>/dev/null || true

# Install Node.js from NodeSource
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
apt-get install -y nodejs

# Verify installation
NODE_INSTALLED=$(node --version)
NPM_INSTALLED=$(npm --version)
log_info "Node.js ${NODE_INSTALLED} installed"
log_info "npm ${NPM_INSTALLED} installed"

#-------------------------------------------------------------------------------
# Install PM2 globally
#-------------------------------------------------------------------------------
log_info "Installing PM2 globally..."
npm install -g pm2

# Setup PM2 to start on boot
log_info "Configuring PM2 startup script..."
pm2 startup systemd -u ubuntu --hp /home/ubuntu
env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ubuntu --hp /home/ubuntu

# Verify PM2 installation
PM2_VERSION=$(pm2 --version)
log_info "PM2 v${PM2_VERSION} installed"

#-------------------------------------------------------------------------------
# Create application directory structure
#-------------------------------------------------------------------------------
APP_BASE_DIR="/home/ubuntu/app-deploy"
log_info "Creating application directory structure at ${APP_BASE_DIR}..."

mkdir -p ${APP_BASE_DIR}
chown -R ubuntu:ubuntu ${APP_BASE_DIR}
chmod 755 ${APP_BASE_DIR}

#-------------------------------------------------------------------------------
# Install additional useful tools
#-------------------------------------------------------------------------------
log_info "Installing additional tools..."

# Install Yarn (optional but useful)
npm install -g yarn

# Install nginx (for reverse proxy if needed)
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

#-------------------------------------------------------------------------------
# Configure firewall (ufw)
#-------------------------------------------------------------------------------
log_info "Configuring firewall..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

#-------------------------------------------------------------------------------
# Set up log rotation for PM2
#-------------------------------------------------------------------------------
log_info "Setting up PM2 log rotation..."
pm2 install pm2-logrotate
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 7
pm2 set pm2-logrotate:compress true

#-------------------------------------------------------------------------------
# Final summary
#-------------------------------------------------------------------------------
echo ""
echo "=============================================="
log_info "Dependency installation complete!"
echo "=============================================="
echo ""
echo "Installed versions:"
echo "  - Node.js: $(node --version)"
echo "  - npm: $(npm --version)"
echo "  - PM2: $(pm2 --version)"
echo "  - Yarn: $(yarn --version)"
echo ""
echo "Application directory: ${APP_BASE_DIR}"
echo ""
echo "Next steps:"
echo "  1. Run setup-runner.sh to install GitHub Actions runner"
echo "  2. Configure your GitHub repository with the runner"
echo ""


