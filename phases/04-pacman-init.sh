#!/usr/bin/env bash
# Phase 04 — Pacman keyring init + full system upgrade
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

log_info "Initializing pacman..."

# ── DNS check ─────────────────────────────────────────────────────────────────
check_dns

# ── Keyring ───────────────────────────────────────────────────────────────────
log_info "Initializing pacman keyring..."
pacman-key --init
pacman-key --populate archlinux

# ── Full system upgrade ───────────────────────────────────────────────────────
log_info "Running full system upgrade (pacman -Syyu)..."
pacman -Syyu --noconfirm

# ── Ensure sudo is present (not included in Arch base tarball) ────────────────
if ! command -v sudo &>/dev/null; then
  log_info "Installing sudo (not present in Arch base tarball)..."
  pacman -S --needed --noconfirm sudo
fi
