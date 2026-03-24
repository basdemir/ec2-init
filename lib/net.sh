#!/usr/bin/env bash
# lib/net.sh - Network helpers: retry, wait, download with verification

# Retry a command up to N times with exponential backoff
retry() {
    local max_attempts="${1}"; shift
    local delay=5
    local attempt=1

    while true; do
        if "$@"; then
            return 0
        fi
        if (( attempt >= max_attempts )); then
            log_error "Command failed after ${max_attempts} attempts: $*"
            return 1
        fi
        log_warn "Attempt ${attempt}/${max_attempts} failed. Retrying in ${delay}s..."
        sleep "${delay}"
        delay=$(( delay * 2 ))
        attempt=$(( attempt + 1 ))
    done
}

# Wait for network connectivity before proceeding
wait_for_network() {
    local host="${1:-8.8.8.8}"
    local max_wait="${2:-120}"
    local elapsed=0

    log_info "Waiting for network connectivity..."
    until ping -c1 -W2 "${host}" &>/dev/null; do
        if (( elapsed >= max_wait )); then
            log_error "Network not available after ${max_wait}s"
            return 1
        fi
        sleep 5
        elapsed=$(( elapsed + 5 ))
    done
    log_info "Network is up (${elapsed}s elapsed)"
}

# Download a file and optionally verify its SHA256 checksum
# Usage: download_verified <url> <dest> [expected_sha256]
download_verified() {
    local url="$1"
    local dest="$2"
    local expected_sha256="${3:-}"

    retry 3 curl -fsSL --retry 3 --retry-delay 5 -o "${dest}" "${url}"

    if [[ -n "${expected_sha256}" ]]; then
        local actual
        actual="$(sha256sum "${dest}" | awk '{print $1}')"
        if [[ "${actual}" != "${expected_sha256}" ]]; then
            log_error "SHA256 mismatch for ${dest}: expected ${expected_sha256}, got ${actual}"
            return 1
        fi
        log_info "SHA256 verified for ${dest}"
    fi
}
