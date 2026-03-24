#!/usr/bin/env bash
# tests/verify-all.sh - Run all module verify steps for a given manifest
#
# Usage (must run as root):
#   verify-all.sh [--manifest <profile>]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

source "${REPO_ROOT}/lib/log.sh"
source "${REPO_ROOT}/lib/idempotency.sh"

_log_init

MANIFEST="full-dev"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest) MANIFEST="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

MANIFEST_FILE="${REPO_ROOT}/manifests/${MANIFEST}.env"
if [[ ! -f "${MANIFEST_FILE}" ]]; then
    log_error "Manifest not found: ${MANIFEST_FILE}"
    exit 1
fi

# shellcheck source=/dev/null
source "${MANIFEST_FILE}"

log_section "Verify all modules | manifest=${MANIFEST}"

PASS=0
FAIL=0
SKIP=0

while IFS= read -r module; do
    [[ -z "${module}" || "${module}" =~ ^[[:space:]]*# ]] && continue
    module="$(echo "${module}" | tr -d '[:space:]')"
    [[ -z "${module}" ]] && continue

    verify_script="${REPO_ROOT}/modules/${module}/verify.sh"

    if [[ ! -f "${verify_script}" ]]; then
        log_warn "  [SKIP] ${module}: no verify.sh"
        SKIP=$(( SKIP + 1 ))
        continue
    fi

    if bash "${verify_script}" 2>&1; then
        log_info "  [PASS] ${module}"
        PASS=$(( PASS + 1 ))
    else
        log_error "  [FAIL] ${module}"
        FAIL=$(( FAIL + 1 ))
    fi
done <<< "${MODULE_LIST}"

log_section "Verify results"
log_info "PASS: ${PASS} | FAIL: ${FAIL} | SKIP: ${SKIP}"

if (( FAIL > 0 )); then
    log_error "One or more verifications failed"
    exit 1
fi

log_info "All verifications passed"
