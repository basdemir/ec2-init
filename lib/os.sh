#!/usr/bin/env bash
# lib/os.sh - OS and distro detection helpers

# Get the Ubuntu/Debian codename (e.g. "noble", "jammy")
get_distro_codename() {
    lsb_release -cs 2>/dev/null || \
        grep -oP '(?<=UBUNTU_CODENAME=)\S+' /etc/os-release 2>/dev/null || \
        grep -oP '(?<=VERSION_CODENAME=)\S+' /etc/os-release 2>/dev/null
}

# Get the distro ID in lowercase (e.g. "ubuntu", "debian")
get_distro_id() {
    lsb_release -is 2>/dev/null | tr '[:upper:]' '[:lower:]' || \
        grep -oP '(?<=^ID=)\S+' /etc/os-release 2>/dev/null | tr -d '"'
}

# Get the full OS version string
get_os_version() {
    lsb_release -rs 2>/dev/null || \
        grep -oP '(?<=VERSION_ID=)\S+' /etc/os-release 2>/dev/null | tr -d '"'
}

# Returns true if running on Ubuntu
is_ubuntu() {
    [[ "$(get_distro_id)" == "ubuntu" ]]
}

# Returns true if running on Debian
is_debian() {
    [[ "$(get_distro_id)" == "debian" ]]
}
