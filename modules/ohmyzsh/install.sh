#!/usr/bin/env bash
# modules/ohmyzsh/install.sh - Install oh-my-zsh and deploy .zshrc template
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/lib/log.sh"
source "${REPO_ROOT}/lib/net.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
USER_HOME="/home/${BREW_USER}"
OMZ_DIR="${USER_HOME}/.oh-my-zsh"
OHMYZSH_THEME="${OHMYZSH_THEME:-bira}"
OHMYZSH_PLUGINS="${OHMYZSH_PLUGINS:-git}"
ZSHRC_TEMPLATE="${REPO_ROOT}/config/zshrc"

log_info "Starting oh-my-zsh installation"
log_info "Target user: ${BREW_USER} | Theme: ${OHMYZSH_THEME} | Plugins: ${OHMYZSH_PLUGINS}"

# ── Prerequisites ─────────────────────────────────────────────────────────────
retry 3 apt-get install -y -q git curl

# ── Install oh-my-zsh ─────────────────────────────────────────────────────────
if [[ -d "${OMZ_DIR}" ]]; then
    log_info "oh-my-zsh already installed at ${OMZ_DIR}"
else
    OMZ_SCRIPT="/tmp/ohmyzsh-install.sh"
    log_info "Downloading oh-my-zsh installer"
    retry 3 curl -fsSL \
        "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" \
        -o "${OMZ_SCRIPT}"
    chmod +x "${OMZ_SCRIPT}"

    log_info "Running oh-my-zsh installer as ${BREW_USER}"
    sudo -u "${BREW_USER}" \
        HOME="${USER_HOME}" \
        RUNZSH=no \
        CHSH=no \
        KEEP_ZSHRC=yes \
        bash "${OMZ_SCRIPT}"

    rm -f "${OMZ_SCRIPT}"
    log_info "oh-my-zsh installed at ${OMZ_DIR}"
fi

# ── Custom plugins (git-managed, listed in OHMYZSH_PLUGINS) ──────────────────
# Packages like zsh-autosuggestions and zsh-syntax-highlighting are installed
# here as oh-my-zsh custom plugins rather than brew packages. This keeps all
# .zshrc plugin activation in one place (the plugins=() line in the template)
# and avoids appending stray source lines that would be lost if .zshrc is
# redeployed.
ZSH_CUSTOM="${OMZ_DIR}/custom/plugins"

declare -A _OMZ_CUSTOM_PLUGIN_REPOS=(
    [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions"
    [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting"
    [zsh-completions]="https://github.com/zsh-users/zsh-completions"
)

for plugin in "${!_OMZ_CUSTOM_PLUGIN_REPOS[@]}"; do
    # Only install if the plugin appears in OHMYZSH_PLUGINS
    if echo "${OHMYZSH_PLUGINS}" | grep -qw "${plugin}"; then
        target="${ZSH_CUSTOM}/${plugin}"
        if [[ ! -d "${target}" ]]; then
            log_info "Installing custom plugin: ${plugin}"
            sudo -u "${BREW_USER}" git clone --depth 1 \
                "${_OMZ_CUSTOM_PLUGIN_REPOS[$plugin]}" "${target}"
        else
            log_info "Custom plugin already present: ${plugin}"
        fi
    fi
done

# ── Deploy .zshrc from template ───────────────────────────────────────────────
ZSHRC="${USER_HOME}/.zshrc"

if [[ -f "${ZSHRC_TEMPLATE}" ]]; then
    log_info "Deploying .zshrc from template"
    sed \
        -e "s|%%OMZ_DIR%%|${OMZ_DIR}|g" \
        -e "s|%%ZSH_THEME%%|${OHMYZSH_THEME}|g" \
        -e "s|%%ZSH_PLUGINS%%|${OHMYZSH_PLUGINS}|g" \
        "${ZSHRC_TEMPLATE}" > "${ZSHRC}"
    chown "${BREW_USER}:${BREW_USER}" "${ZSHRC}"
    log_info ".zshrc deployed to ${ZSHRC}"
else
    log_warn "No zshrc template found at ${ZSHRC_TEMPLATE} — skipping .zshrc deployment"
fi

log_info "oh-my-zsh installation complete"
