#!/usr/bin/env bash
set -euo pipefail

IFACE="$(ip route get 1.1.1.1 2>/dev/null | sed -n 's/.*dev \([^ ]*\).*/\1/p')"
[ -n "$IFACE" ] || exit 0

if /usr/sbin/iptables -w -L DOCKER-USER -n >/dev/null 2>&1; then
  /usr/sbin/iptables -w -C DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN 2>/dev/null || \
    /usr/sbin/iptables -w -I DOCKER-USER 1 -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
  /usr/sbin/iptables -w -C DOCKER-USER -i "$IFACE" ! -s 100.64.0.0/10 -j DROP 2>/dev/null || \
    /usr/sbin/iptables -w -I DOCKER-USER -i "$IFACE" ! -s 100.64.0.0/10 -j DROP
fi
