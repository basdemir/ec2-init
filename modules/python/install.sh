#!/usr/bin/env bash
# modules/python/install.sh - Install Python 3 with pip and venv
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/lib/log.sh"
source "${REPO_ROOT}/lib/net.sh"

PYTHON_EXTRA_PACKAGES="${PYTHON_EXTRA_PACKAGES:-}"

log_info "Starting Python 3 installation"

retry 3 apt-get update -qq
retry 3 apt-get install -y -q \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools \
    python3-wheel

# ── pip config: disable version nag, use --break-system-packages on Ubuntu 24+ ─
# Ubuntu 24.04 uses PEP 668 (externally managed env), so system pip needs the flag.
# For user installs (pipx pattern) this is not needed — but system pip still works.
PIP_CONF="/etc/pip.conf"
if [[ ! -f "${PIP_CONF}" ]]; then
    log_info "Writing ${PIP_CONF}"
    cat > "${PIP_CONF}" <<'EOF'
[global]
break-system-packages = true
EOF
fi

# ── Optional extra packages ───────────────────────────────────────────────────
if [[ -n "${PYTHON_EXTRA_PACKAGES}" ]]; then
    log_info "Installing extra pip packages: ${PYTHON_EXTRA_PACKAGES}"
    # shellcheck disable=SC2086
    retry 3 pip3 install --quiet ${PYTHON_EXTRA_PACKAGES}
fi

log_info "Python 3 installation complete ($(python3 --version))"
