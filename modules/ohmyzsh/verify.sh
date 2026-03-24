#!/usr/bin/env bash
# modules/ohmyzsh/verify.sh - Verify oh-my-zsh installation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
USER_HOME="/home/${BREW_USER}"
OMZ_DIR="${USER_HOME}/.oh-my-zsh"

log_info "Verifying oh-my-zsh"

# 1. Directory exists
[[ -d "${OMZ_DIR}" ]] || { log_error "oh-my-zsh directory not found: ${OMZ_DIR}"; exit 1; }

# 2. Main script is present
[[ -f "${OMZ_DIR}/oh-my-zsh.sh" ]] || { log_error "oh-my-zsh.sh missing from ${OMZ_DIR}"; exit 1; }

# 3. .zshrc references OMZ
ZSHRC="${USER_HOME}/.zshrc"
[[ -f "${ZSHRC}" ]] || { log_error ".zshrc not found at ${ZSHRC}"; exit 1; }
grep -q "oh-my-zsh.sh" "${ZSHRC}" || { log_error ".zshrc does not source oh-my-zsh.sh"; exit 1; }

# 4. themes directory exists
[[ -d "${OMZ_DIR}/themes" ]] || { log_error "themes directory missing from ${OMZ_DIR}"; exit 1; }

OMZ_VER="$(git -C "${OMZ_DIR}" describe --tags --abbrev=0 2>/dev/null || echo 'unknown')"
log_info "oh-my-zsh OK: dir=${OMZ_DIR} version=${OMZ_VER}"
