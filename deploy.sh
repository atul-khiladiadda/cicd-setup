#!/bin/bash

#===============================================================================
# Script: deploy.sh
# Description: Deploy a Node.js application using PM2
# Usage: ./deploy.sh <project_name_or_path> [environment]
#
# This script is called by the GitHub Actions workflow to deploy the application.
#
# Examples:
#   ./deploy.sh my-api                              # Uses default base dir
#   ./deploy.sh my-api production                   # With environment
#   ./deploy.sh /home/ubuntu/app-deploy/my-api     # Full path
#   ./deploy.sh /var/www/myproject staging         # Custom path with env
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration - Change these defaults as needed
DEFAULT_APP_BASE_DIR="/home/ubuntu/app-deploy"
LOG_DIR="/home/ubuntu/logs"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

print_usage() {
    echo ""
    echo "Usage: $0 <project_name_or_path> [environment]"
    echo ""
    echo "Arguments:"
    echo "  project_name_or_path  - Project name or full path to the project"
    echo "                          If just a name: uses ${DEFAULT_APP_BASE_DIR}/<name>"
    echo "                          If a path (starts with /): uses the full path"
    echo "  environment           - (Optional) Environment name (default: production)"
    echo ""
    echo "Examples:"
    echo "  $0 my-api                              # ${DEFAULT_APP_BASE_DIR}/my-api"
    echo "  $0 my-api production                   # With environment"
    echo "  $0 /home/ubuntu/app-deploy/my-api     # Full path"
    echo "  $0 /var/www/myproject staging         # Custom path"
    echo ""
}

#-------------------------------------------------------------------------------
# Validate arguments
#-------------------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
    log_error "Missing required arguments"
    print_usage
    exit 1
fi

PROJECT_INPUT="$1"
ENVIRONMENT="${2:-production}"

# Determine if input is a full path or just a project name
if [[ "$PROJECT_INPUT" == /* ]]; then
    # Full path provided
    APP_DIR="$PROJECT_INPUT"
    PROJECT_NAME=$(basename "$APP_DIR")
else
    # Just project name - use default base directory
    PROJECT_NAME="$PROJECT_INPUT"
    APP_DIR="${DEFAULT_APP_BASE_DIR}/${PROJECT_NAME}"
fi

log_info "Starting deployment..."
echo "  Project: ${PROJECT_NAME}"
echo "  Environment: ${ENVIRONMENT}"
echo "  Directory: ${APP_DIR}"
echo ""

#-------------------------------------------------------------------------------
# Validate project directory exists
#-------------------------------------------------------------------------------
if [[ ! -d "${APP_DIR}" ]]; then
    log_error "Project directory does not exist: ${APP_DIR}"
    log_error "Make sure the repository has been cloned first"
    exit 1
fi

cd ${APP_DIR}

#-------------------------------------------------------------------------------
# Check for package.json
#-------------------------------------------------------------------------------
if [[ ! -f "package.json" ]]; then
    log_error "package.json not found in ${APP_DIR}"
    exit 1
fi

#-------------------------------------------------------------------------------
# Install dependencies
#-------------------------------------------------------------------------------
log_step "Installing dependencies..."

# Use npm ci for faster, reliable installs in CI/CD
if [[ -f "package-lock.json" ]]; then
    npm ci --production=false
else
    npm install
fi

#-------------------------------------------------------------------------------
# Run build if script exists
#-------------------------------------------------------------------------------
if grep -q '"build"' package.json; then
    log_step "Running build..."
    npm run build
else
    log_info "No build script found, skipping..."
fi

#-------------------------------------------------------------------------------
# Run database migrations if script exists
#-------------------------------------------------------------------------------
if grep -q '"migrate"' package.json; then
    log_step "Running database migrations..."
    npm run migrate
else
    log_info "No migrate script found, skipping..."
fi

#-------------------------------------------------------------------------------
# Determine PM2 ecosystem file or entry point
#-------------------------------------------------------------------------------
PM2_CONFIG=""
ENTRY_POINT=""

if [[ -f "ecosystem.config.js" ]]; then
    PM2_CONFIG="ecosystem.config.js"
    log_info "Using PM2 ecosystem config: ${PM2_CONFIG}"
elif [[ -f "ecosystem.config.cjs" ]]; then
    PM2_CONFIG="ecosystem.config.cjs"
    log_info "Using PM2 ecosystem config: ${PM2_CONFIG}"
elif [[ -f "pm2.config.js" ]]; then
    PM2_CONFIG="pm2.config.js"
    log_info "Using PM2 config: ${PM2_CONFIG}"
else
    # Try to determine entry point from package.json
    ENTRY_POINT=$(node -e "console.log(require('./package.json').main || 'index.js')" 2>/dev/null || echo "index.js")
    
    # Check for common entry points
    if [[ -f "dist/index.js" ]]; then
        ENTRY_POINT="dist/index.js"
    elif [[ -f "build/index.js" ]]; then
        ENTRY_POINT="build/index.js"
    elif [[ -f "src/index.js" ]]; then
        ENTRY_POINT="src/index.js"
    fi
    
    log_info "Using entry point: ${ENTRY_POINT}"
fi

#-------------------------------------------------------------------------------
# Stop existing process if running
#-------------------------------------------------------------------------------
log_step "Checking for existing PM2 process..."

if pm2 describe ${PROJECT_NAME} > /dev/null 2>&1; then
    log_info "Stopping existing process: ${PROJECT_NAME}"
    pm2 stop ${PROJECT_NAME} || true
    pm2 delete ${PROJECT_NAME} || true
else
    log_info "No existing process found"
fi

#-------------------------------------------------------------------------------
# Start/Restart application with PM2
#-------------------------------------------------------------------------------
log_step "Starting application with PM2..."

if [[ -n "${PM2_CONFIG}" ]]; then
    # Use ecosystem config file
    pm2 start ${PM2_CONFIG} --env ${ENVIRONMENT}
else
    # Start with default options
    pm2 start ${ENTRY_POINT} \
        --name ${PROJECT_NAME} \
        --max-memory-restart 500M \
        --time \
        --merge-logs \
        --log-date-format "YYYY-MM-DD HH:mm:ss Z" \
        -i max
fi

#-------------------------------------------------------------------------------
# Wait for application to start
#-------------------------------------------------------------------------------
log_step "Waiting for application to start..."
sleep 5

#-------------------------------------------------------------------------------
# Health check
#-------------------------------------------------------------------------------
log_step "Running health check..."

# Check if process is running
if pm2 describe ${PROJECT_NAME} > /dev/null 2>&1; then
    PM2_STATUS=$(pm2 jlist | jq -r ".[] | select(.name==\"${PROJECT_NAME}\") | .pm2_env.status")
    
    if [[ "${PM2_STATUS}" == "online" ]]; then
        log_info "Application is running successfully!"
    else
        log_error "Application started but status is: ${PM2_STATUS}"
        pm2 logs ${PROJECT_NAME} --lines 50
        exit 1
    fi
else
    log_error "PM2 process not found after starting"
    exit 1
fi

#-------------------------------------------------------------------------------
# Save PM2 process list
#-------------------------------------------------------------------------------
log_step "Saving PM2 process list..."
pm2 save

#-------------------------------------------------------------------------------
# Display application status
#-------------------------------------------------------------------------------
echo ""
echo "=============================================="
log_info "Deployment complete!"
echo "=============================================="
echo ""
pm2 show ${PROJECT_NAME}
echo ""
echo "Useful commands:"
echo "  - View logs:     pm2 logs ${PROJECT_NAME}"
echo "  - Monitor:       pm2 monit"
echo "  - Restart:       pm2 restart ${PROJECT_NAME}"
echo "  - Stop:          pm2 stop ${PROJECT_NAME}"
echo ""

