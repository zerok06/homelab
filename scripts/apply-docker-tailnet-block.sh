#!/usr/bin/env bash
set -euo pipefail

IFACE="$(ip route get 1.1.1.1 2>/dev/null | sed -n 's/.*dev \([^ ]*\).*/\1/p')"
[ -n "$IFACE" ] || exit 0

if /usr/sbin/iptables -w -L DOCKER-USER -n >/dev/null 2>&1; then
  /usr/sbin/iptables -w -D DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN 2>/dev/null || true
  /usr/sbin/iptables -w -D DOCKER-USER -i "$IFACE" ! -s 100.64.0.0/10 -j DROP 2>/dev/null || true
  /usr/sbin/iptables -w -A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
  /usr/sbin/iptables -w -A DOCKER-USER -i "$IFACE" ! -s 100.64.0.0/10 -j DROP
fi
