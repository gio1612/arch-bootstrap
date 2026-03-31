#!/usr/bin/env bash
# Phase 10 — Fix ownership, cleanup, print summary
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

USER_HOME="/home/${BOOTSTRAP_USER}"

log_info "Finalizing..."

# ── Fix ownership ─────────────────────────────────────────────────────────────
log_info "Fixing ownership of ${USER_HOME}..."
chown -R "${BOOTSTRAP_USER}:${BOOTSTRAP_USER}" "${USER_HOME}"

# ── Cleanup temp files ────────────────────────────────────────────────────────
[[ -d "/tmp/paru-build" ]] && rm -rf /tmp/paru-build && log_info "Cleaned up /tmp/paru-build"

# ── Installed packages summary ───────────────────────────────────────────────
PACKAGES_FILE="$(dirname "$0")/../config/packages.txt"
PACKAGE_COUNT=$(grep -vc '^\s*#\|^\s*$' "$PACKAGES_FILE" 2>/dev/null || echo "?")

# ── Print summary ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}Bootstrap Summary${RESET}"
echo -e "─────────────────────────────────────────"
echo -e "  User     : ${BOLD}${BOOTSTRAP_USER}${RESET}"
echo -e "  Shell    : $(getent passwd "${BOOTSTRAP_USER}" | cut -d: -f7)"
echo -e "  Packages : ~${PACKAGE_COUNT} pacman packages"
echo -e "  Dotfiles : /home/${BOOTSTRAP_USER}/.dotfiles"
echo -e "  Log      : /var/log/arch-bootstrap.log"
echo -e "─────────────────────────────────────────"
echo ""
echo -e "${YELLOW}Phases completed:${RESET}"
cat /var/lib/arch-bootstrap/state 2>/dev/null | sed 's/^/  ✓ /' || true
echo ""
echo -e "${BOLD}${YELLOW}ACTION REQUIRED:${RESET}"
echo -e "  Run from PowerShell or CMD:"
echo ""
echo -e "    ${BOLD}wsl --shutdown${RESET}"
echo ""
echo -e "  Then relaunch this distro. You will land as ${BOLD}${BOOTSTRAP_USER}${RESET} in zsh."
echo -e "  The 1Password SSH agent bridge will be active via socat in your .zshrc."
echo ""
echo -e "${BOLD}Machine-specific git config:${RESET}"
echo -e "  Create ~/.gitconfig.local with your SSH signing key and 1Password path:"
echo ""
echo -e "    [user]"
echo -e "        signingkey = <your SSH public key>"
echo -e "    [gpg \"ssh\"]"
echo -e "        program = /mnt/c/Users/<WindowsUser>/AppData/Local/1Password/app/8/op-ssh-sign-wsl.exe"
echo ""
