#!/bin/bash

#===============================================================================
# Script: setup-runner.sh
# Description: Install and configure GitHub Actions self-hosted runner on Ubuntu
#              Safe to run for multiple repositories on the same server: each
#              repository gets its own runner directory, service and labels.
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
RUNNER_USER="$(whoami)"
RUNNER_HOME="${HOME}"
EXPECTED_USER="ubuntu"

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
    echo "  runner_name      - (Optional) Name for the runner"
    echo "                     (default: <hostname>-<repo>)"
    echo "  labels           - (Optional) Comma-separated labels"
    echo "                     (default: self-hosted,ubuntu,ec2)"
    echo ""
    echo "Notes:"
    echo "  Each repository gets its own runner directory, so running this script"
    echo "  for a second project does NOT affect runners already installed here."
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

# Validate GitHub URL format
if [[ ! "$GITHUB_REPO_URL" =~ ^https://github\.com/[^/]+/[^/]+/?$ ]]; then
    log_error "Invalid GitHub repository URL format"
    log_error "Expected format: https://github.com/owner/repo"
    exit 1
fi

# Derive owner/repo so every project gets its own isolated runner install
REPO_PATH="${GITHUB_REPO_URL#https://github.com/}"
REPO_PATH="${REPO_PATH%/}"
REPO_PATH="${REPO_PATH%.git}"
REPO_OWNER="${REPO_PATH%%/*}"
REPO_NAME="${REPO_PATH##*/}"

if [[ -z "$REPO_OWNER" || -z "$REPO_NAME" ]]; then
    log_error "Could not determine owner/repo from URL: ${GITHUB_REPO_URL}"
    exit 1
fi

# Normalized URL used to compare against an already configured runner
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"

# Filesystem-safe identifier for this repository
REPO_SLUG=$(echo "${REPO_OWNER}-${REPO_NAME}" | sed 's/[^A-Za-z0-9._-]/-/g')

# One runner directory per repository. Override with RUNNER_DIR=... if needed.
RUNNER_DIR="${RUNNER_DIR:-${RUNNER_HOME}/actions-runner-${REPO_SLUG}}"
LEGACY_RUNNER_DIR="${RUNNER_HOME}/actions-runner"

RUNNER_NAME="${3:-$(hostname)-${REPO_NAME}}"
RUNNER_LABELS="${4:-self-hosted,ubuntu,ec2}"

# Per-project label so a workflow can target its own runner when several are
# registered on this server (e.g. runs-on: [self-hosted, project-myrepo])
PROJECT_LABEL="project-$(echo "${REPO_NAME}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')"
if [[ ",${RUNNER_LABELS}," != *",${PROJECT_LABEL},"* ]]; then
    RUNNER_LABELS="${RUNNER_LABELS},${PROJECT_LABEL}"
fi

#-------------------------------------------------------------------------------
# Helpers
#-------------------------------------------------------------------------------

# Print the repository URL a runner directory is currently registered to.
# Empty output means "not configured" or "cannot tell".
configured_repo_url() {
    local dir="$1"
    local runner_file="${dir}/.runner"

    [[ -r "${runner_file}" ]] || return 0

    local url=""
    if command -v jq >/dev/null 2>&1; then
        url=$(jq -r '.gitHubUrl // empty' "${runner_file}" 2>/dev/null || true)
    fi
    if [[ -z "${url}" ]]; then
        url=$(sed -n 's/.*"gitHubUrl"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${runner_file}" | head -n 1)
    fi

    url="${url%/}"
    url="${url%.git}"
    echo "${url}"
}

#-------------------------------------------------------------------------------
# Check if running as root/sudo (not allowed for runner config)
#-------------------------------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
    log_error "This script must NOT be run as root or with sudo"
    log_error "The GitHub Actions runner cannot be configured as root"
    log_error ""
    log_error "Please run as a regular user (e.g., ubuntu):"
    log_error "  ./setup-runner.sh $*"
    exit 1
fi

#-------------------------------------------------------------------------------
# Check if running as expected user
#-------------------------------------------------------------------------------
if [[ "${RUNNER_USER}" != "${EXPECTED_USER}" ]]; then
    log_warn "The provided workflows expect deployments under /home/${EXPECTED_USER}"
    log_warn "Current user: ${RUNNER_USER} (runner will be installed in ${RUNNER_HOME})"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

#-------------------------------------------------------------------------------
# Reuse the legacy single-runner directory only if it belongs to this repository
#-------------------------------------------------------------------------------
if [[ "${RUNNER_DIR}" != "${LEGACY_RUNNER_DIR}" && -f "${LEGACY_RUNNER_DIR}/config.sh" ]]; then
    LEGACY_URL=$(configured_repo_url "${LEGACY_RUNNER_DIR}")
    if [[ "${LEGACY_URL}" == "${REPO_URL}" ]]; then
        log_info "Found an existing runner for this repository at ${LEGACY_RUNNER_DIR}"
        log_info "Reusing it instead of creating a new install"
        RUNNER_DIR="${LEGACY_RUNNER_DIR}"
    elif [[ -n "${LEGACY_URL}" ]]; then
        log_warn "${LEGACY_RUNNER_DIR} belongs to ${LEGACY_URL} and will be left untouched"
    fi
fi

#-------------------------------------------------------------------------------
# Refuse to touch a directory registered to a different repository
#-------------------------------------------------------------------------------
if [[ -d "${RUNNER_DIR}" ]]; then
    EXISTING_URL=$(configured_repo_url "${RUNNER_DIR}")
    if [[ -n "${EXISTING_URL}" && "${EXISTING_URL}" != "${REPO_URL}" ]]; then
        log_error "${RUNNER_DIR} is already registered to ${EXISTING_URL}"
        log_error "Refusing to overwrite another project's runner."
        log_error "Remove it first with ${RUNNER_DIR}/remove-runner.sh, or set RUNNER_DIR to a different path."
        exit 1
    fi
fi

log_info "Configuration:"
echo "  Repository: ${REPO_URL}"
echo "  Runner Name: ${RUNNER_NAME}"
echo "  Labels: ${RUNNER_LABELS}"
echo "  Runner Directory: ${RUNNER_DIR}"
echo ""

#-------------------------------------------------------------------------------
# Show runners already installed on this server
#-------------------------------------------------------------------------------
EXISTING_SERVICES=$(systemctl list-units --type=service --all --no-legend --plain 'actions.runner.*' 2>/dev/null | awk '{print $1}' || true)
if [[ -n "${EXISTING_SERVICES}" ]]; then
    log_info "Runners already installed on this server (these will not be modified):"
    echo "${EXISTING_SERVICES}" | sed 's/^/  - /'
    echo ""
fi

#-------------------------------------------------------------------------------
# Install runner dependencies
#-------------------------------------------------------------------------------
log_step "Installing runner dependencies..."
sudo apt-get update -y
sudo apt-get install -y libicu-dev

#-------------------------------------------------------------------------------
# Stop and deregister a previous install of THIS repository's runner
#-------------------------------------------------------------------------------
if [[ -d "${RUNNER_DIR}" ]]; then
    log_step "Existing install for this repository found. Deregistering before reinstall..."
    cd "${RUNNER_DIR}"

    if [[ -f "svc.sh" && -f ".service" ]]; then
        sudo ./svc.sh stop || true
        sudo ./svc.sh uninstall || true
    fi

    if [[ -f ".runner" ]]; then
        # Registration tokens are not always valid for removal; --replace covers that case
        ./config.sh remove --token "${RUNNER_TOKEN}" 2>/dev/null || log_warn "Could not deregister automatically, continuing with --replace"
    fi

    cd - >/dev/null
fi

#-------------------------------------------------------------------------------
# Create runner directory
#-------------------------------------------------------------------------------
log_step "Preparing runner directory..."
mkdir -p "${RUNNER_DIR}"
sudo chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_DIR}"

cd "${RUNNER_DIR}"

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
    curl -o "${RUNNER_FILE}" -L "${RUNNER_URL}"
fi

#-------------------------------------------------------------------------------
# Extract runner
#-------------------------------------------------------------------------------
log_step "Extracting runner..."
tar xzf "${RUNNER_FILE}"

#-------------------------------------------------------------------------------
# Configure the runner
#-------------------------------------------------------------------------------
log_step "Configuring runner..."

./config.sh \
    --url "${REPO_URL}" \
    --token "${RUNNER_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABELS}" \
    --work "_work" \
    --unattended \
    --replace

#-------------------------------------------------------------------------------
# Install runner as a service
#-------------------------------------------------------------------------------
log_step "Installing runner as a systemd service..."

sudo ./svc.sh install "${RUNNER_USER}"
sudo ./svc.sh start

# Service name is written by svc.sh; used to scope the helper scripts below
SERVICE_NAME=$(cat "${RUNNER_DIR}/.service" 2>/dev/null || echo "actions.runner.*")

# Check service status
log_step "Checking runner service status..."
sudo ./svc.sh status

#-------------------------------------------------------------------------------
# Create helper scripts
#-------------------------------------------------------------------------------
log_step "Creating helper scripts..."

# Script to check runner status
cat > "${RUNNER_DIR}/check-status.sh" << EOF
#!/bin/bash
cd ${RUNNER_DIR}
sudo ./svc.sh status
EOF
chmod +x "${RUNNER_DIR}/check-status.sh"

# Script to restart runner
cat > "${RUNNER_DIR}/restart-runner.sh" << EOF
#!/bin/bash
cd ${RUNNER_DIR}
sudo ./svc.sh stop
sudo ./svc.sh start
sudo ./svc.sh status
EOF
chmod +x "${RUNNER_DIR}/restart-runner.sh"

# Script to view logs for this runner only
cat > "${RUNNER_DIR}/view-logs.sh" << EOF
#!/bin/bash
sudo journalctl -u ${SERVICE_NAME} -f
EOF
chmod +x "${RUNNER_DIR}/view-logs.sh"

# Script to remove only this repository's runner
cat > "${RUNNER_DIR}/remove-runner.sh" << EOF
#!/bin/bash
#
# Removes the runner for ${REPO_URL} only. Other projects on this server
# are not affected.
#
# Usage: ./remove-runner.sh <removal_token>
#   Get the token from: ${REPO_URL}/settings/actions/runners
set -e

if [[ \$# -lt 1 ]]; then
    echo "Usage: \$0 <removal_token>"
    echo "Get a token from: ${REPO_URL}/settings/actions/runners"
    exit 1
fi

cd ${RUNNER_DIR}
sudo ./svc.sh stop || true
sudo ./svc.sh uninstall || true
./config.sh remove --token "\$1"

echo "Runner removed. Delete ${RUNNER_DIR} manually if you no longer need it."
EOF
chmod +x "${RUNNER_DIR}/remove-runner.sh"

#-------------------------------------------------------------------------------
# Final summary
#-------------------------------------------------------------------------------
echo ""
echo "=============================================="
log_info "GitHub Actions runner setup complete!"
echo "=============================================="
echo ""
echo "Runner Details:"
echo "  - Repository: ${REPO_URL}"
echo "  - Name: ${RUNNER_NAME}"
echo "  - Labels: ${RUNNER_LABELS}"
echo "  - Directory: ${RUNNER_DIR}"
echo "  - Service: ${SERVICE_NAME}"
echo ""
echo "Helper Scripts:"
echo "  - Check status:   ${RUNNER_DIR}/check-status.sh"
echo "  - Restart runner: ${RUNNER_DIR}/restart-runner.sh"
echo "  - View logs:      ${RUNNER_DIR}/view-logs.sh"
echo "  - Remove runner:  ${RUNNER_DIR}/remove-runner.sh <removal_token>"
echo ""
echo "The runner should now appear in your GitHub repository:"
echo "  Settings > Actions > Runners"
echo ""
echo "To use this runner in your workflow, add:"
echo "  runs-on: [self-hosted, ubuntu, ec2]"
echo ""
echo "If several projects share this server and you want to pin a workflow to"
echo "this runner, use its project label instead:"
echo "  runs-on: [self-hosted, ${PROJECT_LABEL}]"
echo ""
