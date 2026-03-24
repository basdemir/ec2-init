#!/usr/bin/env bash
# EC2 Bootstrap — bash user-data fallback
#
# Use this instead of user-data.yml when:
#   - You need to inject runtime secrets (never put them in the YAML form)
#   - The cloud-init YAML parser is unavailable or restricted
#   - You want the simplest possible user-data for quick tests
#
# Output from this script goes to /var/log/cloud-init-output.log automatically.
set -euo pipefail

REPO_URL="https://github.com/basdemir/ec2-init.git"
REPO_BRANCH="main"
MANIFEST="full-dev"   # ← change this before launching: minimal | backend | full-dev
INSTALL_DIR="/opt/ec2-init"

# ── Ensure core dependencies ──────────────────────────────────────────────────
apt-get update -qq
apt-get install -y -q git curl

# ── Clone or update the bootstrap repo ───────────────────────────────────────
if [[ -d "${INSTALL_DIR}/.git" ]]; then
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] Updating ec2-init repo"
    git -C "${INSTALL_DIR}" fetch --quiet origin "${REPO_BRANCH}"
    git -C "${INSTALL_DIR}" reset --hard "origin/${REPO_BRANCH}"
else
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] Cloning ec2-init repo"
    git clone --depth 1 --branch "${REPO_BRANCH}" "${REPO_URL}" "${INSTALL_DIR}"
fi

chmod +x "${INSTALL_DIR}/bin/bootstrap" "${INSTALL_DIR}/bin/run-module"

# ── Hand off to the bootstrap orchestrator ────────────────────────────────────
echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] Starting bootstrap (manifest=${MANIFEST})"
exec "${INSTALL_DIR}/bin/bootstrap" --manifest "${MANIFEST}"
