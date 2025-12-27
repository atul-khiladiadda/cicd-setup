#!/bin/bash

# =============================================================================
# MongoDB Setup Script for Ubuntu EC2 Instances
# =============================================================================
# This script installs and configures MongoDB on Ubuntu-based EC2 instances
# Supports Ubuntu 20.04 (Focal), 22.04 (Jammy), and 24.04 (Noble)
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default MongoDB version
MONGODB_VERSION="7.0"

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# =============================================================================
# Check Requirements
# =============================================================================

check_requirements() {
    print_header "Checking Requirements"

    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
    print_success "Running with root privileges"

    # Check if Ubuntu
    if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
        print_error "This script is designed for Ubuntu-based systems"
        exit 1
    fi
    print_success "Ubuntu detected"

    # Get Ubuntu version
    UBUNTU_VERSION=$(lsb_release -rs)
    UBUNTU_CODENAME=$(lsb_release -cs)
    print_info "Ubuntu version: $UBUNTU_VERSION ($UBUNTU_CODENAME)"

    # Check supported versions
    case $UBUNTU_CODENAME in
        focal|jammy|noble)
            print_success "Ubuntu $UBUNTU_CODENAME is supported"
            ;;
        *)
            print_warning "Ubuntu $UBUNTU_CODENAME may not be officially supported by MongoDB $MONGODB_VERSION"
            print_info "Attempting to use the closest supported version..."
            ;;
    esac
}

# =============================================================================
# Install MongoDB
# =============================================================================

install_mongodb() {
    print_header "Installing MongoDB $MONGODB_VERSION"

    # Install required packages
    print_info "Installing required packages..."
    apt-get update
    apt-get install -y gnupg curl apt-transport-https ca-certificates software-properties-common
    print_success "Required packages installed"

    # Import MongoDB public GPG key
    print_info "Adding MongoDB GPG key..."
    curl -fsSL https://www.mongodb.org/static/pgp/server-${MONGODB_VERSION}.asc | \
        gpg --dearmor -o /usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg
    print_success "MongoDB GPG key added"

    # Determine the correct Ubuntu codename for MongoDB repository
    case $UBUNTU_CODENAME in
        focal)
            REPO_CODENAME="focal"
            ;;
        jammy)
            REPO_CODENAME="jammy"
            ;;
        noble)
            # Noble (24.04) might need jammy repo if not yet supported
            REPO_CODENAME="jammy"
            ;;
        *)
            REPO_CODENAME="jammy"
            ;;
    esac

    # Add MongoDB repository
    print_info "Adding MongoDB repository..."
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg ] https://repo.mongodb.org/apt/ubuntu ${REPO_CODENAME}/mongodb-org/${MONGODB_VERSION} multiverse" | \
        tee /etc/apt/sources.list.d/mongodb-org-${MONGODB_VERSION}.list
    print_success "MongoDB repository added"

    # Update package list
    print_info "Updating package list..."
    apt-get update
    print_success "Package list updated"

    # Install MongoDB
    print_info "Installing MongoDB packages..."
    apt-get install -y mongodb-org
    print_success "MongoDB packages installed"

    # Pin the package versions to prevent unintended upgrades
    print_info "Pinning MongoDB package versions..."
    echo "mongodb-org hold" | dpkg --set-selections
    echo "mongodb-org-database hold" | dpkg --set-selections
    echo "mongodb-org-server hold" | dpkg --set-selections
    echo "mongodb-org-shell hold" | dpkg --set-selections
    echo "mongodb-org-mongos hold" | dpkg --set-selections
    echo "mongodb-org-tools hold" | dpkg --set-selections
    print_success "Package versions pinned"
}

# =============================================================================
# Configure MongoDB
# =============================================================================

configure_mongodb() {
    print_header "Configuring MongoDB"

    # Backup original config
    if [[ -f /etc/mongod.conf ]]; then
        cp /etc/mongod.conf /etc/mongod.conf.backup
        print_success "Original config backed up to /etc/mongod.conf.backup"
    fi

    # Create data and log directories if they don't exist
    mkdir -p /var/lib/mongodb
    mkdir -p /var/log/mongodb
    chown -R mongodb:mongodb /var/lib/mongodb
    chown -R mongodb:mongodb /var/log/mongodb
    print_success "Data and log directories configured"

    # Set recommended ulimits for MongoDB
    print_info "Configuring system limits..."
    cat > /etc/security/limits.d/mongodb.conf << 'EOF'
mongodb soft nofile 64000
mongodb hard nofile 64000
mongodb soft nproc 64000
mongodb hard nproc 64000
EOF
    print_success "System limits configured"

    # Disable Transparent Huge Pages (THP) - recommended for MongoDB
    print_info "Disabling Transparent Huge Pages..."
    cat > /etc/systemd/system/disable-thp.service << 'EOF'
[Unit]
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=mongod.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null'
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null'

[Install]
WantedBy=basic.target
EOF
    systemctl daemon-reload
    systemctl enable disable-thp
    systemctl start disable-thp
    print_success "Transparent Huge Pages disabled"
}

# =============================================================================
# Start MongoDB Service
# =============================================================================

start_mongodb() {
    print_header "Starting MongoDB Service"

    # Reload systemd
    systemctl daemon-reload

    # Enable MongoDB to start on boot
    systemctl enable mongod
    print_success "MongoDB enabled to start on boot"

    # Start MongoDB
    systemctl start mongod
    print_success "MongoDB service started"

    # Wait for MongoDB to be ready
    print_info "Waiting for MongoDB to be ready..."
    sleep 5

    # Check if MongoDB is running
    if systemctl is-active --quiet mongod; then
        print_success "MongoDB is running"
    else
        print_error "MongoDB failed to start. Check logs with: journalctl -u mongod"
        exit 1
    fi

    # Verify MongoDB connection
    if mongosh --eval "db.adminCommand('ping')" &>/dev/null; then
        print_success "MongoDB is accepting connections"
    else
        print_warning "MongoDB may still be initializing. Try again in a few seconds."
    fi
}

# =============================================================================
# Security Setup (Optional)
# =============================================================================

setup_security() {
    print_header "Security Configuration"

    read -p "Do you want to enable authentication? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Skipping authentication setup"
        print_warning "MongoDB is currently accessible without authentication!"
        return
    fi

    # Prompt for admin credentials
    read -p "Enter admin username: " ADMIN_USER
    read -s -p "Enter admin password: " ADMIN_PASS
    echo

    # Create admin user
    print_info "Creating admin user..."
    mongosh admin --eval "
        db.createUser({
            user: '$ADMIN_USER',
            pwd: '$ADMIN_PASS',
            roles: [
                { role: 'userAdminAnyDatabase', db: 'admin' },
                { role: 'readWriteAnyDatabase', db: 'admin' },
                { role: 'dbAdminAnyDatabase', db: 'admin' },
                { role: 'clusterAdmin', db: 'admin' }
            ]
        })
    "
    print_success "Admin user created"

    # Enable authentication in config
    print_info "Enabling authentication..."
    if grep -q "^#security:" /etc/mongod.conf; then
        sed -i 's/^#security:/security:\n  authorization: enabled/' /etc/mongod.conf
    elif grep -q "^security:" /etc/mongod.conf; then
        sed -i '/^security:/a\  authorization: enabled' /etc/mongod.conf
    else
        echo -e "\nsecurity:\n  authorization: enabled" >> /etc/mongod.conf
    fi
    print_success "Authentication enabled in config"

    # Restart MongoDB
    print_info "Restarting MongoDB with authentication..."
    systemctl restart mongod
    sleep 3

    if systemctl is-active --quiet mongod; then
        print_success "MongoDB restarted with authentication enabled"
        print_info "Connect using: mongosh -u $ADMIN_USER -p --authenticationDatabase admin"
    else
        print_error "MongoDB failed to restart. Check logs with: journalctl -u mongod"
    fi
}

# =============================================================================
# Configure Remote Access (Optional)
# =============================================================================

setup_remote_access() {
    print_header "Remote Access Configuration"

    print_warning "By default, MongoDB only listens on localhost (127.0.0.1)"
    read -p "Do you want to enable remote access? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Keeping MongoDB accessible only from localhost"
        return
    fi

    # Update bindIp in mongod.conf
    print_info "Configuring MongoDB to accept remote connections..."
    sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
    print_success "bindIp updated to 0.0.0.0"

    # Restart MongoDB
    systemctl restart mongod
    sleep 3

    if systemctl is-active --quiet mongod; then
        print_success "MongoDB restarted with remote access enabled"
    else
        print_error "MongoDB failed to restart. Check logs with: journalctl -u mongod"
    fi

    print_warning "IMPORTANT: Configure your EC2 Security Group to allow inbound traffic on port 27017"
    print_warning "Only allow access from trusted IP addresses!"
}

# =============================================================================
# Display Summary
# =============================================================================

display_summary() {
    print_header "Installation Complete!"

    # Get MongoDB version
    INSTALLED_VERSION=$(mongod --version | head -n1)

    echo -e "${GREEN}MongoDB has been successfully installed and configured!${NC}\n"
    echo "Installation Details:"
    echo "  • Version: $INSTALLED_VERSION"
    echo "  • Config: /etc/mongod.conf"
    echo "  • Data: /var/lib/mongodb"
    echo "  • Logs: /var/log/mongodb/mongod.log"
    echo ""
    echo "Useful Commands:"
    echo "  • Start:   sudo systemctl start mongod"
    echo "  • Stop:    sudo systemctl stop mongod"
    echo "  • Restart: sudo systemctl restart mongod"
    echo "  • Status:  sudo systemctl status mongod"
    echo "  • Logs:    sudo journalctl -u mongod"
    echo "  • Shell:   mongosh"
    echo ""
    echo "Default Port: 27017"
    echo ""

    # Check status
    if systemctl is-active --quiet mongod; then
        print_success "MongoDB is currently running"
    else
        print_warning "MongoDB is not running"
    fi
}

# =============================================================================
# Usage Information
# =============================================================================

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION  MongoDB version to install (default: 7.0)"
    echo "  -s, --skip-security    Skip security setup prompts"
    echo "  -r, --skip-remote      Skip remote access setup prompts"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                     # Install with default options"
    echo "  $0 -v 6.0              # Install MongoDB 6.0"
    echo "  $0 -s -r               # Install without prompts"
    exit 0
}

# =============================================================================
# Parse Arguments
# =============================================================================

SKIP_SECURITY=false
SKIP_REMOTE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            MONGODB_VERSION="$2"
            shift 2
            ;;
        -s|--skip-security)
            SKIP_SECURITY=true
            shift
            ;;
        -r|--skip-remote)
            SKIP_REMOTE=true
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            ;;
    esac
done

# =============================================================================
# Main Execution
# =============================================================================

main() {
    print_header "MongoDB Setup Script for Ubuntu EC2"
    print_info "MongoDB version: $MONGODB_VERSION"

    check_requirements
    install_mongodb
    configure_mongodb
    start_mongodb

    if [[ "$SKIP_SECURITY" == false ]]; then
        setup_security
    else
        print_warning "Skipping security setup (--skip-security flag used)"
    fi

    if [[ "$SKIP_REMOTE" == false ]]; then
        setup_remote_access
    else
        print_info "Skipping remote access setup (--skip-remote flag used)"
    fi

    display_summary
}

# Run main function
main
