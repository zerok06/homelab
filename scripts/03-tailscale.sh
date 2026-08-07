#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_root

HOMELAB_HOSTNAME="${HOMELAB_HOSTNAME:-homelab}"
HOMELAB_TAILSCALE_AUTHKEY="${HOMELAB_TAILSCALE_AUTHKEY:-}"

log "=== FASE 3: Tailscale ==="

if ! is_installed tailscale; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

if tailscale status >/dev/null 2>&1 && [ -n "$(tailscale ip -4 2>/dev/null)" ]; then
  log "Tailscale ya está conectado. IP VPN: $(tailscale ip -4)"
else
  if [ -n "$HOMELAB_TAILSCALE_AUTHKEY" ]; then
    log "Conectando con auth key..."
    tailscale up --authkey="$HOMELAB_TAILSCALE_AUTHKEY" --hostname="$HOMELAB_HOSTNAME"
  else
    log "Sin auth key. Se abrirá la URL de login en el navegador para que la abras manualmente."
    tailscale up --hostname="$HOMELAB_HOSTNAME"
  fi
fi

tailscale set --accept-dns=true 2>/dev/null || true
ensure_tailscale0_rules

TS_IP="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
log "FASE 3 completa."
log "IP VPN del servidor: $TS_IP"
log "Hostname MagicDNS:   $HOMELAB_HOSTNAME"
log "Desde tu laptop (con Tailscale instalado):"
log "   ssh $(detect_user)@$HOMELAB_HOSTNAME"
log "   http://$HOMELAB_HOSTNAME:8000"
warn "Activa MagicDNS en la consola de Tailscale (admin.tailscale.com > DNS) si los nombres no resuelven."
