#!/usr/bin/env bash
# modules/sdkman/install.sh - Install SDKMAN and Temurin JDK via sdk
#
# SDKMAN is user-level (like brew/nvm) — all sdk commands run as BOOTSTRAP_USER.
# The installer modifies ~/.bashrc and ~/.zshrc; those additions are harmless
# duplicates since the .zshrc template already includes the guarded init block.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/lib/log.sh"
source "${REPO_ROOT}/lib/net.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
USER_HOME="/home/${BREW_USER}"
SDKMAN_DIR="${USER_HOME}/.sdkman"

# Versions — override in manifest
SDKMAN_JAVA_VERSION="${SDKMAN_JAVA_VERSION:-25-tem}"

log_info "Starting SDKMAN installation"
log_info "Target user: ${BREW_USER} | Java: ${SDKMAN_JAVA_VERSION}"

# ── Prerequisites ─────────────────────────────────────────────────────────────
retry 3 apt-get install -y -q curl zip unzip

# ── Install SDKMAN ────────────────────────────────────────────────────────────
if [[ -d "${SDKMAN_DIR}" && -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]]; then
    log_info "SDKMAN already installed at ${SDKMAN_DIR}"
else
    SDKMAN_SCRIPT="/tmp/sdkman-install.sh"
    log_info "Downloading SDKMAN installer"
    retry 3 curl -fsSL "https://get.sdkman.io" -o "${SDKMAN_SCRIPT}"
    chmod +x "${SDKMAN_SCRIPT}"

    log_info "Running SDKMAN installer as ${BREW_USER}"
    sudo -u "${BREW_USER}" \
        HOME="${USER_HOME}" \
        SDKMAN_DIR="${SDKMAN_DIR}" \
        bash "${SDKMAN_SCRIPT}"

    rm -f "${SDKMAN_SCRIPT}"
    log_info "SDKMAN installed at ${SDKMAN_DIR}"
fi

# ── Install Temurin JDK ───────────────────────────────────────────────────────
# sdk is a shell function — we must source sdkman-init.sh before using it.
# SDKMAN_AUTO_ANSWER=true skips interactive "set as default?" prompts.
log_info "Installing Java ${SDKMAN_JAVA_VERSION} (Temurin)"

# sdk install is idempotent: if the version is already installed SDKMAN prints
# "java X is already installed" and exits 0. We rely on that rather than parsing
# 'sdk list java' output, which uses a resolved version (e.g. 25.0.1-tem) that
# won't match the alias (25-tem) we pass in.
sudo -u "${BREW_USER}" HOME="${USER_HOME}" bash -c "
    export SDKMAN_DIR=\"${SDKMAN_DIR}\"
    source \"${SDKMAN_DIR}/bin/sdkman-init.sh\"
    SDKMAN_AUTO_ANSWER=true sdk install java \"${SDKMAN_JAVA_VERSION}\"
    sdk default java \"${SDKMAN_JAVA_VERSION}\"
"

log_info "SDKMAN installation complete"
