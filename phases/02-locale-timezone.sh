#!/usr/bin/env bash
# Phase 02 — Locale and timezone
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

# ── Locale ────────────────────────────────────────────────────────────────────
log_info "Setting up locale..."

if locale -a 2>/dev/null | grep -qi "en_US.utf8"; then
  log_info "en_US.UTF-8 already generated."
else
  sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
  locale-gen
  log_info "Locale generated."
fi

if [[ ! -f /etc/locale.conf ]] || ! grep -q "LANG=en_US.UTF-8" /etc/locale.conf; then
  echo "LANG=en_US.UTF-8" > /etc/locale.conf
  log_info "Written /etc/locale.conf"
fi

# ── Timezone ──────────────────────────────────────────────────────────────────
log_info "Setting up timezone..."

WINDOWS_TZ=""
# Try to detect from Windows via interop
if command -v powershell.exe &>/dev/null; then
  WINDOWS_TZ=$(powershell.exe -NoProfile -NonInteractive \
    -Command "[TimeZoneInfo]::Local.Id" 2>/dev/null | tr -d '\r') || true
fi

# Map Windows timezone ID to IANA
case "$WINDOWS_TZ" in
  "Eastern Standard Time"|"Eastern Daylight Time")   IANA_TZ="America/New_York" ;;
  "Central Standard Time"|"Central Daylight Time")   IANA_TZ="America/Chicago" ;;
  "Mountain Standard Time")                          IANA_TZ="America/Denver" ;;
  "Pacific Standard Time"|"Pacific Daylight Time")   IANA_TZ="America/Los_Angeles" ;;
  "UTC")                                             IANA_TZ="UTC" ;;
  "GMT Standard Time")                               IANA_TZ="Europe/London" ;;
  "Romance Standard Time")                           IANA_TZ="Europe/Paris" ;;
  "W. Europe Standard Time")                         IANA_TZ="Europe/Berlin" ;;
  "E. South America Standard Time")                  IANA_TZ="America/Sao_Paulo" ;;
  "SA Eastern Standard Time")                        IANA_TZ="America/Buenos_Aires" ;;
  "AUS Eastern Standard Time")                       IANA_TZ="Australia/Sydney" ;;
  "Tokyo Standard Time")                             IANA_TZ="Asia/Tokyo" ;;
  *)                                                 IANA_TZ="" ;;
esac

if [[ -z "$IANA_TZ" ]]; then
  log_warn "Could not detect Windows timezone (got: '${WINDOWS_TZ}'). Falling back to UTC."
  IANA_TZ="UTC"
fi

ZONE_FILE="/usr/share/zoneinfo/${IANA_TZ}"
if [[ ! -f "$ZONE_FILE" ]]; then
  log_warn "Zone file not found: ${ZONE_FILE}. Falling back to UTC."
  IANA_TZ="UTC"
  ZONE_FILE="/usr/share/zoneinfo/UTC"
fi

CURRENT_ZONE=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||') || true
if [[ "$CURRENT_ZONE" == "$IANA_TZ" ]]; then
  log_info "Timezone already set to ${IANA_TZ}."
else
  ln -sf "$ZONE_FILE" /etc/localtime
  log_info "Timezone set to ${IANA_TZ}."
fi
