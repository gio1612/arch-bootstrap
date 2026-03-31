# arch-bootstrap

Automated setup for a fresh **Arch Linux WSL2** instance.

One command (after a quick user-setup step) takes you from a bare root environment to a fully
configured development machine: system packages, AUR helper, Python/Node/Go/Rust toolchains, and
dotfiles symlinked via GNU Stow — with SSH authentication handled by **1Password**.

---

## What it installs

| Category | Tools |
|---|---|
| Shell | zsh + zinit, starship prompt |
| Editor | Neovim + lazy.nvim (LSP, Treesitter, Telescope) |
| CLI | ripgrep, fd, fzf, bat, eza, htop, tmux |
| Dev toolchains | pyenv (Python), fnm (Node), rustup (Rust), go |
| AUR | yay, 1password-cli, wslu, npiperelay |
| Fonts | JetBrains Mono Nerd Font, Noto Fonts (for WSLg) |

---

## Prerequisites

Complete these steps on **Windows** before touching WSL.

### 1. Install WSL2 and import Arch Linux

Download the latest Arch Linux bootstrap tarball from https://archlinux.org/download and import it
as a WSL2 distro:

```powershell
# In PowerShell (as Administrator)
wsl --install --no-distribution       # Enable WSL2 if not already done
# Reboot if prompted

# Import Arch (adjust paths as needed)
New-Item -ItemType Directory -Path C:\WSL\Arch
wsl --import Arch C:\WSL\Arch C:\Downloads\archlinux-bootstrap-x86_64.tar.zst --version 2
```

### 2. Enable the 1Password SSH agent

In the **1Password desktop app** on Windows:
- Go to **Settings → Developer**
- Enable **"Use the SSH agent"**

This exposes your SSH keys to WSL2 without ever writing key files to disk.

### 3. Install npiperelay

`npiperelay.exe` bridges the 1Password SSH agent (a Windows named pipe) into WSL2.
It must be **accessible from inside WSL** — not just on the Windows PATH.

```powershell
# Option A: WinGet
winget install albertony.npiperelay

# Option B: Scoop
scoop install npiperelay
```

Then confirm the path from inside WSL (you will need this later):

```bash
# WinGet example
ls /mnt/c/Users/<WindowsUser>/AppData/Local/Microsoft/WinGet/Links/npiperelay.exe
```

---

## Quick start

### Step 1 — Enter the new distro as root

```powershell
wsl -d Arch
```

You land as `root` in a minimal Arch environment.

---

### Step 2 — Create your user and configure WSL

Run these commands **as root** inside the new distro. Replace `gio` with your preferred username.

#### 2a. Create the user

```bash
# Create the user with a home directory and wheel group membership
useradd -m -G wheel -s /bin/bash gio

# Set a password
passwd gio
```

#### 2b. Enable passwordless sudo for the wheel group

```bash
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel
```

#### 2c. Write `/etc/wsl.conf`

This file tells WSL2 to start systemd, auto-login as your user, and mount Windows drives
with proper metadata (needed for SSH key permissions).

```bash
cat > /etc/wsl.conf << 'EOF'
[boot]
systemd=true

[user]
default=gio

[automount]
enabled=true
options = "metadata,umask=22,fmask=11"

[interop]
enabled=true
appendWindowsPath=true

[network]
generateHosts=true
generateResolvConf=true
EOF
```

> **Why `metadata` in automount options?**
> Without it, Windows-mounted files always appear as `755/644` and SSH refuses
> private keys because they look world-readable.

> **Why `systemd=true`?**
> The 1Password SSH agent bridge relies on a `systemd` socket unit. Without it,
> the bridge must be started manually every session.

---

### Step 3 — Restart WSL to apply the config

From PowerShell or CMD (not from inside WSL):

```powershell
wsl --shutdown
```

Then relaunch:

```powershell
wsl -d Arch
```

You are now logged in as `gio` (or whichever user you created). Verify:

```bash
whoami    # should print your username, not root
```

---

### Step 4 — Clone and run the bootstrap

#### 4a. Install git (needed to clone the repo)

```bash
sudo pacman -Sy git --noconfirm
```

#### 4b. Clone this repository

```bash
git clone https://github.com/gio1612/arch-bootstrap.git ~/arch-bootstrap
cd ~/arch-bootstrap
```

#### 4c. Run the bootstrap

```bash
sudo bash bootstrap.sh --user "$USER" --dotfiles https://github.com/gio1612/dotfiles.git
```

The bootstrap will:
1. Run **pre-flight checks** — validates Arch Linux, WSL, internet, disk space, and arguments.
   Exits immediately with a clear error if anything is wrong.
2. Configure `/etc/wsl.conf` (idempotent — skipped if already written)
3. Set locale and timezone
4. Ensure your user exists with wheel/sudo access
5. Init the pacman keyring and run a full system upgrade
6. Install all packages from `config/packages.txt`
7. Build and install `yay`, then install all AUR packages from `config/aur-packages.txt`
8. **Verify** every package and key command — reports missing items before continuing
9. Install dev toolchains: pyenv, fnm, rustup, Go workspace
10. Sign in to **1Password CLI**, clone your dotfiles, and stow all configs
11. Set default shell to zsh and bootstrap zinit
12. Fix ownership, clean up, print next steps

> Phase 10 will print an `ACTION REQUIRED` reminder to restart WSL again so that the new
> default shell and systemd changes take full effect.

---

### Step 5 — Set up SSH and 1Password

After the bootstrap completes, 1Password CLI is installed and your dotfiles are stowed.
Now configure SSH authentication.

#### 5a. Sign in to 1Password CLI (if not already done in phase 10)

```bash
op signin
```

#### 5b. Test the SSH agent bridge

The `.zshrc` from your dotfiles starts a `socat` bridge from the 1Password Windows named pipe
to a local socket. Test it:

```bash
ssh -T git@github.com
# Hi gio1612! You've successfully authenticated...
```

If it fails, check:
- `npiperelay.exe` is reachable: `ls /mnt/c/Users/<WindowsUser>/.../npiperelay.exe`
- The path in `.zshrc` matches where it was installed (WinGet, Scoop, or manual)
- 1Password SSH agent is enabled and unlocked (Settings → Developer → Use the SSH agent)
- The socat bridge started: `ls ~/.ssh/agent.sock`
- Restart the bridge manually: `pkill socat; exec zsh`

#### 5c. Machine-specific git config

The dotfiles `.gitconfig` intentionally omits machine-specific settings.
Create `~/.gitconfig.local` on each machine:

```ini
[user]
    signingkey = <your SSH public key from 1Password>

[gpg "ssh"]
    program = /mnt/c/Users/<WindowsUser>/AppData/Local/1Password/app/8/op-ssh-sign-wsl.exe
```

To get the public key from 1Password CLI:

```bash
op read "op://Personal/GitHub SSH Key/public key"
```

---

## Re-running / updating

The bootstrap is **idempotent** — safe to re-run at any time.
Already-completed phases are skipped automatically.

```bash
# Re-run everything from scratch
sudo bash bootstrap.sh --user "$USER" --dotfiles https://github.com/gio1612/dotfiles.git --force

# Re-run a single phase
sudo bash phases/05-packages.sh
```

Logs are written to `/var/log/arch-bootstrap.log`.

---

## Customization

| File | Purpose |
|---|---|
| `config/packages.txt` | pacman packages to install (one per line, `#` comments ok) |
| `config/aur-packages.txt` | AUR packages installed via yay |
| `config/wsl.conf.template` | Template for `/etc/wsl.conf` (`{{USER}}` is substituted by phase 01) |

---

## Phase reference

| Phase | What it does |
|---|---|
| 01 | Render `config/wsl.conf.template` → `/etc/wsl.conf` (only writes if changed) |
| 02 | Generate locale (`en_US.UTF-8`), detect and set timezone |
| 03 | Create user, add to wheel group, configure sudo, set password |
| 04 | Init pacman keyring, install sudo if missing, full system upgrade |
| 05 | Install packages from `config/packages.txt` |
| 06 | Build `yay` from source (avoids libalpm ABI mismatch), install AUR packages |
| 06b | **Verify** every package and key command; warns on failures, does not block |
| 07 | Install pyenv, fnm, rustup; create Go workspace |
| 08 | Sign in to 1Password CLI → clone dotfiles → `stow` all packages → shred temp key |
| 09 | Set default shell to zsh, bootstrap zinit |
| 10 | Fix home-dir ownership, clean up temp files, print summary and next steps |
