#!/usr/bin/env bash
systemctl -q is-active tailscaled 2>/dev/null || exit 0
for _ in $(seq 1 45); do
  IP="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
  case "$IP" in
    100.*) exit 0 ;;
  esac
  sleep 2
done
exit 0
