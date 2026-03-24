#!/usr/bin/env bash
# modules/docker/verify.sh - Verify Docker installation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"

DOCKER_USER="${BOOTSTRAP_USER:-ubuntu}"

log_info "Verifying Docker installation"

# 1. Binary in PATH
command -v docker >/dev/null 2>&1 || { log_error "docker binary not found in PATH"; exit 1; }

# 2. Daemon is running
systemctl is-active --quiet docker || { log_error "Docker service not active"; exit 1; }

# 3. CLI can talk to daemon
docker version --format '{{.Server.Version}}' >/dev/null 2>&1 || {
    log_error "docker version failed — daemon may not be reachable"
    exit 1
}

# 4. compose plugin present
docker compose version >/dev/null 2>&1 || { log_error "docker compose plugin not found"; exit 1; }

# 5. buildx plugin present
docker buildx version >/dev/null 2>&1 || { log_error "docker buildx plugin not found"; exit 1; }

# 6. User is in docker group
if id "${DOCKER_USER}" &>/dev/null; then
    groups "${DOCKER_USER}" | grep -q '\bdocker\b' || \
        log_warn "${DOCKER_USER} is not yet in docker group (may need re-login)"
fi

DOCKER_VER="$(docker version --format '{{.Server.Version}}')"
COMPOSE_VER="$(docker compose version --short 2>/dev/null || docker compose version | grep -oP 'v[\d.]+')"
log_info "Docker OK: engine=${DOCKER_VER} compose=${COMPOSE_VER} service=active"
