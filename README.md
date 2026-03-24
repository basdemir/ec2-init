# ec2-init

Modular, idempotent EC2 bootstrap system for Ubuntu instances. Triggered automatically at first boot via cloud-init — no manual steps required after launch.

---

## What gets installed

| Module | What it installs | How |
|---|---|---|
| `base` | curl, wget, vim, git, zip, build-essential, jq, htop, tree… | apt |
| `docker` | Docker CE, docker-compose-plugin, docker-buildx-plugin | apt (official repo) |
| `python` | python3, pip, venv, dev headers | apt |
| `zsh` | zsh, set as default shell | apt |
| `ohmyzsh` | oh-my-zsh + custom plugins (zsh-autosuggestions, zsh-syntax-highlighting) | git |
| `brew` | Homebrew (Linuxbrew) at `/home/linuxbrew/.linuxbrew` | official installer |
| `devtools` | fzf, ripgrep, bat, lazygit, git-delta, go, gh… | brew |
| `sdkman` | SDKMAN + Temurin JDK 25 | sdkman installer |
| `nvm` | NVM + Node.js 24 LTS | nvm installer |
| `codex` | OpenAI Codex CLI (`@openai/codex`) | npm |
| `claudecode` | Claude Code CLI | official installer |

---

## Quick start

**Automatic** — paste `cloud-init/user-data.yml` as EC2 user data when launching an instance. The repo is cloned and bootstrap runs on first boot with no further action.

**Manual** — on a running instance:

```bash
git clone https://github.com/basdemir/ec2-init.git /opt/ec2-init
sudo /opt/ec2-init/bin/bootstrap --manifest full-dev
```

---

## Profiles

| Profile | Modules | Use case |
|---|---|---|
| `minimal` | base, docker, zsh | Utility / monitoring instances |
| `backend` | + python, ohmyzsh, brew, devtools, sdkman, nvm | API servers, CI runners |
| `full-dev` | + codex, claudecode | Developer workstations |

Select a profile with `--manifest <name>`.

---

## How it works

```
EC2 launch
  └── cloud-init: install git + curl, create 4 GB swap
        └── clone github.com/basdemir/ec2-init → /opt/ec2-init
              └── bin/bootstrap --manifest full-dev
                    └── for each module in MODULE_LIST:
                          ├── marker exists? → skip
                          ├── run modules/<name>/install.sh
                          ├── run modules/<name>/verify.sh
                          └── write /var/lib/ec2-init/markers/<name>.done
```

- **Idempotent** — marker files prevent re-runs; safe to run twice
- **Non-fatal failures** — a failed module is logged but doesn't abort others
- **User context** — apt/systemctl run as root; brew/nvm/sdkman run as `ubuntu`
- **Logs** — `/var/log/ec2-init/bootstrap.log` (aggregate) + `/var/log/ec2-init/<module>.log`

---

## Repository structure

```
bin/
  bootstrap             Main orchestrator (--manifest, --force)
  run-module            Debug: run a single module standalone

lib/
  log.sh                log_info / log_warn / log_error / log_section
  idempotency.sh        marker_exists / marker_write / marker_clear
  net.sh                retry() / wait_for_network() / download_verified()
  user.sh               run_as_user() — sudo wrapper for non-root ops
  os.sh                 OS/distro detection

modules/
  <name>/
    install.sh          Install logic
    verify.sh           Post-install verification

manifests/
  minimal.env           }
  backend.env           } Sourced as bash — define MODULE_LIST + per-module vars
  full-dev.env          }
  test-container.env    For Docker-based local testing (no docker module)

config/
  zshrc                 .zshrc template (%%PLACEHOLDER%% substitution)
  docker-daemon.json    log-driver, live-restore, overlay2

cloud-init/
  user-data.yml         Primary entry point — thin wrapper, all logic in repo
  user-data.sh          Bash shebang fallback

systemd/
  ec2-bootstrap.service One-shot retry-on-reboot unit (optional)

tests/
  verify-all.sh         Run all verify.sh steps for a manifest
  test-in-docker.sh     Clean-room install test inside a fresh Ubuntu container
```

---

## Adding packages

### apt package → `modules/base/install.sh`

```bash
retry 3 apt-get install -y -q \
    ...
    your-package        # ← add here
```

### brew formula → `manifests/*.env`

```bash
BREW_PACKAGES="fzf ripgrep bat ... your-formula"   # ← add here
```

---

## Adding a module

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
# ... install logic ...
log_info "mymodule complete"
```

**`modules/mymodule/verify.sh`**
```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/lib/log.sh"

command -v mytool >/dev/null 2>&1 || { log_error "mytool not found"; exit 1; }
log_info "mymodule OK: $(mytool --version)"
```

```bash
chmod +x modules/mymodule/install.sh modules/mymodule/verify.sh
```

Then add `mymodule` to `MODULE_LIST` in the relevant manifests, and optionally add module-specific variables:

```bash
# manifests/full-dev.env
MODULE_LIST="
...
mymodule
"
MYMODULE_VERSION="1.2.3"
```

---

## Removing a module

```bash
# 1. Remove from manifests
# 2. Delete module directory
rm -rf modules/mymodule

# 3. Clear the marker on any already-provisioned instances
sudo rm -f /var/lib/ec2-init/markers/mymodule.done
```

---

## Re-running / forcing reinstall

```bash
# Re-run one module
sudo rm /var/lib/ec2-init/markers/devtools.done
sudo /opt/ec2-init/bin/bootstrap --manifest full-dev

# Force ALL modules (ignore all markers)
sudo /opt/ec2-init/bin/bootstrap --manifest full-dev --force

# Run a single module interactively
sudo /opt/ec2-init/bin/run-module brew install
sudo /opt/ec2-init/bin/run-module docker verify
```

---

## Testing

### Static analysis
```bash
sudo apt-get install -y shellcheck
shellcheck bin/bootstrap bin/run-module lib/*.sh modules/*/install.sh modules/*/verify.sh
```

### Idempotency — on this machine
```bash
# Verify current state
sudo bash tests/verify-all.sh --manifest full-dev

# Full run (all modules already marked → should skip everything)
sudo /opt/ec2-init/bin/bootstrap --manifest full-dev
```

### Clean-room — Docker container
Simulates a first-boot install in a fresh Ubuntu 24.04 container (excludes the `docker` module which requires systemd):

```bash
sudo bash tests/test-in-docker.sh
# or with a specific manifest:
sudo bash tests/test-in-docker.sh --manifest test-container
```

---

## Debugging

```bash
# Cloud-init status
cloud-init status --long

# Aggregate bootstrap log
tail -100 /var/log/ec2-init/bootstrap.log

# Per-module log
cat /var/log/ec2-init/brew.log

# Which modules completed
ls /var/lib/ec2-init/markers/

# Run all verify steps
sudo bash /opt/ec2-init/tests/verify-all.sh --manifest full-dev
```

---

## Manifest variables reference

| Variable | Default | Description |
|---|---|---|
| `BOOTSTRAP_USER` | `ubuntu` | Non-root user for brew / nvm / sdkman operations |
| `BREW_PREFIX` | `/home/linuxbrew/.linuxbrew` | Homebrew install prefix |
| `MODULE_LIST` | _(required)_ | Newline/space-separated list of modules to run |
| `DOCKER_VERSION` | `""` (latest) | Pin Docker CE version e.g. `5:29.3.0-1~ubuntu.24.04~noble` |
| `ZSH_SET_DEFAULT_SHELL` | `true` | Set zsh as default shell for `BOOTSTRAP_USER` |
| `OHMYZSH_THEME` | `bira` | oh-my-zsh theme |
| `OHMYZSH_PLUGINS` | `git` | Space-separated plugin list; custom plugins are git-cloned automatically |
| `BREW_PACKAGES` | _(see manifest)_ | Space-separated brew formulae |
| `BREW_INSTALL_SHA256` | `""` | Pin Homebrew installer SHA256 for reproducible builds |
| `PYTHON_EXTRA_PACKAGES` | `""` | Extra pip packages to install system-wide |
| `SDKMAN_JAVA_VERSION` | `25-tem` | Temurin JDK version; run `sdk list java` for identifiers |
| `NVM_VERSION` | `v0.40.1` | NVM installer version |
| `NODE_VERSION` | `24` | Node.js major version; nvm resolves to latest patch |

---

## Security notes

- Docker GPG key is fetched over HTTPS to `/etc/apt/keyrings/docker.asc` with `Signed-By:` pinning — no `apt-key add`, no `curl | bash`
- Homebrew, NVM, SDKMAN, and Claude Code installers are downloaded to `/tmp` first, then executed — never piped directly to bash
- Homebrew, NVM, SDKMAN, and npm always run as `${BOOTSTRAP_USER}` — never as root
- Never put secrets in cloud-init user data — it is readable via the EC2 metadata endpoint (`169.254.169.254`). Use SSM Parameter Store or Secrets Manager

---

## Evolution path

| Stage | What changes |
|---|---|
| **Now** | Clone from GitHub on first boot (~10–15 min cold start) |
| **S3-hosted** | `aws s3 cp s3://bucket/ec2-init.tar.gz` — no GitHub dependency, works in private VPCs |
| **Packer AMI** | Run `bin/bootstrap` inside Packer; markers pre-written; boot time ~30 s |
| **CI validation** | `shellcheck` + `bash -n` on every PR; `packer validate` for AMI pipeline |
| **Multi-env** | `manifests/prod.env` strips dev tools; `manifests/ci-runner.env` installs only Docker + Go |
