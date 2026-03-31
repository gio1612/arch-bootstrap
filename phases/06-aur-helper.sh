#!/usr/bin/env bash
# Phase 06 — Install yay (AUR helper) + AUR packages
# Builds yay from source to avoid libalpm version mismatch with pre-compiled bins
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

AUR_PACKAGES_FILE="$(dirname "$0")/../config/aur-packages.txt"
BUILD_DIR="/tmp/yay-build"

# ── Install yay ───────────────────────────────────────────────────────────────
if command -v yay &>/dev/null; then
  log_info "yay already installed."
else
  log_info "Building yay from AUR (source build — avoids libalpm version mismatch)..."

  check_dns

  rm -rf "$BUILD_DIR"
  run_as_user "git clone https://aur.archlinux.org/yay.git '${BUILD_DIR}'"
  # makepkg -s installs deps; --noconfirm skips prompts; skip the sudo install step
  run_as_user "cd '${BUILD_DIR}' && makepkg -s --noconfirm"

  # Install the built package as root (makepkg -i uses sudo which fails non-interactively)
  PKG=$(ls "${BUILD_DIR}"/yay-[0-9]*.pkg.tar.zst 2>/dev/null | head -1)
  if [[ -z "$PKG" ]]; then
    log_error "yay package not found after build — check ${BUILD_DIR}"
    exit 1
  fi
  pacman -U --noconfirm "$PKG"
  rm -rf "$BUILD_DIR"
  log_info "yay installed."
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
# yay must not run as root
# shellcheck disable=SC2086
run_as_user "yay -S --needed --noconfirm $AUR_PACKAGES" || \
  log_warn "Some AUR packages failed to install — check manually with: yay -S <package>"
