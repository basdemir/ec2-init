#!/usr/bin/env bash
# modules/python/verify.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"

log_info "Verifying Python 3"

command -v python3 >/dev/null 2>&1 || { log_error "python3 not found"; exit 1; }
command -v pip3    >/dev/null 2>&1 || { log_error "pip3 not found"; exit 1; }

python3 -c "import venv" 2>/dev/null || { log_error "python3-venv not functional"; exit 1; }

PY_VER="$(python3 --version)"
PIP_VER="$(pip3 --version | awk '{print $1, $2}')"
log_info "Python OK: ${PY_VER} | ${PIP_VER}"
