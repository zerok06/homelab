#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

require_root

cat <<'BANNER'
============================================================
   Homelab v1 - Intellium  |  HP ProDesk + Ubuntu 24.04
   Fases: SO, Tailscale, Seguridad, Docker, Coolify, Backups
============================================================
BANNER

if ! has_ubuntu_2404; then
  warn "Esto no parece Ubuntu 24.04 LTS."
  if [ "$(ask_yes_no '¿Continuar de todos modos?' 'n')" != "yes" ]; then
    exit 1
  fi
fi

HOMELAB_USER="$(ask 'Usuario administrador' "$(detect_user)")"
HOMELAB_HOSTNAME="$(ask 'Hostname del servidor' 'homelab')"
HOMELAB_TIMEZONE="$(ask 'Zona horaria' "$(cat /etc/timezone 2>/dev/null || echo America/Lima)")"
HOMELAB_SSH_PUBKEY="$(ask 'Llave publica SSH (ssh-ed25519 ...) o Enter para omitir' '')"
HOMELAB_TAILSCALE_AUTHKEY="$(ask 'Auth key de Tailscale (tskey-...) o Enter para login manual' '')"

export HOMELAB_USER HOMELAB_HOSTNAME HOMELAB_TIMEZONE HOMELAB_SSH_PUBKEY HOMELAB_TAILSCALE_AUTHKEY

log "Config: usuario=$HOMELAB_USER hostname=$HOMELAB_HOSTNAME tz=$HOMELAB_TIMEZONE"
log "Iniciando en 5 segundos (Ctrl+C para cancelar)..."
sleep 5

run_phase() {
  log ">>> Iniciando fase: $1"
  bash "$1.sh"
  log "<<< Fase terminada: $1"
}

run_phase 01-install-base
run_phase 03-tailscale
run_phase 02-security
run_phase 04-docker
run_phase 05-install-coolify

log ""
log "=============================="
log "  INSTALACIÓN COMPLETA"
log "=============================="
log "SSH desde tu laptop (con Tailscale):"
log "   ssh $HOMELAB_USER@$HOMELAB_HOSTNAME"
log "Coolify (crea tu cuenta admin):"
log "   http://$HOMELAB_HOSTNAME:8000"
log "Backups:"
log "   sudo bash scripts/06-backup-config.sh"
log "Log completo:"
log "   $HOMELAB_LOG"
