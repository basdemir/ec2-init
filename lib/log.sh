#!/usr/bin/env bash
# lib/log.sh - Logging primitives

LOG_DIR="${LOG_DIR:-/var/log/ec2-init}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/bootstrap.log}"

_log_init() {
    mkdir -p "${LOG_DIR}"
    touch "${LOG_FILE}"
}

log_info() {
    local msg="[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [INFO]  $*"
    echo "${msg}" | tee -a "${LOG_FILE}"
}

log_warn() {
    local msg="[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [WARN]  $*"
    echo "${msg}" | tee -a "${LOG_FILE}" >&2
}

log_error() {
    local msg="[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [ERROR] $*"
    echo "${msg}" | tee -a "${LOG_FILE}" >&2
}

log_section() {
    log_info "========================================"
    log_info "  $*"
    log_info "========================================"
}
