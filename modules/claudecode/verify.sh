#!/usr/bin/env bash
# modules/claudecode/verify.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
USER_HOME="/home/${BREW_USER}"
NVM_DIR="${USER_HOME}/.nvm"

log_info "Verifying Claude Code"

CLAUDE_BIN="$(sudo -u "${BREW_USER}" HOME="${USER_HOME}" bash -c "
    export NVM_DIR=\"${NVM_DIR}\"
    source \"\${NVM_DIR}/nvm.sh\"
    command -v claude 2>/dev/null
")"

[[ -n "${CLAUDE_BIN}" ]] || { log_error "claude command not found"; exit 1; }

CLAUDE_VER="$(sudo -u "${BREW_USER}" HOME="${USER_HOME}" bash -c "
    export NVM_DIR=\"${NVM_DIR}\"
    source \"\${NVM_DIR}/nvm.sh\"
    claude --version 2>&1 || true
" | head -1)"

log_info "Claude Code OK: ${CLAUDE_VER:-installed} (${CLAUDE_BIN})"
