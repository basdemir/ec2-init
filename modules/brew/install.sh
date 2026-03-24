#!/usr/bin/env bash
# modules/brew/install.sh - Install Homebrew (Linuxbrew) for non-root user
#
# Linuxbrew is installed to /home/linuxbrew/.linuxbrew under a 'devbrew' group.
# All brew operations run as the target user — brew refuses to run as root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/lib/log.sh"
source "${REPO_ROOT}/lib/net.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
BREW_GROUP="devbrew"
BREW_PREFIX="${BREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
BREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
# Set BREW_INSTALL_SHA256 in the manifest to pin the installer to a known-good version
BREW_INSTALL_SHA256="${BREW_INSTALL_SHA256:-}"

USER_HOME="/home/${BREW_USER}"

log_info "Starting Homebrew (Linuxbrew) installation"
log_info "Target user: ${BREW_USER} | Prefix: ${BREW_PREFIX}"

# ── Build dependencies ────────────────────────────────────────────────────────
log_info "Installing build dependencies"
retry 3 apt-get update -qq
retry 3 apt-get install -y -q \
    build-essential \
    procps \
    curl \
    file \
    git

# ── Group setup ───────────────────────────────────────────────────────────────
if ! getent group "${BREW_GROUP}" >/dev/null; then
    log_info "Creating group: ${BREW_GROUP}"
    groupadd --system "${BREW_GROUP}"
else
    log_info "Group '${BREW_GROUP}' already exists"
fi

if ! groups "${BREW_USER}" | grep -q "\b${BREW_GROUP}\b"; then
    log_info "Adding ${BREW_USER} to ${BREW_GROUP}"
    usermod -aG "${BREW_GROUP}" "${BREW_USER}"
else
    log_info "${BREW_USER} already in ${BREW_GROUP}"
fi

# ── Prefix directory ──────────────────────────────────────────────────────────
if [[ ! -d "${BREW_PREFIX}" ]]; then
    log_info "Creating brew prefix: ${BREW_PREFIX}"
    mkdir -p "$(dirname "${BREW_PREFIX}")"
    chown "${BREW_USER}:${BREW_GROUP}" "$(dirname "${BREW_PREFIX}")"
fi

# ── Install Homebrew ──────────────────────────────────────────────────────────
BREW_BIN="${BREW_PREFIX}/bin/brew"

if [[ -x "${BREW_BIN}" ]]; then
    log_info "Homebrew already installed at ${BREW_BIN}"
else
    BREW_SCRIPT="/tmp/brew-install.sh"
    log_info "Downloading Homebrew installer"
    download_verified "${BREW_INSTALL_URL}" "${BREW_SCRIPT}" "${BREW_INSTALL_SHA256}"
    chmod +x "${BREW_SCRIPT}"

    log_info "Running Homebrew installer as ${BREW_USER} (NONINTERACTIVE)"
    sudo -u "${BREW_USER}" \
        HOME="${USER_HOME}" \
        NONINTERACTIVE=1 \
        bash "${BREW_SCRIPT}"

    rm -f "${BREW_SCRIPT}"
    log_info "Homebrew installed"
fi

# ── /etc/profile.d entry (login shell PATH for all users) ────────────────────
PROFILE_D="/etc/profile.d/linuxbrew.sh"
if [[ ! -f "${PROFILE_D}" ]]; then
    log_info "Writing ${PROFILE_D}"
    cat > "${PROFILE_D}" <<PROFILE
# Linuxbrew — added by ec2-init
export HOMEBREW_PREFIX="${BREW_PREFIX}"
export HOMEBREW_CELLAR="${BREW_PREFIX}/Cellar"
export HOMEBREW_REPOSITORY="${BREW_PREFIX}/Homebrew"
export PATH="${BREW_PREFIX}/bin:${BREW_PREFIX}/sbin:\${PATH}"
export MANPATH="${BREW_PREFIX}/share/man:\${MANPATH:-}"
export INFOPATH="${BREW_PREFIX}/share/info:\${INFOPATH:-}"
PROFILE
else
    log_info "${PROFILE_D} already present"
fi

# ── Shell rc files (interactive shells) ───────────────────────────────────────
BREW_SHELLENV_LINE="eval \"\$(${BREW_PREFIX}/bin/brew shellenv)\""

for rc_file in "${USER_HOME}/.bashrc" "${USER_HOME}/.zshrc"; do
    if [[ -f "${rc_file}" ]]; then
        if ! grep -qF "brew shellenv" "${rc_file}"; then
            log_info "Adding brew shellenv to ${rc_file}"
            printf '\n# Homebrew (Linuxbrew)\n%s\n' "${BREW_SHELLENV_LINE}" >> "${rc_file}"
        else
            log_info "brew shellenv already in ${rc_file}"
        fi
    fi
done

log_info "Homebrew installation complete"
