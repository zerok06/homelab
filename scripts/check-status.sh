#!/usr/bin/env bash
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

PASS=0
FAIL=0

check() {
  local name="$1" cmd="$2"
  if bash -c "$cmd" >/dev/null 2>&1; then
    echo "  [OK]   $name"
    PASS=$((PASS + 1))
  else
    echo "  [FALLO] $name"
    FAIL=$((FAIL + 1))
  fi
}

TS_IP="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
DOMAIN="${HOMELAB_DNS_DOMAIN:-intellium.lan}"

echo "=== Homelab: estado general ==="
echo "-- Sistema --"
check "Ubuntu activo" "systemctl -q is-active multi-user.target"
check "Docker Engine" "systemctl -q is-active docker"
check "SSH" "systemctl -q is-active ssh"
check "UFW activo (default deny)" "ufw status | grep -q 'Status: active'"
check "Fail2Ban" "systemctl -q is-active fail2ban"
check "docker-tailnet-only (bloqueo 80/443 fuera de VPN)" "systemctl -q is-active docker-tailnet-only"

echo "-- Contenedores (deben estar Up) --"
for c in coolify coolify-db coolify-redis coolify-realtime coolify-proxy coolify-sentinel; do
  check "contenedor $c" "docker inspect '$c' --format '{{.State.Running}}' 2>/dev/null | grep -q true"
done
ADG="$(docker ps -aq --filter ancestor=adguard/adguardhome --format '{{.Names}}' | head -n1 || true)"
if [ -n "$ADG" ]; then
  check "adguard ($ADG)" "docker inspect '$ADG' --format '{{.State.Running}}' | grep -q true"
  check "adguard DNS :53 (en IP Tailscale)" "ss -tulnp 2>/dev/null | grep -q ':53 '"
else
  echo "  [FALLO] contenedor adguard"
  FAIL=$((FAIL + 1))
fi

echo "-- Acceso --"
if [ -n "$TS_IP" ]; then
  echo "  IP VPN del servidor: $TS_IP"
  check "Coolify http://$TS_IP:8000" "curl -s -m 5 -o /dev/null 'http://127.0.0.1:8000'"
  check "AdGuard web :3000" "curl -s -m 5 -o /dev/null 'http://$TS_IP:3000'"
else
  echo "  [FALLO] Tailscale no conectado"
  FAIL=$((FAIL + 1))
fi
check "Tailscale up" "tailscale status >/dev/null 2>&1"

echo "-- DNS de la VPN (wildcard *.$DOMAIN) --"
check "resuelve test.$DOMAIN -> $TS_IP" "getent ahostsv4 test.$DOMAIN | awk '{print \$1}' | grep -q '$TS_IP'"

echo ""
echo "=== Resultado: $PASS OK / $FAIL fallos ==="
if [ "$FAIL" -gt 0 ]; then
  echo "Revisa: sudo systemctl status <servicio> | docker logs <contenedor> --tail 50 | sudo bash scripts/check-status.sh"
  exit 1
fi
