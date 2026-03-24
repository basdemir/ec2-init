#!/usr/bin/env bash
# modules/base/verify.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"

REQUIRED=(curl wget vim git unzip zip ca-certificates build-essential)

log_info "Verifying base utilities"

FAIL=0
for pkg in "${REQUIRED[@]}"; do
    if dpkg -s "${pkg}" &>/dev/null; then
        log_info "  ${pkg}: OK"
    else
        log_error "  ${pkg}: NOT installed"
        FAIL=1
    fi
done

(( FAIL )) && exit 1
log_info "Base utilities OK"
