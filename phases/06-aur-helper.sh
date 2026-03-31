#!/usr/bin/env bash
# Phase 06 — Install paru (AUR helper) + AUR packages
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

AUR_PACKAGES_FILE="$(dirname "$0")/../config/aur-packages.txt"
BUILD_DIR="/tmp/paru-build"

# ── Install paru-bin ──────────────────────────────────────────────────────────
if command -v paru &>/dev/null; then
  log_info "paru already installed."
else
  log_info "Building paru-bin from AUR..."

  check_dns

  # git and base-devel must already be installed (phase 05)
  rm -rf "$BUILD_DIR"
  run_as_user "git clone https://aur.archlinux.org/paru-bin.git ${BUILD_DIR}"
  run_as_user "cd ${BUILD_DIR} && makepkg -si --noconfirm"
  rm -rf "$BUILD_DIR"
  log_info "paru installed."
fi

# ── Install AUR packages ──────────────────────────────────────────────────────
if [[ ! -f "$AUR_PACKAGES_FILE" ]]; then
  log_warn "No aur-packages.txt found — skipping AUR packages."
  exit 0
fi

AUR_PACKAGES=$(grep -v '^\s*#' "$AUR_PACKAGES_FILE" | grep -v '^\s*$' | tr '\n' ' ')

if [[ -z "$AUR_PACKAGES" ]]; then
  log_warn "aur-packages.txt is empty — nothing to install."
  exit 0
fi

log_info "Installing AUR packages: ${AUR_PACKAGES}"
# Run paru as the target user (paru must not run as root)
# shellcheck disable=SC2086
run_as_user "paru -S --needed --noconfirm $AUR_PACKAGES" || \
  log_warn "Some AUR packages failed to install — continuing."
