#!/usr/bin/env bash
# modules/brew/verify.sh - Verify Homebrew installation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
BREW_PREFIX="${BREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
BREW_BIN="${BREW_PREFIX}/bin/brew"

log_info "Verifying Homebrew"

# 1. Binary exists and is executable
[[ -x "${BREW_BIN}" ]] || { log_error "brew binary not found at ${BREW_BIN}"; exit 1; }

# 2. Works as target user
BREW_VER="$(sudo -u "${BREW_USER}" "${BREW_BIN}" --version 2>/dev/null | head -1)"
[[ -n "${BREW_VER}" ]] || { log_error "brew --version returned nothing"; exit 1; }

# 3. profile.d entry exists
[[ -f /etc/profile.d/linuxbrew.sh ]] || \
    log_warn "/etc/profile.d/linuxbrew.sh not found — PATH may not include brew"

# 4. User is in devbrew group
groups "${BREW_USER}" | grep -q '\bdevbrew\b' || \
    log_warn "${BREW_USER} not in devbrew group"

log_info "Homebrew OK: ${BREW_VER} | prefix=${BREW_PREFIX}"
