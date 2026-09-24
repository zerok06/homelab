#!/usr/bin/env bash
set -uo pipefail

TS_IP="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
[ -n "$TS_IP" ] || exit 0

if ss -tlnp 2>/dev/null | grep -q "${TS_IP}:53 "; then
  exit 0
fi

C="$(docker ps -aq --filter name=adguard | head -n1 || true)"
if [ -n "$C" ]; then
  docker start "$C" >/dev/null 2>&1 || docker restart "$C" >/dev/null 2>&1 || true
  exit 0
fi

TOKEN="$(cat /etc/homelab/coolify.token 2>/dev/null || true)"
if [ -n "$TOKEN" ]; then
  curl -s -m 30 -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
    "http://127.0.0.1:8000/api/v1/services/${HOMELAB_ADGUARD_UUID:-u9jijqbzculcs53ve9iqobra}/start" >/dev/null 2>&1 || true
fi
