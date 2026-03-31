#!/usr/bin/env bash
# Phase 07 — Install dev toolchains: pyenv, fnm, rustup
# (Go is already installed via pacman in phase 05)
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

USER_HOME="/home/${BOOTSTRAP_USER}"

# ── pyenv ─────────────────────────────────────────────────────────────────────
if [[ -d "${USER_HOME}/.pyenv" ]]; then
  log_info "pyenv already installed."
else
  log_info "Installing pyenv..."
  run_as_user "curl -fsSL https://pyenv.run | bash"
  log_info "pyenv installed. Install a Python version with: pyenv install <version>"
fi

# ── fnm (Fast Node Manager) ───────────────────────────────────────────────────
if run_as_user "command -v fnm" &>/dev/null; then
  log_info "fnm already installed."
else
  log_info "Installing fnm..."
  run_as_user "curl -fsSL https://fnm.vercel.app/install | bash"
  log_info "fnm installed. Install Node LTS with: fnm install --lts"
fi

# ── rustup ────────────────────────────────────────────────────────────────────
if [[ -f "${USER_HOME}/.cargo/bin/rustup" ]]; then
  log_info "rustup already installed."
else
  log_info "Installing rustup..."
  run_as_user "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path"
  log_info "rustup installed."
fi

# ── Go workspace dirs ─────────────────────────────────────────────────────────
for dir in go/bin go/src go/pkg; do
  if [[ ! -d "${USER_HOME}/${dir}" ]]; then
    mkdir -p "${USER_HOME}/${dir}"
    chown "${BOOTSTRAP_USER}:${BOOTSTRAP_USER}" "${USER_HOME}/${dir}"
  fi
done
log_info "Go workspace dirs ready at ~/go/"

# ── delta (git diff pager, needed for .gitconfig) ─────────────────────────────
if ! command -v delta &>/dev/null; then
  log_info "Installing delta (git pager) via cargo..."
  run_as_user "source \$HOME/.cargo/env && cargo install git-delta" || \
    log_warn "delta install failed — install manually with 'cargo install git-delta'"
fi
