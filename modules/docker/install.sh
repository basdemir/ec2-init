#!/usr/bin/env bash
# modules/docker/install.sh - Install Docker CE from official apt repo
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/lib/log.sh"
source "${REPO_ROOT}/lib/net.sh"
source "${REPO_ROOT}/lib/os.sh"

# Defaults (overridden by manifest)
DOCKER_VERSION="${DOCKER_VERSION:-}"       # empty = latest stable
DOCKER_USER="${BOOTSTRAP_USER:-ubuntu}"

KEYRING_DIR="/etc/apt/keyrings"
KEYRING_FILE="${KEYRING_DIR}/docker.asc"
SOURCES_FILE="/etc/apt/sources.list.d/docker.sources"

log_info "Starting Docker installation"

# ── Detect distro (source /etc/os-release directly, matches official Docker docs)
# shellcheck source=/dev/null
source /etc/os-release
DISTRO_ID="${ID}"                                        # ubuntu / debian
DISTRO_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME}}"
log_info "Detected: ${DISTRO_ID} ${DISTRO_CODENAME}"

# ── Prerequisites ─────────────────────────────────────────────────────────────
log_info "Installing apt prerequisites"
retry 3 apt-get update -qq
retry 3 apt-get install -y -q \
    ca-certificates \
    curl

# ── Docker GPG key (not curl|bash, not apt-key add) ───────────────────────────
install -m 0755 -d "${KEYRING_DIR}"

if [[ ! -f "${KEYRING_FILE}" ]]; then
    log_info "Downloading Docker GPG key"
    retry 3 curl -fsSL \
        "https://download.docker.com/linux/${DISTRO_ID}/gpg" \
        -o "${KEYRING_FILE}"
    chmod a+r "${KEYRING_FILE}"
    log_info "GPG key installed: ${KEYRING_FILE}"
else
    log_info "Docker GPG key already present"
fi

# ── Apt source (DEB822 format - preferred on Ubuntu 24.04+) ───────────────────
if [[ ! -f "${SOURCES_FILE}" ]]; then
    log_info "Writing Docker apt source (DEB822)"
    cat > "${SOURCES_FILE}" <<EOF
Types: deb
URIs: https://download.docker.com/linux/${DISTRO_ID}
Suites: ${DISTRO_CODENAME}
Components: stable
Signed-By: ${KEYRING_FILE}
EOF
    log_info "Apt source written: ${SOURCES_FILE}"
else
    log_info "Docker apt source already configured"
fi

# ── Install Docker ────────────────────────────────────────────────────────────
log_info "Updating apt cache"
retry 3 apt-get update -qq

if [[ -n "${DOCKER_VERSION}" ]]; then
    log_info "Installing Docker version: ${DOCKER_VERSION}"
    PACKAGES=(
        "docker-ce=${DOCKER_VERSION}"
        "docker-ce-cli=${DOCKER_VERSION}"
        "containerd.io"
        "docker-buildx-plugin"
        "docker-compose-plugin"
    )
else
    log_info "Installing Docker (latest stable)"
    PACKAGES=(
        docker-ce
        docker-ce-cli
        containerd.io
        docker-buildx-plugin
        docker-compose-plugin
    )
fi

retry 3 apt-get install -y -q "${PACKAGES[@]}"

# ── daemon.json ───────────────────────────────────────────────────────────────
DAEMON_JSON_SRC="${REPO_ROOT}/config/docker-daemon.json"
if [[ -f "${DAEMON_JSON_SRC}" && ! -f /etc/docker/daemon.json ]]; then
    mkdir -p /etc/docker
    cp "${DAEMON_JSON_SRC}" /etc/docker/daemon.json
    log_info "Deployed /etc/docker/daemon.json"
elif [[ -f /etc/docker/daemon.json ]]; then
    log_info "/etc/docker/daemon.json already present (not overwriting)"
fi

# ── Enable and start service ──────────────────────────────────────────────────
log_info "Enabling Docker service"
systemctl enable docker
systemctl start docker

# ── Add user to docker group ──────────────────────────────────────────────────
if id "${DOCKER_USER}" &>/dev/null; then
    if ! groups "${DOCKER_USER}" | grep -q '\bdocker\b'; then
        log_info "Adding ${DOCKER_USER} to docker group"
        usermod -aG docker "${DOCKER_USER}"
    else
        log_info "${DOCKER_USER} already in docker group"
    fi
else
    log_warn "User '${DOCKER_USER}' not found — skipping group assignment"
fi

log_info "Docker installation complete"
