#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_root

DOMAIN="${HOMELAB_DNS_DOMAIN:-intellium.lan}"
ADGUARD_PORT="${HOMELAB_ADGUARD_PORT:-3000}"
TS_IP="$(tailscale ip -4 2>/dev/null | head -n1 || true)"

log "=== FASE 7: DNS de la VPN (AdGuard Home + $DOMAIN) ==="

if [ -z "$TS_IP" ]; then
  err "Tailscale no está conectado. Ejecuta antes la fase 03."
  exit 1
fi

if ! curl -s -m 5 -o /dev/null "http://127.0.0.1:$ADGUARD_PORT"; then
  warn "AdGuard Home no responde en 127.0.0.1:$ADGUARD_PORT."
  warn "Despliégalo primero en Coolify:"
  warn "  Coolify > Services > New > AdGuard Home > Deploy"
  warn "  Puertos: 53 (UDP/TCP) para DNS y $ADGUARD_PORT para el panel admin"
  exit 1
fi

ADGUARD_USER="$(ask 'Usuario admin de AdGuard Home' 'admin')"
ADGUARD_PASS="$(ask_secret 'Contraseña de AdGuard Home (no se muestra): ')"

TMP_COOKIE="$(mktemp)"
if ! curl -s -m 5 -c "$TMP_COOKIE" -H 'Content-Type: application/json' \
  -d "{\"name\":\"$ADGUARD_USER\",\"password\":\"$ADGUARD_PASS\"}" \
  "http://127.0.0.1:$ADGUARD_PORT/control/login" | grep -q 'true'; then
  err "Login a AdGuard Home falló. Revisa usuario/contraseña."
  rm -f "$TMP_COOKIE"
  exit 1
fi

if curl -s -m 5 -b "$TMP_COOKIE" "http://127.0.0.1:$ADGUARD_PORT/control/rewrite/list" | grep -q "$DOMAIN"; then
  log "El rewrite para $DOMAIN ya existe."
else
  if curl -s -m 5 -b "$TMP_COOKIE" -H 'Content-Type: application/json' \
    -d "{\"domain\":\"*.$DOMAIN\",\"answer\":\"$TS_IP\"}" \
    "http://127.0.0.1:$ADGUARD_PORT/control/rewrite/add" | grep -q 'true'; then
    log "Rewrite agregado: *.$DOMAIN -> $TS_IP"
  else
    warn "No se pudo agregar el rewrite. Puedes hacerlo en el panel de AdGuard Home:"
    warn "  Filters > DNS rewrites > Add: *.$DOMAIN -> $TS_IP"
  fi
fi
rm -f "$TMP_COOKIE"

log ""
log "FASE 7 (servidor) completa."
log "Paso final en la consola de Tailscale (manual, solo una vez):"
log "  1. Abre https://login.tailscale.com/admin"
log "  2. DNS > Nameservers > Add nameserver: $TS_IP"
log "  3. Elige 'Only domains' y escribe: $DOMAIN"
log "  4. Guarda (MagicDNS debe estar activo)."
log ""
log "Después, en Coolify, asigna a cada recurso un dominio:"
log "  <nombre>.$DOMAIN   (ej. n8n.$DOMAIN, gitea.$DOMAIN)"
log "Verificación desde tu laptop: nslookup n8n.$DOMAIN  ->  $TS_IP"
