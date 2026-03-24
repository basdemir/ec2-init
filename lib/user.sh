#!/usr/bin/env bash
# lib/user.sh - User context helpers

# Run a command as a specific user, preserving a clean login-like environment
# Usage: run_as_user <username> <cmd> [args...]
run_as_user() {
    local user="$1"; shift
    sudo -u "${user}" -i "$@"
}

# Run a command as a specific user with additional env vars
# Usage: run_as_user_env <username> VAR=val ... -- <cmd> [args...]
run_as_user_env() {
    local user="$1"; shift
    local -a env_vars=()

    while [[ "$1" != "--" ]]; do
        env_vars+=("$1")
        shift
    done
    shift  # consume '--'

    sudo -u "${user}" env "${env_vars[@]}" -i "$@"
}

# Assert the script is running as root; exit if not
require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "[ERROR] This script must be run as root" >&2
        exit 1
    fi
}

# Get the home directory of a user
user_home() {
    local user="$1"
    getent passwd "${user}" | cut -d: -f6
}
