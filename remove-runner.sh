#!/bin/bash

#===============================================================================
# Script: remove-runner.sh
# Description: Remove one repository's GitHub Actions self-hosted runner from
#              this server. Other repositories' runners are left in place.
# Usage: ./remove-runner.sh <github_repo_url> [removal_token] [--yes] [--local-only]
#
# Example:
#   ./remove-runner.sh https://github.com/username/repo AXXXXXXXXXXXX
#===============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

RUNNER_HOME="${HOME}"

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
    echo "Usage: $0 <github_repo_url> [removal_token] [--yes] [--local-only]"
    echo ""
    echo "Arguments:"
    echo "  github_repo_url  - Repository whose runner should be removed"
    echo "                     Example: https://github.com/username/repo"
    echo "  removal_token    - Token from GitHub (required when the runner is registered)"
    echo "                     Settings > Actions > Runners > New self-hosted runner"
    echo ""
    echo "Options:"
    echo "  --yes            - Skip the confirmation prompt"
    echo "  --local-only     - Stop the service and delete local files without"
    echo "                     deregistering on GitHub. Use this when registration"
    echo "                     never succeeded, or the runner was already removed"
    echo "                     in the GitHub UI."
    echo ""
    echo "The runner directory is detected from the repository URL. Only that"
    echo "repository's install is removed. Set RUNNER_DIR to target a specific path."
    echo ""
    echo "Example:"
    echo "  $0 https://github.com/myorg/myrepo AXXXXXXXXXXXX"
    echo ""
}

repo_url_of() {
    local runner_file="$1/.runner"
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

runner_name_of() {
    local runner_file="$1/.runner"
    [[ -r "${runner_file}" ]] || return 0

    local name=""
    if command -v jq >/dev/null 2>&1; then
        name=$(jq -r '.agentName // empty' "${runner_file}" 2>/dev/null || true)
    fi
    if [[ -z "${name}" ]]; then
        name=$(sed -n 's/.*"agentName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${runner_file}" | head -n 1)
    fi
    echo "${name}"
}

#-------------------------------------------------------------------------------
# Parse arguments
#-------------------------------------------------------------------------------
ASSUME_YES=0
LOCAL_ONLY=0
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y)
            ASSUME_YES=1
            shift
            ;;
        --local-only)
            LOCAL_ONLY=1
            shift
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        --)
            shift
            POSITIONAL+=("$@")
            break
            ;;
        -*)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

if [[ ${#POSITIONAL[@]} -lt 1 ]]; then
    log_error "Missing repository URL"
    print_usage
    exit 1
fi

GITHUB_REPO_URL="${POSITIONAL[0]}"
REMOVAL_TOKEN="${POSITIONAL[1]:-}"

if [[ ${#POSITIONAL[@]} -gt 2 ]]; then
    log_error "Too many arguments"
    print_usage
    exit 1
fi

if [[ $EUID -eq 0 ]]; then
    log_error "Run this as the user that owns the runner (for example, ubuntu), not as root"
    log_error "The script uses sudo itself for the service commands"
    exit 1
fi

if [[ ! "$GITHUB_REPO_URL" =~ ^https://github\.com/[^/]+/[^/]+/?$ ]]; then
    log_error "Invalid GitHub repository URL format"
    log_error "Expected format: https://github.com/owner/repo"
    exit 1
fi

REPO_PATH="${GITHUB_REPO_URL#https://github.com/}"
REPO_PATH="${REPO_PATH%/}"
REPO_PATH="${REPO_PATH%.git}"
REPO_OWNER="${REPO_PATH%%/*}"
REPO_NAME="${REPO_PATH##*/}"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
REPO_SLUG=$(echo "${REPO_OWNER}-${REPO_NAME}" | sed 's/[^A-Za-z0-9._-]/-/g')
EXPECTED_DIR="${RUNNER_HOME}/actions-runner-${REPO_SLUG}"

#-------------------------------------------------------------------------------
# Find this repository's runner, and only that one
#-------------------------------------------------------------------------------
TARGETS=()

add_target() {
    local dir="$1"
    local existing
    [[ -f "${dir}/config.sh" ]] || return 0
    for existing in "${TARGETS[@]:-}"; do
        [[ "${existing}" == "${dir}" ]] && return 0
    done
    TARGETS+=("${dir}")
}

if [[ -n "${RUNNER_DIR:-}" ]]; then
    if [[ ! -f "${RUNNER_DIR}/config.sh" ]]; then
        log_error "${RUNNER_DIR} is not a runner install (config.sh is missing)"
        exit 1
    fi
    CONFIGURED_URL=$(repo_url_of "${RUNNER_DIR}")
    if [[ -n "${CONFIGURED_URL}" && "${CONFIGURED_URL}" != "${REPO_URL}" ]]; then
        log_error "${RUNNER_DIR} is registered to ${CONFIGURED_URL}"
        log_error "Refusing to remove another project's runner."
        exit 1
    fi
    add_target "${RUNNER_DIR}"
else
    shopt -s nullglob
    for dir in "${RUNNER_HOME}"/actions-runner "${RUNNER_HOME}"/actions-runner-*; do
        [[ -f "${dir}/config.sh" ]] || continue
        CONFIGURED_URL=$(repo_url_of "${dir}")
        if [[ "${CONFIGURED_URL}" == "${REPO_URL}" ]]; then
            add_target "${dir}"
        fi
    done
    shopt -u nullglob

    # A failed registration leaves the expected directory with no .runner file
    if [[ -f "${EXPECTED_DIR}/config.sh" ]]; then
        CONFIGURED_URL=$(repo_url_of "${EXPECTED_DIR}")
        if [[ -z "${CONFIGURED_URL}" ]]; then
            add_target "${EXPECTED_DIR}"
        fi
    fi
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
    log_error "No runner found for ${REPO_URL}"
    log_error "Looked in ${EXPECTED_DIR} and ${RUNNER_HOME}/actions-runner*"
    log_error "Run ./list-runners.sh to see what is installed, or set RUNNER_DIR."
    exit 1
fi

NEEDS_TOKEN=0
if [[ "${LOCAL_ONLY}" -eq 0 ]]; then
    for dir in "${TARGETS[@]}"; do
        if [[ -f "${dir}/.runner" ]]; then
            NEEDS_TOKEN=1
        fi
    done
fi

if [[ "${NEEDS_TOKEN}" -eq 1 && -z "${REMOVAL_TOKEN}" ]]; then
    log_error "A removal token is required because this runner is registered with GitHub"
    log_error "Get one from: ${REPO_URL}/settings/actions/runners"
    log_error "Then run: $0 ${REPO_URL} <removal_token>"
    exit 1
fi

echo ""
log_info "Runner(s) that will be removed for ${REPO_URL}:"
for dir in "${TARGETS[@]}"; do
    CONFIGURED_URL=$(repo_url_of "${dir}")
    RUNNER_NAME=$(runner_name_of "${dir}")
    echo "  Directory:  ${dir}"
    echo "  Repository: ${CONFIGURED_URL:-<not registered>}"
    echo "  Runner:     ${RUNNER_NAME:-<not registered>}"
    echo ""
done

if [[ "${LOCAL_ONLY}" -eq 1 ]]; then
    log_warn "GitHub will not be contacted (--local-only)"
fi

if [[ "${ASSUME_YES}" -eq 0 ]]; then
    read -r -p "Remove the runner(s) listed above? (y/N): " REPLY
    if [[ ! "${REPLY}" =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        exit 0
    fi
fi

#-------------------------------------------------------------------------------
# Stop, deregister, and delete each matching install
#-------------------------------------------------------------------------------
for dir in "${TARGETS[@]}"; do
    log_step "Stopping ${dir}"

    if [[ -f "${dir}/svc.sh" ]]; then
        (cd "${dir}" && sudo ./svc.sh stop) || log_warn "Could not stop the service, continuing"
        (cd "${dir}" && sudo ./svc.sh uninstall) || log_warn "Could not uninstall the service, continuing"
    else
        log_warn "No svc.sh in ${dir}, skipping service removal"
    fi

    if [[ -f "${dir}/.runner" && "${LOCAL_ONLY}" -eq 0 ]]; then
        log_step "Deregistering from GitHub"
        (cd "${dir}" && ./config.sh remove --token "${REMOVAL_TOKEN}")
    elif [[ -f "${dir}/.runner" ]]; then
        log_warn "Left the GitHub registration in place (--local-only)"
        log_warn "Remove it from ${REPO_URL}/settings/actions/runners if it is still listed"
    else
        log_info "This install was never registered with GitHub"
    fi

    rm -rf "${dir}"
    log_info "Deleted ${dir}"
done

echo ""
log_info "Runner removed for ${REPO_URL}"
log_info "The deployed app, nginx site, and PM2 process were not changed"
echo ""
