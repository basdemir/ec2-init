#!/usr/bin/env bash
# modules/codex/verify.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
USER_HOME="/home/${BREW_USER}"
NVM_DIR="${USER_HOME}/.nvm"

log_info "Verifying Codex CLI"

CODEX_VER="$(sudo -u "${BREW_USER}" HOME="${USER_HOME}" bash -c "
    export NVM_DIR=\"${NVM_DIR}\"
    source \"\${NVM_DIR}/nvm.sh\"
    codex --version 2>/dev/null || npm list -g @openai/codex 2>/dev/null | grep codex | head -1
")"

[[ -n "${CODEX_VER}" ]] || { log_error "codex not found in npm global packages"; exit 1; }

log_info "Codex OK: ${CODEX_VER}"
