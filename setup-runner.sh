#!/bin/bash

#===============================================================================
# Script: setup-runner.sh
# Description: Install and configure GitHub Actions self-hosted runner on Ubuntu
# Usage: ./setup-runner.sh <github_repo_url> <runner_token> [runner_name] [labels]
#
# Example:
#   ./setup-runner.sh https://github.com/username/repo AXXXXXXXXXXXX my-runner "self-hosted,ubuntu,production"
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
RUNNER_VERSION="2.311.0"
RUNNER_DIR="/home/ubuntu/actions-runner"
RUNNER_USER="ubuntu"

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
    echo "Usage: $0 <github_repo_url> <runner_token> [runner_name] [labels]"
    echo ""
    echo "Arguments:"
    echo "  github_repo_url  - Full URL of your GitHub repository"
    echo "                     Example: https://github.com/username/repo"
    echo "  runner_token     - Registration token from GitHub"
    echo "                     (Get from: Settings > Actions > Runners > New self-hosted runner)"
    echo "  runner_name      - (Optional) Name for the runner (default: hostname)"
    echo "  labels           - (Optional) Comma-separated labels (default: self-hosted,ubuntu,ec2)"
    echo ""
    echo "Example:"
    echo "  $0 https://github.com/myorg/myrepo AXXXXXXXXXXXX prod-runner 'self-hosted,ubuntu,production'"
    echo ""
}

#-------------------------------------------------------------------------------
# Validate arguments
#-------------------------------------------------------------------------------
if [[ $# -lt 2 ]]; then
    log_error "Missing required arguments"
    print_usage
    exit 1
fi

GITHUB_REPO_URL="$1"
RUNNER_TOKEN="$2"
RUNNER_NAME="${3:-$(hostname)}"
RUNNER_LABELS="${4:-self-hosted,ubuntu,ec2}"

# Validate GitHub URL format
if [[ ! "$GITHUB_REPO_URL" =~ ^https://github.com/.+/.+ ]]; then
    log_error "Invalid GitHub repository URL format"
    log_error "Expected format: https://github.com/owner/repo"
    exit 1
fi

log_info "Configuration:"
echo "  Repository: ${GITHUB_REPO_URL}"
echo "  Runner Name: ${RUNNER_NAME}"
echo "  Labels: ${RUNNER_LABELS}"
echo "  Runner Directory: ${RUNNER_DIR}"
echo ""

#-------------------------------------------------------------------------------
# Check if running as ubuntu user
#-------------------------------------------------------------------------------
if [[ "$(whoami)" != "ubuntu" ]]; then
    log_warn "This script should be run as 'ubuntu' user"
    log_warn "Current user: $(whoami)"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

#-------------------------------------------------------------------------------
# Install runner dependencies
#-------------------------------------------------------------------------------
log_step "Installing runner dependencies..."
sudo apt-get update -y
sudo apt-get install -y libicu-dev

#-------------------------------------------------------------------------------
# Create runner directory
#-------------------------------------------------------------------------------
log_step "Creating runner directory..."
mkdir -p ${RUNNER_DIR}
cd ${RUNNER_DIR}

#-------------------------------------------------------------------------------
# Download GitHub Actions runner
#-------------------------------------------------------------------------------
log_step "Downloading GitHub Actions runner v${RUNNER_VERSION}..."

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        RUNNER_ARCH="x64"
        ;;
    aarch64|arm64)
        RUNNER_ARCH="arm64"
        ;;
    *)
        log_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

RUNNER_FILE="actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_FILE}"

if [[ -f "${RUNNER_FILE}" ]]; then
    log_info "Runner archive already exists, skipping download"
else
    curl -o ${RUNNER_FILE} -L ${RUNNER_URL}
fi

#-------------------------------------------------------------------------------
# Extract runner
#-------------------------------------------------------------------------------
log_step "Extracting runner..."
tar xzf ${RUNNER_FILE}

#-------------------------------------------------------------------------------
# Configure the runner
#-------------------------------------------------------------------------------
log_step "Configuring runner..."

# Remove existing configuration if any
if [[ -f ".runner" ]]; then
    log_warn "Existing runner configuration found. Removing..."
    ./config.sh remove --token ${RUNNER_TOKEN} 2>/dev/null || true
fi

# Configure the runner
./config.sh \
    --url ${GITHUB_REPO_URL} \
    --token ${RUNNER_TOKEN} \
    --name ${RUNNER_NAME} \
    --labels ${RUNNER_LABELS} \
    --work "_work" \
    --unattended \
    --replace

#-------------------------------------------------------------------------------
# Install runner as a service
#-------------------------------------------------------------------------------
log_step "Installing runner as a systemd service..."

sudo ./svc.sh install ${RUNNER_USER}
sudo ./svc.sh start

# Check service status
log_step "Checking runner service status..."
sudo ./svc.sh status

#-------------------------------------------------------------------------------
# Create helper scripts
#-------------------------------------------------------------------------------
log_step "Creating helper scripts..."

# Script to check runner status
cat > ${RUNNER_DIR}/check-status.sh << EOF
#!/bin/bash
cd ${RUNNER_DIR}
sudo ./svc.sh status
EOF
chmod +x ${RUNNER_DIR}/check-status.sh

# Script to restart runner
cat > ${RUNNER_DIR}/restart-runner.sh << EOF
#!/bin/bash
cd ${RUNNER_DIR}
sudo ./svc.sh stop
sudo ./svc.sh start
sudo ./svc.sh status
EOF
chmod +x ${RUNNER_DIR}/restart-runner.sh

# Script to view runner logs
cat > ${RUNNER_DIR}/view-logs.sh << 'EOF'
#!/bin/bash
sudo journalctl -u actions.runner.* -f
EOF
chmod +x ${RUNNER_DIR}/view-logs.sh

#-------------------------------------------------------------------------------
# Final summary
#-------------------------------------------------------------------------------
echo ""
echo "=============================================="
log_info "GitHub Actions runner setup complete!"
echo "=============================================="
echo ""
echo "Runner Details:"
echo "  - Name: ${RUNNER_NAME}"
echo "  - Labels: ${RUNNER_LABELS}"
echo "  - Directory: ${RUNNER_DIR}"
echo ""
echo "Helper Scripts:"
echo "  - Check status:  ${RUNNER_DIR}/check-status.sh"
echo "  - Restart runner: ${RUNNER_DIR}/restart-runner.sh"
echo "  - View logs:      ${RUNNER_DIR}/view-logs.sh"
echo ""
echo "The runner should now appear in your GitHub repository:"
echo "  Settings > Actions > Runners"
echo ""
echo "To use this runner in your workflow, add:"
echo "  runs-on: [self-hosted, ubuntu, ec2]"
echo ""

