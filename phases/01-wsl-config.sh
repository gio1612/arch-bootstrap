#!/usr/bin/env bash
# Phase 01 — WSL2 configuration (/etc/wsl.conf)
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

WSL_CONF="/etc/wsl.conf"
TEMPLATE="$(dirname "$0")/../config/wsl.conf.template"

log_info "Configuring /etc/wsl.conf..."

# Substitute the username into the template
RENDERED=$(sed "s/{{USER}}/${BOOTSTRAP_USER}/g" "$TEMPLATE")

# Only write if content differs
CURRENT_HASH=""
NEW_HASH=$(echo "$RENDERED" | sha256sum | cut -d' ' -f1)

if [[ -f "$WSL_CONF" ]]; then
  CURRENT_HASH=$(sha256sum "$WSL_CONF" | cut -d' ' -f1)
fi

if [[ "$CURRENT_HASH" == "$NEW_HASH" ]]; then
  log_info "/etc/wsl.conf is already up to date."
else
  backup_file "$WSL_CONF"
  echo "$RENDERED" > "$WSL_CONF"
  log_info "Written /etc/wsl.conf"
  log_warn "wsl.conf changes require 'wsl --shutdown' to take effect."
fi
