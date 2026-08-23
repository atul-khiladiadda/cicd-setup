#!/bin/bash

#===============================================================================
# Script: list-runners.sh
# Description: List every GitHub Actions self-hosted runner installed on this
#              server, with the repository and service each one belongs to.
# Usage: ./list-runners.sh
#===============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

RUNNER_HOME="${HOME}"

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

echo ""
echo -e "${CYAN}Self-hosted runners installed under ${RUNNER_HOME}${NC}"
echo "=============================================="

FOUND=0
for dir in "${RUNNER_HOME}"/actions-runner "${RUNNER_HOME}"/actions-runner-*; do
    [[ -f "${dir}/config.sh" ]] || continue
    FOUND=$((FOUND + 1))

    REPO=$(repo_url_of "${dir}")
    NAME=$(runner_name_of "${dir}")
    SERVICE=$(cat "${dir}/.service" 2>/dev/null || true)

    if [[ -n "${SERVICE}" ]]; then
        STATE=$(systemctl is-active "${SERVICE}" 2>/dev/null || true)
    else
        STATE="not installed as service"
    fi

    if [[ "${STATE}" == "active" ]]; then
        STATE_DISPLAY="${GREEN}${STATE}${NC}"
    else
        STATE_DISPLAY="${YELLOW}${STATE:-unknown}${NC}"
    fi

    echo ""
    echo "  Directory:  ${dir}"
    echo "  Repository: ${REPO:-<not configured>}"
    echo "  Runner:     ${NAME:-<not configured>}"
    echo "  Service:    ${SERVICE:-<none>}"
    echo -e "  Status:     ${STATE_DISPLAY}"
done

echo ""
if [[ ${FOUND} -eq 0 ]]; then
    echo "  No runners found. Run ./setup-runner.sh to install one."
else
    echo "=============================================="
    echo "Total runners: ${FOUND}"
fi
echo ""
