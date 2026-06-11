#!/usr/bin/env bash
#
# ECC VPS provisioner — installs Everything Claude Code onto a fresh Linux box.
#
# Target: Ubuntu 22.04+ (Debian-family). Idempotent: safe to re-run. It installs
# prerequisites, adds swap for small-RAM boxes, installs Node, clones ECC, and
# applies the ECC surfaces into ~/.claude via the OSS installer.
#
# Usage (on the VPS):
#   curl -fsSL https://raw.githubusercontent.com/jpjump11/ECC/main/deploy/vps-setup.sh | bash
# or:
#   git clone https://github.com/jpjump11/ECC.git && bash ECC/deploy/vps-setup.sh
#
# Overridable via environment:
#   ECC_REPO            git URL to clone           (default: https://github.com/jpjump11/ECC.git)
#   ECC_BRANCH          branch to check out        (default: main)
#   ECC_DIR             clone destination          (default: $HOME/ECC)
#   ECC_PROFILE         install profile            (default: full)
#                       one of: minimal core developer security research full opencode
#   ECC_TARGET          install target             (default: claude)
#   SWAP_SIZE           swap file size             (default: 2G; set 0 to skip)
#   INSTALL_CLAUDE_CODE install the Claude Code CLI (default: 0; set 1 to install)
#
# No secrets are read or written by this script. Authenticating Claude Code (API
# key / login) and any PRIVATE_KEY for downstream jobs remain your manual step.

set -euo pipefail

ECC_REPO="${ECC_REPO:-https://github.com/jpjump11/ECC.git}"
ECC_BRANCH="${ECC_BRANCH:-main}"
ECC_DIR="${ECC_DIR:-$HOME/ECC}"
ECC_PROFILE="${ECC_PROFILE:-full}"
ECC_TARGET="${ECC_TARGET:-claude}"
SWAP_SIZE="${SWAP_SIZE:-2G}"
INSTALL_CLAUDE_CODE="${INSTALL_CLAUDE_CODE:-0}"
NODE_MAJOR="${NODE_MAJOR:-22}"

log() { printf '\n[ecc-vps] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# Run a privileged command as root directly, or via sudo when available.
as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    log "ERROR: need root (or sudo) for: $*"
    exit 1
  fi
}

# ── 1. System prerequisites ────────────────────────────────────────────────
log "Installing system prerequisites"
export DEBIAN_FRONTEND=noninteractive
as_root apt-get update -y
as_root apt-get install -y git curl ca-certificates python3 build-essential

# ── 2. Swap (small-RAM boxes OOM during npm/node otherwise) ─────────────────
if [ "$SWAP_SIZE" != "0" ]; then
  if [ "$(swapon --show --noheadings | wc -l)" -eq 0 ] && [ ! -f /swapfile ]; then
    log "Creating ${SWAP_SIZE} swap file"
    as_root fallocate -l "$SWAP_SIZE" /swapfile || as_root dd if=/dev/zero of=/swapfile bs=1M count=2048
    as_root chmod 600 /swapfile
    as_root mkswap /swapfile
    as_root swapon /swapfile
    if ! grep -q '^/swapfile' /etc/fstab; then
      echo '/swapfile none swap sw 0 0' | as_root tee -a /etc/fstab >/dev/null
    fi
  else
    log "Swap already present — skipping"
  fi
fi

# ── 3. Node.js ─────────────────────────────────────────────────────────────
NODE_OK=0
if have node; then
  CURRENT="$(node -v | sed 's/v//; s/\..*//')"
  [ "$CURRENT" -ge 18 ] 2>/dev/null && NODE_OK=1
fi
if [ "$NODE_OK" -eq 1 ]; then
  log "Node $(node -v) already satisfies >=18 — skipping"
else
  log "Installing Node.js ${NODE_MAJOR}.x"
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | as_root -E bash -
  as_root apt-get install -y nodejs
fi

# ── 4. Clone or update ECC ─────────────────────────────────────────────────
if [ -d "$ECC_DIR/.git" ]; then
  log "Updating existing ECC clone at $ECC_DIR"
  git -C "$ECC_DIR" fetch --depth 1 origin "$ECC_BRANCH"
  git -C "$ECC_DIR" checkout "$ECC_BRANCH"
  git -C "$ECC_DIR" reset --hard "origin/$ECC_BRANCH"
else
  log "Cloning $ECC_REPO ($ECC_BRANCH) into $ECC_DIR"
  git clone --depth 1 --branch "$ECC_BRANCH" "$ECC_REPO" "$ECC_DIR"
fi

# ── 5. Install repo dependencies (best-effort; the installer is pure Node) ──
log "Installing ECC dependencies"
( cd "$ECC_DIR" && npm install --omit=dev --no-audit --no-fund ) || \
  log "npm install reported issues — the OSS installer still runs on plain Node"

# ── 6. Apply ECC surfaces into the Claude config ───────────────────────────
log "Install plan (dry run):"
( cd "$ECC_DIR" && node scripts/install-apply.js --profile "$ECC_PROFILE" --target "$ECC_TARGET" --dry-run ) || true

log "Applying profile '$ECC_PROFILE' to target '$ECC_TARGET'"
( cd "$ECC_DIR" && node scripts/install-apply.js --profile "$ECC_PROFILE" --target "$ECC_TARGET" )

# ── 7. Optional: Claude Code CLI ───────────────────────────────────────────
if [ "$INSTALL_CLAUDE_CODE" = "1" ]; then
  log "Installing the Claude Code CLI globally"
  as_root npm install -g @anthropic-ai/claude-code || \
    log "Claude Code CLI install failed — install it manually if you need the agent on this box"
fi

# ── 8. Verify ──────────────────────────────────────────────────────────────
log "Verifying installation"
( cd "$ECC_DIR" && node scripts/ecc.js doctor ) || true
( cd "$ECC_DIR" && node scripts/ecc.js list-installed ) || true

cat <<'DONE'

[ecc-vps] Done.

Next:
  - ECC surfaces are installed under ~/.claude (profile: this run's ECC_PROFILE).
  - If you set INSTALL_CLAUDE_CODE=1, authenticate Claude Code separately
    (it needs your API key / login). That step is intentionally manual.
  - Re-run this script any time to pull the latest ECC and re-apply.
  - Health check later with:  node ~/ECC/scripts/ecc.js doctor
DONE
