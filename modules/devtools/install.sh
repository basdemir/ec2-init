#!/usr/bin/env bash
# modules/devtools/install.sh - Install developer tools via Homebrew
#
# BREW_PACKAGES (set in manifest) is a space-separated list of brew formulae.
# All brew operations run as the target user (brew refuses root).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/lib/log.sh"
source "${REPO_ROOT}/lib/net.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
BREW_PREFIX="${BREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
BREW_BIN="${BREW_PREFIX}/bin/brew"

# Default package list (overridden by manifest BREW_PACKAGES).
# Shell plugins (zsh-autosuggestions, zsh-syntax-highlighting) are managed as
# oh-my-zsh custom plugins by the ohmyzsh module — do NOT add them here.
BREW_PACKAGES="${BREW_PACKAGES:-fzf ripgrep bat jq htop lazygit git-delta}"

log_info "Starting devtools installation"
log_info "Packages: ${BREW_PACKAGES}"

# Sanity check: brew must already be installed
if [[ ! -x "${BREW_BIN}" ]]; then
    log_error "brew not found at ${BREW_BIN} — run the 'brew' module first"
    exit 1
fi

# ── Update Homebrew ───────────────────────────────────────────────────────────
log_info "Updating Homebrew"
retry 3 sudo -u "${BREW_USER}" \
    HOME="/home/${BREW_USER}" \
    "${BREW_BIN}" update --quiet

# ── Install packages ──────────────────────────────────────────────────────────
# brew install is idempotent — already-installed formulae are skipped
# shellcheck disable=SC2086
log_info "Installing packages (brew install)"
retry 3 sudo -u "${BREW_USER}" \
    HOME="/home/${BREW_USER}" \
    "${BREW_BIN}" install --quiet ${BREW_PACKAGES}

# ── fzf shell integration ─────────────────────────────────────────────────────
FZF_INSTALL="${BREW_PREFIX}/opt/fzf/install"
if [[ -x "${FZF_INSTALL}" ]]; then
    log_info "Running fzf shell integration"
    sudo -u "${BREW_USER}" \
        HOME="/home/${BREW_USER}" \
        "${FZF_INSTALL}" \
            --key-bindings \
            --completion \
            --no-update-rc \
            --no-bash \
            2>/dev/null || log_warn "fzf shell integration step returned non-zero (may be partial)"
fi

log_info "Devtools installation complete"
