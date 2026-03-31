#!/usr/bin/env bash
# lib/common.sh — shared utilities for arch-bootstrap phases

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${RESET}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo -e "\n${BOLD}${CYAN}==>${RESET}${BOLD} $*${RESET}"; }

# ── Root guard ────────────────────────────────────────────────────────────────
check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root."
    exit 1
  fi
}

# ── Phase state tracking ───────────────────────────────────────────────────────
STATE_DIR="/var/lib/arch-bootstrap"
STATE_FILE="${STATE_DIR}/state"

mkdir -p "$STATE_DIR"

phase_done() {
  local phase="$1"
  grep -qxF "$phase" "$STATE_FILE" 2>/dev/null
}

mark_done() {
  local phase="$1"
  echo "$phase" >> "$STATE_FILE"
}

# ── Run command as target user ────────────────────────────────────────────────
# Usage: run_as_user "command here"
run_as_user() {
  sudo -u "${BOOTSTRAP_USER}" bash -c "$1"
}

# ── Backup a file before overwriting ──────────────────────────────────────────
backup_file() {
  local file="$1"
  if [[ -e "$file" ]]; then
    local backup_dir="${HOME}/.config-backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    cp -r "$file" "$backup_dir/"
    log_warn "Backed up ${file} → ${backup_dir}/"
  fi
}

# ── DNS check ────────────────────────────────────────────────────────────────
check_dns() {
  if ! getent hosts archlinux.org &>/dev/null; then
    log_warn "DNS resolution failed. Writing fallback /etc/resolv.conf..."
    backup_file /etc/resolv.conf
    # Unlink WSL-managed symlink if present
    [[ -L /etc/resolv.conf ]] && rm /etc/resolv.conf
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    log_info "Set fallback DNS. Consider adding generateResolvConf=false to wsl.conf."
  fi
}
