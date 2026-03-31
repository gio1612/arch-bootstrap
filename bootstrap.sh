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

# ── Pre-flight checks ─────────────────────────────────────────────────────────
preflight_checks() {
  local errors=0

  log_step "Pre-flight checks"

  # Must run as root
  if [[ $EUID -ne 0 ]]; then
    log_error "Bootstrap must run as root (use: sudo bash bootstrap.sh ...)"
    errors=$(( errors + 1 ))
  else
    log_info "  ✓  Running as root"
  fi

  # Must be Arch Linux
  if grep -q 'ID=arch' /etc/os-release 2>/dev/null; then
    log_info "  ✓  Arch Linux detected"
  else
    log_error "  ✗  This bootstrap is designed for Arch Linux only."
    errors=$(( errors + 1 ))
  fi

  # Must be inside WSL
  if grep -qi 'microsoft\|wsl' /proc/version 2>/dev/null; then
    log_info "  ✓  Running inside WSL2"
  else
    log_warn "  ?  WSL not detected — /proc/version does not mention Microsoft/WSL."
    log_warn "     Continuing anyway, but some WSL-specific steps may not apply."
  fi

  # Internet connectivity
  if getent hosts archlinux.org &>/dev/null; then
    log_info "  ✓  DNS resolution works (archlinux.org)"
  else
    log_warn "  ?  DNS resolution failed. Will attempt fallback in pacman phase."
    log_warn "     If pacman fails, check /etc/resolv.conf or set a static nameserver."
  fi

  # Disk space — require at least 4 GiB free on /
  local free_gib
  free_gib=$(df --output=avail -BG / | tail -1 | tr -d 'G[:space:]')
  if [[ "$free_gib" -ge 4 ]]; then
    log_info "  ✓  Disk space: ${free_gib} GiB free"
  else
    log_error "  ✗  Less than 4 GiB free on / (${free_gib} GiB). Installation will likely fail."
    errors=$(( errors + 1 ))
  fi

  # --user must be set and valid (alphanumeric + underscore/hyphen, no spaces)
  if [[ -z "$BOOTSTRAP_USER" ]]; then
    log_error "  ✗  --user is required."
    errors=$(( errors + 1 ))
  elif [[ ! "$BOOTSTRAP_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    log_error "  ✗  --user '${BOOTSTRAP_USER}' is not a valid Linux username."
    errors=$(( errors + 1 ))
  else
    log_info "  ✓  Target user: ${BOOTSTRAP_USER}"
  fi

  # Warn if dotfiles URL not provided (phase 08 will prompt interactively)
  if [[ -z "${DOTFILES_REPO:-}" ]]; then
    log_warn "  ?  --dotfiles not set. Phase 08 will prompt you for the URL."
  else
    log_info "  ✓  Dotfiles repo: ${DOTFILES_REPO}"
  fi

  if [[ $errors -gt 0 ]]; then
    log_error "${errors} pre-flight check(s) failed. Fix the issues above and re-run."
    exit 1
  fi

  log_info "All pre-flight checks passed."
}

preflight_checks

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
