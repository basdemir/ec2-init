# ec2-init

Modular, idempotent EC2 bootstrap system for Ubuntu instances. Runs automatically at first boot via cloud-init.

**Installs:** Docker · zsh · oh-my-zsh · Homebrew (Linuxbrew) · developer tools

---

## Quick start

```bash
# Clone to the standard location
git clone https://github.com/basdemir/ec2-init.git /opt/ec2-init

# Run with a profile
sudo /opt/ec2-init/bin/bootstrap --manifest full-dev
```

Or paste `cloud-init/user-data.yml` as EC2 user data — it clones the repo and runs bootstrap automatically on first boot.

---

## Profiles

| Profile | Modules | Use case |
|---|---|---|
| `minimal` | docker, zsh | Utility / monitoring instances |
| `backend` | + ohmyzsh, brew, devtools (lean) | API servers, CI runners |
| `full-dev` | + full brew toolset | Developer workstations |

Pass `--manifest <name>` to select a profile.

---

## Repository structure

```
bin/
  bootstrap       Main orchestrator
  run-module      Debug: run a single module

lib/
  log.sh          Logging (log_info / log_warn / log_error / log_section)
  idempotency.sh  Marker file helpers (marker_exists / marker_write / marker_clear)
  net.sh          retry(), wait_for_network(), download_verified()
  user.sh         run_as_user() — sudo wrapper for non-root operations
  os.sh           get_distro_codename(), get_distro_id()

modules/
  <name>/
    install.sh    Install logic (runs as root; brew ops use sudo -u ubuntu)
    verify.sh     Post-install verification

manifests/
  minimal.env     }
  backend.env     } Sourced as bash — set MODULE_LIST and per-module variables
  full-dev.env    }

config/
  zshrc           .zshrc template (%%PLACEHOLDER%% substitution)
  docker-daemon.json

cloud-init/
  user-data.yml   Primary cloud-init entry point (recommended)
  user-data.sh    Bash shebang fallback

systemd/
  ec2-bootstrap.service   Optional one-shot retry-on-reboot unit

tests/
  verify-all.sh   Run all verify steps for a manifest
```

---

## How it works

1. cloud-init clones this repo to `/opt/ec2-init` and calls `bin/bootstrap --manifest <profile>`
2. The manifest is sourced as bash — it sets `MODULE_LIST` and per-module variables
3. For each module, bootstrap checks `/var/lib/ec2-init/markers/<module>.done`
   - If the marker exists → skip (idempotent)
   - Otherwise → run `install.sh`, then `verify.sh`, then write the marker
4. Failures are logged but don't abort other modules; exit code accumulates

**Logs:** `/var/log/ec2-init/bootstrap.log` (aggregate) + `/var/log/ec2-init/<module>.log`
**Markers:** `/var/lib/ec2-init/markers/`

---

## Adding a module

1. Create the module directory and scripts:

```bash
mkdir -p modules/mymodule
```

**`modules/mymodule/install.sh`**
```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"
source "${REPO_ROOT}/lib/net.sh"

log_info "Installing mymodule"
# ... your install logic ...
log_info "mymodule installation complete"
```

**`modules/mymodule/verify.sh`**
```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"

log_info "Verifying mymodule"
command -v mytool >/dev/null 2>&1 || { log_error "mytool not found"; exit 1; }
log_info "mymodule OK: $(mytool --version)"
```

2. Make them executable:

```bash
chmod +x modules/mymodule/install.sh modules/mymodule/verify.sh
```

3. Add the module to the relevant manifests:

```bash
# manifests/full-dev.env
MODULE_LIST="
docker
zsh
ohmyzsh
brew
devtools
mymodule       # <-- add here
"

# Optionally add module-specific variables
MYMODULE_VERSION="1.2.3"
```

4. Test it standalone:

```bash
sudo /opt/ec2-init/bin/run-module mymodule
```

---

## Removing a module

1. Remove it from any manifests that include it:

```bash
# manifests/full-dev.env — delete the line
```

2. Delete the module directory:

```bash
rm -rf modules/mymodule
```

3. Clear the marker if the module was previously installed (so a re-run doesn't skip a now-gone module):

```bash
sudo rm -f /var/lib/ec2-init/markers/mymodule.done
```

---

## Adding a manifest (profile)

Create `manifests/<name>.env`:

```bash
# manifests/staging.env
BOOTSTRAP_USER="ubuntu"
BREW_PREFIX="/home/linuxbrew/.linuxbrew"

MODULE_LIST="
docker
zsh
"

DOCKER_VERSION=""
ZSH_SET_DEFAULT_SHELL="true"
```

Run it with:

```bash
sudo /opt/ec2-init/bin/bootstrap --manifest staging
```

---

## Re-running / forcing reinstall

```bash
# Re-run a single module (clears its marker first)
sudo rm /var/lib/ec2-init/markers/devtools.done
sudo /opt/ec2-init/bin/bootstrap --manifest full-dev

# Force ALL modules to re-run (ignores all markers)
sudo /opt/ec2-init/bin/bootstrap --manifest full-dev --force

# Run and verify a single module interactively
sudo /opt/ec2-init/bin/run-module brew both
sudo /opt/ec2-init/bin/run-module docker verify
```

---

## Debugging

```bash
# Check cloud-init status
cloud-init status --long

# Aggregate bootstrap log
tail -100 /var/log/ec2-init/bootstrap.log

# Per-module log
cat /var/log/ec2-init/brew.log

# Which modules completed successfully
ls /var/lib/ec2-init/markers/

# Run all verify steps
sudo /opt/ec2-init/tests/verify-all.sh --manifest full-dev
```

---

## Manifest variables reference

| Variable | Default | Description |
|---|---|---|
| `BOOTSTRAP_USER` | `ubuntu` | Non-root user for brew/ohmyzsh operations |
| `BREW_PREFIX` | `/home/linuxbrew/.linuxbrew` | Homebrew prefix |
| `MODULE_LIST` | _(required)_ | Newline or space-separated list of modules to run |
| `DOCKER_VERSION` | `""` (latest) | Pin a specific Docker CE version (e.g. `5:29.3.0-1~ubuntu.24.04~noble`) |
| `ZSH_SET_DEFAULT_SHELL` | `true` | Set zsh as default shell for `BOOTSTRAP_USER` |
| `OHMYZSH_THEME` | `bira` | oh-my-zsh theme |
| `OHMYZSH_PLUGINS` | `git` | Space-separated oh-my-zsh plugins |
| `BREW_PACKAGES` | _(lean set)_ | Space-separated list of brew formulae |
| `BREW_INSTALL_SHA256` | `""` | Pin the Homebrew installer by SHA256 (leave empty for latest) |

---

## Security notes

- Docker GPG key is downloaded to `/etc/apt/keyrings/docker.asc` and pinned via `Signed-By:` — not piped to `apt-key`
- The Homebrew installer is downloaded to `/tmp` first and then executed — not piped directly to bash
- Homebrew always runs as `${BOOTSTRAP_USER}` — never as root
- Never put secrets in cloud-init user data (readable via EC2 metadata endpoint). Use SSM Parameter Store or Secrets Manager instead

---

## Evolution path

| Stage | Approach |
|---|---|
| **Now** | Bootstrap from GitHub on first boot (~10 min cold start) |
| **S3-hosted** | `aws s3 cp s3://bucket/ec2-init.tar.gz` — removes GitHub dependency for private VPCs |
| **Packer AMI** | Run `bin/bootstrap` inside a Packer build; markers are pre-written; boot time drops to ~30s |
| **CI validation** | `bash -n` + `shellcheck` on every PR; `packer validate` for AMI builds |
