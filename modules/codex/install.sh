#!/usr/bin/env bash
# modules/codex/install.sh - Install OpenAI Codex CLI via npm
#
# Depends on: nvm module (provides node + npm)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/lib/log.sh"
source "${REPO_ROOT}/lib/net.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
USER_HOME="/home/${BREW_USER}"
NVM_DIR="${USER_HOME}/.nvm"

log_info "Starting Codex CLI installation"

# ── Dependency check ──────────────────────────────────────────────────────────
[[ -s "${NVM_DIR}/nvm.sh" ]] || {
    log_error "NVM not found — run the 'nvm' module first"
    exit 1
}

# ── Install @openai/codex globally ────────────────────────────────────────────
sudo -u "${BREW_USER}" HOME="${USER_HOME}" bash -c "
    export NVM_DIR=\"${NVM_DIR}\"
    source \"\${NVM_DIR}/nvm.sh\"

    if npm list -g @openai/codex 2>/dev/null | grep -q '@openai/codex'; then
        echo '[INFO]  @openai/codex already installed'
    else
        log_info 'Installing @openai/codex via npm'
        npm install -g @openai/codex --quiet
    fi
"

log_info "Codex CLI installation complete"
