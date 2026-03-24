#!/usr/bin/env bash
# modules/claudecode/install.sh - Install Claude Code CLI
#
# Uses the official installer at https://claude.ai/install.sh
# Downloaded to /tmp first (not piped directly to bash).
# Depends on: nvm module (provides node + npm in PATH)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/lib/log.sh"
source "${REPO_ROOT}/lib/net.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
USER_HOME="/home/${BREW_USER}"
NVM_DIR="${USER_HOME}/.nvm"

log_info "Starting Claude Code installation"

# ── Dependency check ──────────────────────────────────────────────────────────
[[ -s "${NVM_DIR}/nvm.sh" ]] || {
    log_error "NVM not found — run the 'nvm' module first"
    exit 1
}

# ── Check if already installed ────────────────────────────────────────────────
ALREADY_INSTALLED="$(sudo -u "${BREW_USER}" HOME="${USER_HOME}" bash -c "
    export PATH=\"${USER_HOME}/.local/bin:\${PATH}\"
    export NVM_DIR=\"${NVM_DIR}\"
    [ -s \"\${NVM_DIR}/nvm.sh\" ] && source \"\${NVM_DIR}/nvm.sh\"
    command -v claude 2>/dev/null
" 2>/dev/null || true)"

if [[ -n "${ALREADY_INSTALLED}" ]]; then
    log_info "Claude Code already installed at ${ALREADY_INSTALLED}"
else
    # ── Download installer ────────────────────────────────────────────────────
    CLAUDE_SCRIPT="/tmp/claude-install.sh"
    log_info "Downloading Claude Code installer"
    retry 3 curl -fsSL "https://claude.ai/install.sh" -o "${CLAUDE_SCRIPT}"
    chmod +x "${CLAUDE_SCRIPT}"

    log_info "Running Claude Code installer as ${BREW_USER}"
    sudo -u "${BREW_USER}" HOME="${USER_HOME}" bash -c "
        export NVM_DIR=\"${NVM_DIR}\"
        source \"\${NVM_DIR}/nvm.sh\"
        bash \"${CLAUDE_SCRIPT}\"
    "
    rm -f "${CLAUDE_SCRIPT}"
fi

log_info "Claude Code installation complete"
