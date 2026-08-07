#!/usr/bin/env bash
set -euo pipefail

HOMELAB_LOG="${HOMELAB_LOG:-/var/log/homelab-setup.log}"
HOMELAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$HOMELAB_LOG"; }
warn() { echo "[AVISO] $*" | tee -a "$HOMELAB_LOG"; }
err()  { echo "[ERROR] $*" | tee -a "$HOMELAB_LOG" >&2; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    err "Ejecuta con: sudo bash $0"
    exit 1
  fi
}

detect_user() {
  if [ -n "${HOMELAB_USER:-}" ]; then printf '%s' "$HOMELAB_USER"; return; fi
  local u
  u="$(logname 2>/dev/null || echo "${SUDO_USER:-}")"
  if [ -z "$u" ] || [ "$u" = "root" ]; then u="jose"; fi
  printf '%s' "$u"
}

ask() {
  local msg="$1" def="${2:-}" input
  if [ -n "$def" ]; then
    read -r -p "$msg [$def]: " input
  else
    read -r -p "$msg: " input
  fi
  if [ -n "$input" ]; then printf '%s' "$input"; else printf '%s' "$def"; fi
}

ask_secret() {
  local msg="$1" input
  read -r -p "$msg" input
  printf '%s' "$input"
}

ask_yes_no() {
  local msg="$1" def="${2:-n}" input
  read -r -p "$msg [$def]: " input
  if [ -z "$input" ]; then input="$def"; fi
  case "${input,,}" in
    y|s|yes|si|sí) printf 'yes' ;;
    *) printf 'no' ;;
  esac
}

is_installed() { command -v "$1" >/dev/null 2>&1; }

has_ubuntu_2404() {
  [ -f /etc/os-release ] || return 1
  . /etc/os-release
  [ "$ID" = "ubuntu" ] && [ "$VERSION_ID" = "24.04" ]
}

ensure_tailscale0_rules() {
  if ip link show tailscale0 >/dev/null 2>&1; then
    ufw allow in on tailscale0 >/dev/null 2>&1
    ufw reload >/dev/null 2>&1
    log "UFW: permitido acceso entrante en la interfaz tailscale0"
  else
    warn "tailscale0 no existe aún; las reglas UFW de la VPN se aplicarán al terminar la fase Tailscale."
  fi
}
