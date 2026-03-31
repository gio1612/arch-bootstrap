# arch-bootstrap

Automated setup for a fresh **Arch Linux WSL2** instance.

One command takes you from a bare root environment to a fully configured development machine:
user account, system packages, AUR helper, Python/Node/Go/Rust toolchains, and dotfiles
symlinked via GNU Stow — with SSH authentication handled by **1Password**.

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

Download the latest Arch Linux bootstrap tarball from https://archlinux.org/download
and import it as a WSL2 distro:

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

### 3. Install npiperelay on Windows

`npiperelay.exe` bridges the 1Password SSH agent (a Windows named pipe) into WSL2.

Download the latest release from https://github.com/jstarks/npiperelay/releases
and place `npiperelay.exe` somewhere on your Windows `PATH`
(e.g. `C:\Windows\System32\` or `C:\Users\<you>\bin\`).

---

## Quick start

### Step 1 — Enter the new distro as root

```powershell
wsl -d Arch
```

### Step 2 — Clone and run the bootstrap

No SSH yet, so clone via HTTPS:

```bash
pacman -Sy git --noconfirm
git clone https://github.com/gio1612/arch-bootstrap.git /tmp/arch-bootstrap
cd /tmp/arch-bootstrap
```

Run the bootstrap as root, passing your dotfiles repo URL:

```bash
bash bootstrap.sh --user gio --dotfiles https://github.com/gio1612/dotfiles.git
```

> During **phase 08** (dotfiles), the script will install `1password-cli` and prompt you
> to sign in. It retrieves your GitHub SSH key from 1Password, clones the dotfiles repo,
> stows all configs, then **shreds the key file**. After the reboot, 1Password's SSH agent
> handles all authentication permanently.

### Step 3 — Restart WSL2

From PowerShell or CMD:

```powershell
wsl --shutdown
```

Then relaunch:

```powershell
wsl -d Arch
```

You will land as `gio` in **zsh** with your full environment ready.

---

## Step 4 — Machine-specific git config

The dotfiles `.gitconfig` intentionally omits machine-specific settings.
Create `~/.gitconfig.local` on each machine:

```ini
[user]
    signingkey = <your SSH public key from 1Password>

[gpg "ssh"]
    program = /mnt/c/Users/<WindowsUser>/AppData/Local/1Password/app/8/op-ssh-sign-wsl.exe
```

Replace `<WindowsUser>` with your actual Windows username and `<your SSH public key>` with
the public key of the SSH key stored in 1Password (the one added to GitHub).

To get the public key from 1Password CLI:

```bash
op read "op://Personal/GitHub SSH Key/public key"
```

---

## Step 5 — Verify SSH auth via 1Password

After relaunch, test that the SSH agent bridge is working:

```bash
ssh -T git@github.com
# Hi gio1612! You've successfully authenticated...
```

If it fails, check that:
- `npiperelay.exe` is on the Windows `PATH`
- 1Password SSH agent is enabled and unlocked
- The `socat` bridge in `.zshrc` started correctly: `ls ~/.ssh/agent.sock`

---

## Re-running / updating

The bootstrap is **idempotent** — safe to re-run at any time.
Already-completed phases are skipped automatically.

```bash
# Re-run everything from scratch
sudo bash bootstrap.sh --user gio --dotfiles https://github.com/gio1612/dotfiles.git --force

# Re-run a single phase
sudo bash phases/05-packages.sh
```

Logs are written to `/var/log/arch-bootstrap.log`.

---

## Customization

| File | Purpose |
|---|---|
| `config/packages.txt` | pacman packages to install (one per line, `#` comments ok) |
| `config/aur-packages.txt` | AUR packages installed via paru |
| `config/wsl.conf.template` | Template for `/etc/wsl.conf` (`{{USER}}` is substituted) |

---

## Phase reference

| Phase | What it does |
|---|---|
| 01 | Write `/etc/wsl.conf` (systemd, default user, automount) |
| 02 | Generate locale (`en_US.UTF-8`), detect and set timezone |
| 03 | Create user, add to wheel group, configure sudo |
| 04 | Init pacman keyring, full system upgrade |
| 05 | Install packages from `config/packages.txt` |
| 06 | Build and install `yay` from source, then AUR packages |
| 07 | Install pyenv, fnm, rustup; create Go workspace |
| 08 | Sign in to 1Password, clone dotfiles, stow all packages |
| 09 | Set default shell to zsh, bootstrap zinit |
| 10 | Fix ownership, cleanup, print next steps |
