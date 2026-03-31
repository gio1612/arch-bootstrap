#!/usr/bin/env bash
# Phase 06b — Verify base + AUR package installation
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

PACKAGES_FILE="$(dirname "$0")/../config/packages.txt"
AUR_PACKAGES_FILE="$(dirname "$0")/../config/aur-packages.txt"

FAILED=0

# ── Check pacman packages ─────────────────────────────────────────────────────
log_info "Verifying pacman packages..."

while IFS= read -r line; do
  # Strip inline comments and trim whitespace
  pkg=$(echo "$line" | sed 's/#.*//' | tr -d '[:space:]')
  [[ -z "$pkg" ]] && continue

  if pacman -Qi "$pkg" &>/dev/null; then
    log_info "  ✓  ${pkg}"
  else
    log_error "  ✗  ${pkg} — NOT installed"
    FAILED=$(( FAILED + 1 ))
  fi
done < "$PACKAGES_FILE"

# ── Check AUR packages ────────────────────────────────────────────────────────
if [[ -f "$AUR_PACKAGES_FILE" ]]; then
  log_info "Verifying AUR packages..."

  while IFS= read -r line; do
    pkg=$(echo "$line" | sed 's/#.*//' | tr -d '[:space:]')
    [[ -z "$pkg" ]] && continue

    if pacman -Qi "$pkg" &>/dev/null; then
      log_info "  ✓  ${pkg}"
    else
      log_warn "  ✗  ${pkg} — NOT installed (AUR build may have failed)"
      FAILED=$(( FAILED + 1 ))
    fi
  done < "$AUR_PACKAGES_FILE"
fi

# ── Check key commands ────────────────────────────────────────────────────────
log_info "Verifying key commands..."

KEY_CMDS=(git curl zsh nvim rg fd fzf bat eza stow yay)
for cmd in "${KEY_CMDS[@]}"; do
  if command -v "$cmd" &>/dev/null; then
    log_info "  ✓  ${cmd}"
  else
    log_error "  ✗  ${cmd} — command not found"
    FAILED=$(( FAILED + 1 ))
  fi
done

# ── Result ────────────────────────────────────────────────────────────────────
if [[ $FAILED -gt 0 ]]; then
  log_warn "${FAILED} verification check(s) failed. Review the output above."
  log_warn "You can retry failed AUR packages with: yay -S <package>"
  log_warn "Continuing bootstrap — non-critical failures will not block setup."
else
  log_info "All packages and commands verified."
fi
