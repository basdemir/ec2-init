#!/usr/bin/env bash
# modules/devtools/verify.sh - Verify all BREW_PACKAGES are installed
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
BREW_PREFIX="${BREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
BREW_BIN="${BREW_PREFIX}/bin/brew"
BREW_PACKAGES="${BREW_PACKAGES:-fzf ripgrep bat lazygit git-delta go gh}"

# Map formula name → binary name where they differ
declare -A BINARY_MAP=(
    [ripgrep]="rg"
    [git-delta]="delta"
)

log_info "Verifying brew packages: ${BREW_PACKAGES}"

FAIL=0
for formula in ${BREW_PACKAGES}; do
    bin="${BINARY_MAP[${formula}]:-${formula}}"
    if [[ -x "${BREW_PREFIX}/bin/${bin}" ]]; then
        VER="$(sudo -u "${BREW_USER}" "${BREW_PREFIX}/bin/${bin}" --version 2>/dev/null | head -1 || echo 'ok')"
        log_info "  ${formula}: OK (${VER})"
    else
        log_error "  ${formula}: NOT FOUND at ${BREW_PREFIX}/bin/${bin}"
        FAIL=1
    fi
done

(( FAIL )) && { log_error "One or more brew packages missing"; exit 1; }
log_info "All brew packages verified"
