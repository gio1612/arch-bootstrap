# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

Automated single-command bootstrap for a fresh **Arch Linux WSL2** instance. Running `bootstrap.sh` produces a fully configured dev environment: user account, system packages, AUR helper (yay), Python/Node/Go/Rust toolchains, and dotfiles symlinked via GNU Stow — with SSH auth handled by 1Password.

## Running the bootstrap

```bash
# Full bootstrap (run as root inside WSL2)
sudo bash bootstrap.sh --user gio --dotfiles https://github.com/<user>/dotfiles.git

# Force re-run all phases
sudo bash bootstrap.sh --user gio --dotfiles <url> --force

# Run a single phase directly
sudo bash phases/05-packages.sh
```

Logs: `/var/log/arch-bootstrap.log`

## Architecture

### Phase system

`bootstrap.sh` globs `phases/[0-9]*.sh` and runs them in order. Each phase:
1. Sources `lib/common.sh` for shared utilities
2. Is tracked in `/var/lib/arch-bootstrap/state` (one phase name per line)
3. Is skipped on re-runs if its name already appears in the state file

Adding a new phase only requires dropping a correctly numbered file in `phases/` — no registration needed.

### lib/common.sh

All phases share these utilities:
- `log_info` / `log_warn` / `log_error` / `log_step` — colored output
- `check_root` — exits if not root
- `run_as_user "<cmd>"` — runs a shell command as `$BOOTSTRAP_USER` via `sudo -u`
- `backup_file <path>` — copies a file to `~/.config-backup/<timestamp>/` before overwriting
- `phase_done <name>` / `mark_done <name>` — idempotency state checks
- `check_dns` — writes fallback `/etc/resolv.conf` if DNS resolution fails

### Key phases

| Phase | Notable behavior |
|---|---|
| 01 | Renders `config/wsl.conf.template` by substituting `{{USER}}`, only writes if content changed |
| 06 | Builds yay **from source** (not `paru-bin`) to avoid `libalpm` ABI mismatch |
| 08 | Retrieves SSH private key from 1Password CLI → clones dotfiles → `shred`s the key file; falls back to HTTPS+PAT if `op` is absent |
| 09 | Changes default shell to zsh, bootstraps zinit |

### Customization files

| File | Purpose |
|---|---|
| `config/packages.txt` | pacman packages (one per line, `#` comments ok) |
| `config/aur-packages.txt` | AUR packages installed via yay |
| `config/wsl.conf.template` | Template for `/etc/wsl.conf`; `{{USER}}` is replaced at runtime |

## Shell scripting conventions

- All scripts use `set -euo pipefail`
- Phase scripts must source `lib/common.sh` via `$(dirname "$0")/../lib/common.sh`
- Never run `yay` as root — use `run_as_user`
- `BOOTSTRAP_USER` and `DOTFILES_REPO` are exported environment variables available to all phases
- Idempotency: check with `command -v`, directory/file existence, or `phase_done` before doing work
