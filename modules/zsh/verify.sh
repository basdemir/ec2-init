#!/usr/bin/env bash
# modules/zsh/verify.sh - Verify zsh installation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
ZSH_SET_DEFAULT_SHELL="${ZSH_SET_DEFAULT_SHELL:-true}"

log_info "Verifying zsh"

# 1. Binary present
command -v zsh >/dev/null 2>&1 || { log_error "zsh binary not found"; exit 1; }

# 2. Functional
ZSH_VER="$(zsh --version 2>/dev/null | head -1)"
[[ -n "${ZSH_VER}" ]] || { log_error "zsh --version returned nothing"; exit 1; }

# 3. Default shell set correctly (if requested)
if [[ "${ZSH_SET_DEFAULT_SHELL}" == "true" ]]; then
    ZSH_PATH="$(command -v zsh)"
    CURRENT_SHELL="$(getent passwd "${BREW_USER}" | cut -d: -f7)"
    if [[ "${CURRENT_SHELL}" != "${ZSH_PATH}" ]]; then
        log_error "Default shell for ${BREW_USER} is '${CURRENT_SHELL}', expected '${ZSH_PATH}'"
        exit 1
    fi
fi

log_info "zsh OK: ${ZSH_VER} | default-shell=$(getent passwd "${BREW_USER}" | cut -d: -f7)"
