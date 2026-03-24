#!/usr/bin/env bash
# modules/zsh/install.sh - Install zsh and set as default shell
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/lib/log.sh"
source "${REPO_ROOT}/lib/net.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
ZSH_SET_DEFAULT_SHELL="${ZSH_SET_DEFAULT_SHELL:-true}"

log_info "Starting zsh installation"

# ── Install zsh via apt ───────────────────────────────────────────────────────
if dpkg -s zsh &>/dev/null; then
    log_info "zsh already installed ($(zsh --version 2>/dev/null | head -1))"
else
    log_info "Installing zsh via apt"
    retry 3 apt-get update -qq
    retry 3 apt-get install -y -q zsh
fi

# ── Set zsh as the default shell for the target user ─────────────────────────
if [[ "${ZSH_SET_DEFAULT_SHELL}" == "true" ]]; then
    ZSH_PATH="$(command -v zsh)"
    CURRENT_SHELL="$(getent passwd "${BREW_USER}" | cut -d: -f7)"

    if [[ "${CURRENT_SHELL}" != "${ZSH_PATH}" ]]; then
        # Ensure zsh is listed in /etc/shells
        if ! grep -qxF "${ZSH_PATH}" /etc/shells; then
            log_info "Adding ${ZSH_PATH} to /etc/shells"
            echo "${ZSH_PATH}" >> /etc/shells
        fi
        log_info "Setting zsh as default shell for ${BREW_USER}"
        chsh -s "${ZSH_PATH}" "${BREW_USER}"
    else
        log_info "zsh is already the default shell for ${BREW_USER}"
    fi
else
    log_info "ZSH_SET_DEFAULT_SHELL=false — skipping chsh"
fi

log_info "zsh installation complete ($(zsh --version 2>/dev/null | head -1))"
