#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_root

DOMAIN="${HOMELAB_DNS_DOMAIN:-intellium.lan}"
ADGUARD_PORT="${HOMELAB_ADGUARD_PORT:-3000}"
ADGUARD_USER="${HOMELAB_ADGUARD_USER:-admin}"
TS_IP="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
TS_APIKEY="${HOMELAB_TAILSCALE_APIKEY:-}"
TS_TAILNET="${HOMELAB_TAILSCALE_TAILNET:-}"

log "=== FASE 7: DNS de la VPN (AdGuard Home + $DOMAIN) ==="

if [ -z "$TS_IP" ]; then
  err "Tailscale no está conectado. Ejecuta antes la fase 03."
  exit 1
fi

ADG="http://127.0.0.1:$ADGUARD_PORT"
if ! curl -s -m 5 -o /dev/null "$ADG"; then
  ADG="http://$TS_IP:$ADGUARD_PORT"
fi
if ! curl -s -m 5 -o /dev/null "$ADG"; then
  warn "AdGuard Home no responde. Despliégalo primero en Coolify:"
  warn "  Coolify > Services > New > AdGuard Home (puertos 53 y 3000)."
  exit 1
fi

ADGUARD_PASS="$(ask_secret 'Contraseña de AdGuard Home (no se muestra): ')"
TMP_COOKIE="$(mktemp)"
if ! curl -s -m 5 -c "$TMP_COOKIE" -H 'Content-Type: application/json' \
  -d "{\"name\":\"$ADGUARD_USER\",\"password\":\"$ADGUARD_PASS\"}" \
  "$ADG/control/login" | grep -q 'true'; then
  err "Login a AdGuard Home falló. Revisa usuario/contraseña."
  rm -f "$TMP_COOKIE"
  exit 1
fi

if curl -s -m 5 -b "$TMP_COOKIE" "$ADG/control/rewrite/list" | grep -q "$DOMAIN"; then
  log "El rewrite para $DOMAIN ya existe."
else
  if curl -s -m 5 -b "$TMP_COOKIE" -H 'Content-Type: application/json' \
    -d "{\"domain\":\"*.$DOMAIN\",\"answer\":\"$TS_IP\"}" \
    "$ADG/control/rewrite/add" | grep -q 'true'; then
    log "Rewrite agregado: *.$DOMAIN -> $TS_IP"
  else
    warn "No se pudo agregar el rewrite vía API. Añádelo en el panel: Filters > DNS rewrites."
  fi
fi
rm -f "$TMP_COOKIE"

if [ -n "$TS_APIKEY" ]; then
  if [ -z "$TS_TAILNET" ]; then
    TS_TAILNET="$(tailscale status --json 2>/dev/null | jq -r '.MagicDNSSuffix' 2>/dev/null || true)"
  fi
  if [ -n "$TS_TAILNET" ]; then
    BODY=$(jq -n --arg ip "$TS_IP" --arg dom "$DOMAIN" '{($dom): [$ip]}')
    RESP=$(curl -s -m 15 -w '\nHTTP:%{http_code}' -X PUT \
      -u ":$TS_APIKEY" -H 'Content-Type: application/json' -d "$BODY" \
      "https://api.tailscale.com/api/v2/tailnet/$TS_TAILNET/dns/split-dns")
    if echo "$RESP" | grep -q 'HTTP:200'; then
      log "Split DNS de Tailscale configurado: $DOMAIN -> $TS_IP (tailnet $TS_TAILNET)"
    else
      warn "No se pudo configurar el split DNS en Tailscale. Respuesta: $(echo "$RESP" | tail -c 300)"
    fi
  else
    warn "No se pudo detectar el tailnet. Configura el split DNS manualmente en la consola de Tailscale."
  fi
fi

log ""
log "FASE 7 (servidor) completa."
if [ -z "$TS_APIKEY" ]; then
  log "Paso final en la consola de Tailscale (manual):"
  log "  1. https://login.tailscale.com/admin > DNS > Nameservers"
  log "  2. Add nameserver: $TS_IP (modo 'Only domains', dominio: $DOMAIN)"
fi
log ""
log "En Coolify, asigna a cada recurso un dominio: <nombre>.$DOMAIN (ej. n8n.$DOMAIN)."
log "Verificación desde tu laptop: nslookup n8n.$DOMAIN  ->  $TS_IP"
