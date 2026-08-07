#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_root

log "=== FASE 5: Coolify ==="

if ! systemctl -q is-active docker; then
  err "Docker no está corriendo. Ejecuta primero la fase Docker."
  exit 1
fi

mkdir -p /data/coolify
log "Instalando Coolify v4 (PostgreSQL por defecto). Puede tardar varios minutos..."
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash

TS_IP="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
log "FASE 5 completa."
log "Acceso a Coolify desde tu laptop (con Tailscale):"
log "   http://$TS_IP:8000   (o http://$(hostname):8000 si MagicDNS está activo)"
log "Crea tu cuenta de administrador en el navegador."
log "No expongas Coolify a Internet: solo se accede por VPN."
