#!/usr/bin/env bash
# bootstrap.sh — Arch Linux WSL2 initial setup
# Usage: sudo ./bootstrap.sh [--user USERNAME] [--dotfiles GIT_URL] [--force]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# ── Defaults ──────────────────────────────────────────────────────────────────
BOOTSTRAP_USER="gio"
DOTFILES_REPO=""
FORCE=false

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      [[ $# -lt 2 ]] && { log_error "--user requires a value"; exit 1; }
      BOOTSTRAP_USER="$2"; shift 2 ;;
    --dotfiles)
      [[ $# -lt 2 ]] && { log_error "--dotfiles requires a value"; exit 1; }
      DOTFILES_REPO="$2"; shift 2 ;;
    --force)     FORCE=true; shift ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

export BOOTSTRAP_USER
export DOTFILES_REPO

# ── Sanity checks ─────────────────────────────────────────────────────────────
check_root

# ── Logging setup ─────────────────────────────────────────────────────────────
LOG_FILE="/var/log/arch-bootstrap.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

log_step "Arch Linux WSL2 Bootstrap"
log_info "User    : ${BOOTSTRAP_USER}"
log_info "Dotfiles: ${DOTFILES_REPO:-<not set — will prompt in phase 08>}"
log_info "Force   : ${FORCE}"
log_info "Log     : ${LOG_FILE}"

START_TIME=$(date +%s)

# ── Phase runner ──────────────────────────────────────────────────────────────
run_phase() {
  local script="$1"
  local name
  name="$(basename "$script" .sh)"

  if ! $FORCE && phase_done "$name"; then
    log_info "Skipping ${name} (already complete). Use --force to re-run."
    return 0
  fi

  log_step "Phase: ${name}"
  bash "$script"
  mark_done "$name"
  log_info "${name} complete."
}

# ── Execute phases in order ───────────────────────────────────────────────────
for phase in "${SCRIPT_DIR}/phases"/[0-9]*.sh; do
  run_phase "$phase"
done

# ── Summary ───────────────────────────────────────────────────────────────────
ELAPSED=$(( $(date +%s) - START_TIME ))
log_step "Bootstrap complete in ${ELAPSED}s"
echo ""
echo -e "${YELLOW}NEXT STEP:${RESET} Run the following from PowerShell or CMD, then relaunch this distro:"
echo ""
echo -e "    ${BOLD}wsl --shutdown${RESET}"
echo ""
echo "This applies the wsl.conf changes (systemd, default user, automount)."
