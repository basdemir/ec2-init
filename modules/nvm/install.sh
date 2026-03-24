#!/usr/bin/env bash
# modules/nvm/install.sh - Install NVM and Node.js LTS
#
# NVM is user-level. All nvm/node/npm commands run as BOOTSTRAP_USER.
# The .zshrc template already contains the guarded NVM init block.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/lib/log.sh"
source "${REPO_ROOT}/lib/net.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
USER_HOME="/home/${BREW_USER}"
NVM_DIR="${USER_HOME}/.nvm"

# Versions — override in manifest
NVM_VERSION="${NVM_VERSION:-v0.40.1}"
NODE_VERSION="${NODE_VERSION:-24}"     # major version; nvm resolves to latest patch

log_info "Starting NVM installation"
log_info "Target user: ${BREW_USER} | NVM: ${NVM_VERSION} | Node: ${NODE_VERSION}"

# ── Install NVM ───────────────────────────────────────────────────────────────
if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
    log_info "NVM already installed at ${NVM_DIR}"
else
    NVM_SCRIPT="/tmp/nvm-install.sh"
    log_info "Downloading NVM ${NVM_VERSION} installer"
    retry 3 curl -fsSL \
        "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" \
        -o "${NVM_SCRIPT}"
    chmod +x "${NVM_SCRIPT}"

    log_info "Running NVM installer as ${BREW_USER}"
    # NVM_DIR tells the installer where to install; XDG_CONFIG_HOME suppresses
    # it from modifying .profile when HOME is set explicitly
    sudo -u "${BREW_USER}" \
        HOME="${USER_HOME}" \
        NVM_DIR="${NVM_DIR}" \
        bash "${NVM_SCRIPT}"

    rm -f "${NVM_SCRIPT}"
    log_info "NVM installed at ${NVM_DIR}"
fi

# ── Install Node ──────────────────────────────────────────────────────────────
log_info "Installing Node.js ${NODE_VERSION}"

sudo -u "${BREW_USER}" HOME="${USER_HOME}" bash -c "
    export NVM_DIR=\"${NVM_DIR}\"
    source \"\${NVM_DIR}/nvm.sh\"

    # nvm ls <major> outputs a version line (e.g. v24.3.0) if installed, or nothing.
    # nvm install is also idempotent but skipping it avoids unnecessary output.
    if nvm ls \"${NODE_VERSION}\" 2>/dev/null | grep -q 'v${NODE_VERSION}'; then
        echo '[INFO]  Node ${NODE_VERSION} already installed'
    else
        nvm install \"${NODE_VERSION}\"
    fi

    # alias and use are fast and idempotent — safe to run every time
    nvm alias default \"${NODE_VERSION}\"
    nvm use default --silent
"

log_info "NVM installation complete"
