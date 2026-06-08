# Deploy ECC to a VPS

`vps-setup.sh` provisions a fresh Linux box (Ubuntu 22.04+, Debian-family) with
everything needed to run Everything Claude Code: system prerequisites, swap for
small-RAM hosts, Node.js, an ECC clone, and the ECC surfaces applied into
`~/.claude` via the OSS installer. It is idempotent, so re-running it pulls the
latest ECC and re-applies cleanly.

## One-liner

On the VPS (as root, or a sudo user):

```bash
curl -fsSL https://raw.githubusercontent.com/jpjump11/ECC/main/deploy/vps-setup.sh | bash
```

Or clone first if you prefer to read before running:

```bash
git clone https://github.com/jpjump11/ECC.git
bash ECC/deploy/vps-setup.sh
```

## What it does

1. Installs `git`, `curl`, `python3`, and build tools.
2. Adds a swap file (default 2G) when the host has none. A 1 GB box will OOM
   during install without it.
3. Installs Node.js 22 (skips if Node >= 18 is already present).
4. Clones (or fast-forwards) ECC.
5. Runs `npm install --omit=dev` (best-effort; the installer itself is plain Node).
6. Shows the install plan as a dry run, then applies the profile to the target.
7. Optionally installs the Claude Code CLI.
8. Verifies with `node scripts/ecc.js doctor` and `list-installed`.

## Configuration

All knobs are environment variables, so nothing sensitive lives in the script:

| Variable | Default | Notes |
|---|---|---|
| `ECC_REPO` | `https://github.com/jpjump11/ECC.git` | Point at upstream or another fork. |
| `ECC_BRANCH` | `main` | Branch to deploy. |
| `ECC_DIR` | `$HOME/ECC` | Clone destination. |
| `ECC_PROFILE` | `full` | One of: `minimal` `core` `developer` `security` `research` `full` `opencode`. |
| `ECC_TARGET` | `claude` | Install target (`claude`, `claude-project`, `codex`, `opencode`, `zed`, ...). |
| `SWAP_SIZE` | `2G` | Set `0` to skip swap creation. |
| `INSTALL_CLAUDE_CODE` | `0` | Set `1` to also install the Claude Code CLI globally. |

Example — a lean install of just the core profile, plus the Claude Code CLI:

```bash
ECC_PROFILE=core INSTALL_CLAUDE_CODE=1 bash ECC/deploy/vps-setup.sh
```

## Secrets stay manual (by design)

This script reads and writes no credentials. Two things remain your manual step:

- **Claude Code auth.** If you install the CLI, authenticate it separately with
  your API key or login. The provisioner never touches your keys.
- **Any downstream job secrets** (for example a trading bot's `PRIVATE_KEY`)
  belong in the service's own environment, never in this repo or this script.

## Re-running and health checks

Re-run the script any time to update ECC and re-apply. To check health later
without a full re-run:

```bash
node ~/ECC/scripts/ecc.js doctor
node ~/ECC/scripts/ecc.js list-installed
node ~/ECC/scripts/ecc.js repair   # if doctor flags missing managed files
```

## Note on install methods

Do not stack the Claude Code plugin install and this OSS installer on the same
profile, that duplicates skills and hooks. On a headless VPS the OSS installer
path here is the reliable choice; reach for the plugin marketplace only on a
desktop Claude Code build.
