#!/usr/bin/env bash
# Phase 08 — Clone dotfiles via 1Password SSH agent + stow
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

USER_HOME="/home/${BOOTSTRAP_USER}"
DOTFILES_DIR="${USER_HOME}/.dotfiles"
SSH_DIR="${USER_HOME}/.ssh"
KEY_FILE="${SSH_DIR}/id_ed25519"
KNOWN_HOSTS="${SSH_DIR}/known_hosts"

# ── Resolve dotfiles repo URL ─────────────────────────────────────────────────
if [[ -z "${DOTFILES_REPO:-}" ]]; then
  echo -n "Enter your dotfiles git URL (e.g. git@github.com:gio1612/dotfiles.git): "
  read -r DOTFILES_REPO
fi

if [[ -z "$DOTFILES_REPO" ]]; then
  log_error "No dotfiles repo provided. Skipping dotfiles phase."
  exit 0
fi

# ── SSH setup ─────────────────────────────────────────────────────────────────
run_as_user "mkdir -p ${SSH_DIR} && chmod 700 ${SSH_DIR}"

# Add GitHub to known_hosts to avoid interactive prompt
if ! run_as_user "grep -q 'github.com' ${KNOWN_HOSTS} 2>/dev/null"; then
  log_info "Adding github.com to known_hosts..."
  run_as_user "ssh-keyscan -H github.com >> ${KNOWN_HOSTS} 2>/dev/null"
fi

# ── Retrieve SSH key from 1Password CLI ───────────────────────────────────────
if [[ ! -f "$KEY_FILE" ]]; then
  if command -v op &>/dev/null; then
    log_info "Signing in to 1Password CLI..."
    # Run op signin interactively as root (it will prompt for master password)
    eval "$(op signin)" || {
      log_error "1Password sign-in failed."
      exit 1
    }

    log_info "Retrieving SSH private key from 1Password..."
    echo "Enter the 1Password secret reference for your GitHub SSH private key."
    echo "Format: op://VaultName/ItemName/private key"
    echo -n "Secret reference: "
    read -r OP_REF

    op read "$OP_REF" > "$KEY_FILE"
    chown "${BOOTSTRAP_USER}:${BOOTSTRAP_USER}" "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    log_info "SSH key written temporarily to ${KEY_FILE}"
  else
    log_warn "1password-cli (op) not found."
    log_info "Falling back to HTTPS clone with GitHub PAT."
    echo -n "Enter GitHub Personal Access Token: "
    read -rs GITHUB_PAT
    echo ""
    # Rewrite SSH URL to HTTPS+PAT if needed
    if [[ "$DOTFILES_REPO" == git@github.com:* ]]; then
      REPO_PATH="${DOTFILES_REPO#git@github.com:}"
      DOTFILES_REPO="https://oauth2:${GITHUB_PAT}@github.com/${REPO_PATH}"
    fi
  fi
fi

# ── Clone or update dotfiles ──────────────────────────────────────────────────
if [[ -d "$DOTFILES_DIR" ]]; then
  CURRENT_REMOTE=$(run_as_user "git -C ${DOTFILES_DIR} remote get-url origin 2>/dev/null" || echo "")
  if [[ -n "$CURRENT_REMOTE" ]]; then
    log_info "Dotfiles already cloned. Pulling latest..."
    run_as_user "git -C ${DOTFILES_DIR} pull --ff-only" || \
      log_warn "git pull failed — continuing with existing dotfiles."
  else
    log_warn "${DOTFILES_DIR} exists but is not a git repo. Skipping clone."
  fi
else
  log_info "Cloning dotfiles..."
  if [[ -f "$KEY_FILE" ]]; then
    run_as_user "GIT_SSH_COMMAND='ssh -i ${KEY_FILE} -o StrictHostKeyChecking=no' \
      git clone ${DOTFILES_REPO} ${DOTFILES_DIR}"
  else
    run_as_user "git clone ${DOTFILES_REPO} ${DOTFILES_DIR}"
  fi
  log_info "Dotfiles cloned to ${DOTFILES_DIR}"
fi

# ── Shred temporary key (1Password SSH agent takes over after reboot) ─────────
if [[ -f "$KEY_FILE" ]] && command -v op &>/dev/null; then
  shred -u "$KEY_FILE"
  log_info "Temporary SSH key removed. 1Password SSH agent will handle future auth."
fi

# ── Stow dotfiles ─────────────────────────────────────────────────────────────
log_info "Stowing dotfiles..."

STOW_PACKAGES=$(find "$DOTFILES_DIR" -maxdepth 1 -mindepth 1 -type d \
  ! -name '.git' -printf '%f\n' | sort)

if [[ -z "$STOW_PACKAGES" ]]; then
  log_warn "No stow packages found in ${DOTFILES_DIR}."
  exit 0
fi

BACKUP_DIR="${USER_HOME}/.config-backup/$(date +%Y%m%d_%H%M%S)"

for pkg in $STOW_PACKAGES; do
  log_info "Stowing: ${pkg}"
  # Dry run first to detect conflicts
  CONFLICTS=$(run_as_user "stow -d ${DOTFILES_DIR} -t ~ --no-folding -n ${pkg} 2>&1" | \
    grep -i "conflict\|existing target" || true)

  if [[ -n "$CONFLICTS" ]]; then
    log_warn "Conflicts for ${pkg}:"
    echo "$CONFLICTS"
    # Back up conflicting files
    mkdir -p "$BACKUP_DIR"
    chown "${BOOTSTRAP_USER}:${BOOTSTRAP_USER}" "$BACKUP_DIR"
    while IFS= read -r conflict_line; do
      # Extract the conflicting file path
      conflict_file=$(echo "$conflict_line" | grep -oP '(?<=existing target is )\S+' || true)
      if [[ -n "$conflict_file" && -e "${USER_HOME}/${conflict_file}" ]]; then
        run_as_user "cp -r ${USER_HOME}/${conflict_file} ${BACKUP_DIR}/" || true
      fi
    done <<< "$CONFLICTS"
  fi

  run_as_user "stow -d ${DOTFILES_DIR} -t ~ --no-folding --adopt ${pkg}" || \
    log_warn "stow failed for ${pkg} — skipping."
done

log_info "Dotfiles stowed."
[[ -d "$BACKUP_DIR" ]] && log_info "Backed up conflicting files to ${BACKUP_DIR}"
