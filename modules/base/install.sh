#!/usr/bin/env bash
# modules/base/install.sh - Core system utilities
#
# This is the right place to add apt packages that should be present on every
# instance regardless of profile. Add a package here, and it will be installed
# on every instance that includes the 'base' module in its MODULE_LIST.
#
# DO NOT add language runtimes or developer tools here — use a dedicated module.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${REPO_ROOT}/lib/log.sh"
source "${REPO_ROOT}/lib/net.sh"

log_info "Installing base system utilities"

retry 3 apt-get update -qq
retry 3 apt-get install -y -q \
    curl \
    wget \
    vim \
    git \
    unzip \
    zip \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    procps \
    file \
    jq \
    tree \
    htop

log_info "Base utilities installation complete"
