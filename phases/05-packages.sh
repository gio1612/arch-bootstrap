#!/usr/bin/env bash
# Phase 05 — Install base packages from config/packages.txt
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

PACKAGES_FILE="$(dirname "$0")/../config/packages.txt"

log_info "Installing packages from ${PACKAGES_FILE}..."

# Strip comments and blank lines
PACKAGES=$(grep -v '^\s*#' "$PACKAGES_FILE" | grep -v '^\s*$' | tr '\n' ' ')

if [[ -z "$PACKAGES" ]]; then
  log_warn "packages.txt is empty — nothing to install."
  exit 0
fi

log_info "Packages: ${PACKAGES}"
# shellcheck disable=SC2086
pacman -S --needed --noconfirm $PACKAGES
