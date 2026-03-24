#!/usr/bin/env bash
# tests/test-in-docker.sh - Run bootstrap inside a fresh Ubuntu container
#
# Usage:
#   tests/test-in-docker.sh [--manifest <profile>] [--image <image>] [--no-cache]
#
# Requirements: Docker must be running on the host.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

MANIFEST="test-container"
IMAGE="ubuntu:24.04"
CONTAINER_NAME="ec2-init-test-$$"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest) MANIFEST="$2"; shift 2 ;;
        --image)    IMAGE="$2";    shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

echo "==================================================="
echo "  ec2-init container test"
echo "  Image    : ${IMAGE}"
echo "  Manifest : ${MANIFEST}"
echo "  Repo     : ${REPO_ROOT}"
echo "==================================================="

# ── Cleanup on exit ───────────────────────────────────────────────────────────
cleanup() {
    echo ""
    echo "--- Cleaning up container ---"
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
}
trap cleanup EXIT

# ── Pull image ────────────────────────────────────────────────────────────────
echo ""
echo "--- Pulling ${IMAGE} ---"
docker pull "${IMAGE}"

# ── Run bootstrap inside container ────────────────────────────────────────────
# Mount the repo read-only so we test exactly what's on disk.
# The container gets a fresh Ubuntu with no pre-installed tools.
echo ""
echo "--- Starting bootstrap (this takes a few minutes on first run) ---"
echo ""

docker run \
    --name "${CONTAINER_NAME}" \
    --rm \
    --volume "${REPO_ROOT}:/opt/ec2-init:ro" \
    --env "DEBIAN_FRONTEND=noninteractive" \
    "${IMAGE}" \
    bash -c "
        set -euo pipefail

        # Create the test user (matches BOOTSTRAP_USER in test-container.env)
        useradd -m -s /bin/bash testuser 2>/dev/null || true

        # Run bootstrap
        bash /opt/ec2-init/bin/bootstrap --manifest ${MANIFEST}

        echo ''
        echo '--- Verify step ---'
        bash /opt/ec2-init/tests/verify-all.sh --manifest ${MANIFEST}

        echo ''
        echo '--- Installed markers ---'
        ls /var/lib/ec2-init/markers/ 2>/dev/null || echo 'none'

        echo ''
        echo '--- zsh version ---'
        zsh --version

        echo ''
        echo '--- brew version ---'
        sudo -u testuser /home/linuxbrew/.linuxbrew/bin/brew --version

        echo ''
        echo '--- Installed formulae ---'
        sudo -u testuser /home/linuxbrew/.linuxbrew/bin/brew list --formula
    "

EXIT=$?

echo ""
if [[ "${EXIT}" -eq 0 ]]; then
    echo "==================================================="
    echo "  PASS — bootstrap completed successfully"
    echo "==================================================="
else
    echo "==================================================="
    echo "  FAIL — bootstrap exited with code ${EXIT}"
    echo "==================================================="
fi

exit "${EXIT}"
