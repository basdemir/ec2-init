#!/usr/bin/env bash
# lib/idempotency.sh - Marker file management

MARKER_DIR="${MARKER_DIR:-/var/lib/ec2-init/markers}"

marker_exists() {
    local name="$1"
    [[ -f "${MARKER_DIR}/${name}.done" ]]
}

marker_write() {
    local name="$1"
    mkdir -p "${MARKER_DIR}"
    date -u '+%Y-%m-%dT%H:%M:%SZ' > "${MARKER_DIR}/${name}.done"
    log_info "Marker written: ${name}"
}

marker_clear() {
    local name="$1"
    rm -f "${MARKER_DIR}/${name}.done"
    log_info "Marker cleared: ${name}"
}
