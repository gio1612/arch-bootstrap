#!/usr/bin/env bash
# Phase 03 — Create user, sudo access
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

log_info "Setting up user: ${BOOTSTRAP_USER}"

# ── Create user if not exists ─────────────────────────────────────────────────
if id -u "${BOOTSTRAP_USER}" &>/dev/null; then
  log_info "User '${BOOTSTRAP_USER}' already exists."
else
  useradd -m -G wheel -s /bin/bash "${BOOTSTRAP_USER}"
  log_info "Created user '${BOOTSTRAP_USER}' with wheel group."
fi

# Ensure home dir exists and is owned by the user (guards against re-runs
# where a previous root process may have created files under the home dir)
USER_HOME="/home/${BOOTSTRAP_USER}"
mkdir -p "${USER_HOME}"
chown "${BOOTSTRAP_USER}:${BOOTSTRAP_USER}" "${USER_HOME}"

# Ensure user is in wheel group
if ! groups "${BOOTSTRAP_USER}" | grep -q "\bwheel\b"; then
  usermod -aG wheel "${BOOTSTRAP_USER}"
  log_info "Added '${BOOTSTRAP_USER}' to wheel group."
fi

# ── Sudo configuration ────────────────────────────────────────────────────────
SUDOERS_FILE="/etc/sudoers.d/wheel"
SUDOERS_CONTENT="%wheel ALL=(ALL:ALL) ALL"

if [[ -f "$SUDOERS_FILE" ]] && grep -qxF "$SUDOERS_CONTENT" "$SUDOERS_FILE"; then
  log_info "Sudoers for wheel already configured."
else
  SUDOERS_TMP=$(mktemp)
  echo "$SUDOERS_CONTENT" > "$SUDOERS_TMP"
  if visudo -cf "$SUDOERS_TMP" &>/dev/null; then
    install -m 0440 "$SUDOERS_TMP" "$SUDOERS_FILE"
    log_info "Installed ${SUDOERS_FILE}"
  else
    log_error "visudo validation failed — sudoers NOT installed."
    rm "$SUDOERS_TMP"
    exit 1
  fi
  rm "$SUDOERS_TMP"
fi

# ── Set password ──────────────────────────────────────────────────────────────
# Check if password is already set (shadow entry is not '!' or '*')
SHADOW_ENTRY=$(getent shadow "${BOOTSTRAP_USER}" | cut -d: -f2)
if [[ "$SHADOW_ENTRY" == "!" || "$SHADOW_ENTRY" == "*" || -z "$SHADOW_ENTRY" ]]; then
  log_info "Setting password for '${BOOTSTRAP_USER}'..."
  passwd "${BOOTSTRAP_USER}"
else
  log_info "Password already set for '${BOOTSTRAP_USER}'."
fi
