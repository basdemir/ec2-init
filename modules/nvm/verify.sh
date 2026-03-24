#!/usr/bin/env bash
# modules/nvm/verify.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
USER_HOME="/home/${BREW_USER}"
NVM_DIR="${USER_HOME}/.nvm"
NODE_VERSION="${NODE_VERSION:-24}"

log_info "Verifying NVM"

# 1. NVM script exists
[[ -s "${NVM_DIR}/nvm.sh" ]] || { log_error "NVM not found at ${NVM_DIR}"; exit 1; }

# 2. Node and npm are available in the NVM environment
NODE_VER="$(sudo -u "${BREW_USER}" HOME="${USER_HOME}" bash -c "
    export NVM_DIR=\"${NVM_DIR}\"
    source \"\${NVM_DIR}/nvm.sh\"
    node --version 2>/dev/null
")"
[[ -n "${NODE_VER}" ]] || { log_error "node not available in NVM environment"; exit 1; }

NPM_VER="$(sudo -u "${BREW_USER}" HOME="${USER_HOME}" bash -c "
    export NVM_DIR=\"${NVM_DIR}\"
    source \"\${NVM_DIR}/nvm.sh\"
    npm --version 2>/dev/null
")"

# 3. Version check — major must match
NODE_MAJOR="${NODE_VER#v}"
NODE_MAJOR="${NODE_MAJOR%%.*}"
if [[ "${NODE_MAJOR}" != "${NODE_VERSION}" ]]; then
    log_warn "Node major version is ${NODE_MAJOR}, expected ${NODE_VERSION}"
fi

log_info "NVM OK: node=${NODE_VER} npm=${NPM_VER}"
