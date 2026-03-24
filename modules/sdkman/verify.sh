#!/usr/bin/env bash
# modules/sdkman/verify.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"

BREW_USER="${BOOTSTRAP_USER:-ubuntu}"
USER_HOME="/home/${BREW_USER}"
SDKMAN_DIR="${USER_HOME}/.sdkman"
SDKMAN_JAVA_VERSION="${SDKMAN_JAVA_VERSION:-25-tem}"

log_info "Verifying SDKMAN"

# 1. SDKMAN init script exists
[[ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]] || {
    log_error "SDKMAN not found at ${SDKMAN_DIR}"
    exit 1
}

# 2. Java is installed and the version is set as default
JAVA_BIN="$(sudo -u "${BREW_USER}" HOME="${USER_HOME}" bash -c "
    export SDKMAN_DIR=\"${SDKMAN_DIR}\"
    source \"${SDKMAN_DIR}/bin/sdkman-init.sh\"
    command -v java 2>/dev/null
")"

[[ -n "${JAVA_BIN}" ]] || { log_error "java not found in SDKMAN environment"; exit 1; }

JAVA_VER="$(sudo -u "${BREW_USER}" HOME="${USER_HOME}" bash -c "
    export SDKMAN_DIR=\"${SDKMAN_DIR}\"
    source \"${SDKMAN_DIR}/bin/sdkman-init.sh\"
    java -version 2>&1 | head -1
")"

SDKMAN_VER="$(sudo -u "${BREW_USER}" HOME="${USER_HOME}" bash -c "
    export SDKMAN_DIR=\"${SDKMAN_DIR}\"
    source \"${SDKMAN_DIR}/bin/sdkman-init.sh\"
    sdk version 2>/dev/null | head -1
" 2>/dev/null || echo 'unknown')"

log_info "SDKMAN OK: ${SDKMAN_VER} | Java: ${JAVA_VER}"
