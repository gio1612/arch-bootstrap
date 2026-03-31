#!/usr/bin/env bash
# Phase 09 — Set default shell to zsh, bootstrap zinit
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

USER_HOME="/home/${BOOTSTRAP_USER}"
ZSH_BIN="/usr/bin/zsh"
ZINIT_DIR="${USER_HOME}/.local/share/zinit/zinit.git"

# ── Install zsh if missing ────────────────────────────────────────────────────
if [[ ! -x "$ZSH_BIN" ]]; then
  log_info "zsh not found — installing..."
  pacman -S --needed --noconfirm zsh
fi

# ── Set default shell ─────────────────────────────────────────────────────────
CURRENT_SHELL=$(getent passwd "${BOOTSTRAP_USER}" | cut -d: -f7)
if [[ "$CURRENT_SHELL" == "$ZSH_BIN" ]]; then
  log_info "Default shell is already zsh."
else
  chsh -s "$ZSH_BIN" "${BOOTSTRAP_USER}"
  log_info "Default shell set to zsh for '${BOOTSTRAP_USER}'."
fi

# ── Bootstrap zinit (if not already installed by dotfiles) ───────────────────
if [[ -d "$ZINIT_DIR" ]]; then
  log_info "zinit already installed."
else
  log_info "Installing zinit..."
  run_as_user "mkdir -p $(dirname ${ZINIT_DIR})"
  run_as_user "git clone https://github.com/zdharma-continuum/zinit.git ${ZINIT_DIR}"
  log_info "zinit installed to ${ZINIT_DIR}"
fi
