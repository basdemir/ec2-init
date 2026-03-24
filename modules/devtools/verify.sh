#!/usr/bin/env bash
# modules/devtools/verify.sh - Verify devtools installation via brew
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
BREW_PREFIX="${BREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
BREW_BIN="${BREW_PREFIX}/bin/brew"

# Core tools that must always be present (subset of BREW_PACKAGES)
REQUIRED_TOOLS=(fzf rg bat jq)

log_info "Verifying devtools"

# 1. brew is functional as target user
sudo -u "${BREW_USER}" "${BREW_BIN}" --version >/dev/null 2>&1 || {
    log_error "brew not functional as ${BREW_USER}"
    exit 1
}

# 2. Check each required tool is in brew's bin
FAIL=0
for tool in "${REQUIRED_TOOLS[@]}"; do
    if [[ -x "${BREW_PREFIX}/bin/${tool}" ]]; then
        VER="$(sudo -u "${BREW_USER}" "${BREW_PREFIX}/bin/${tool}" --version 2>/dev/null | head -1 || echo 'unknown')"
        log_info "  ${tool}: OK (${VER})"
    else
        log_error "  ${tool}: NOT FOUND in ${BREW_PREFIX}/bin/"
        FAIL=1
    fi
done

if (( FAIL )); then
    log_error "One or more required tools are missing"
    exit 1
fi

# 3. List installed packages (informational)
INSTALLED="$(sudo -u "${BREW_USER}" HOME="/home/${BREW_USER}" "${BREW_BIN}" list --formula 2>/dev/null | tr '\n' ' ')"
log_info "Installed formulae: ${INSTALLED}"

log_info "Devtools verify: all required tools present"
