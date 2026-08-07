#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_root

HOMELAB_USER="${HOMELAB_USER:-$(detect_user)}"

log "=== FASE 4: Docker Engine + Compose plugin ==="

if is_installed snap; then
  if snap list docker >/dev/null 2>&1; then
    snap remove docker 2>/dev/null || true
    warn "Docker (snap) eliminado. Coolify no soporta snap."
  fi
fi

export DEBIAN_FRONTEND=noninteractive

install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.asc ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
fi

CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
ARCH="$(dpkg --print-architecture)"
cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $CODENAME stable
EOF

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker
usermod -aG docker "$HOMELAB_USER"
log "Usuario $HOMELAB_USER agregado al grupo docker (vuelve a iniciar sesión para usarlo sin sudo)."

systemctl daemon-reload
if systemctl is-enabled docker-tailnet-only.service >/dev/null 2>&1; then
  systemctl start docker-tailnet-only.service || true
  log "docker-tailnet-only aplicado: puertos publicados solo vía Tailscale."
fi

docker info >/dev/null 2>&1 && log "Docker Engine OK"
log "Docker Compose: $(docker compose version)"
log "FASE 4 completa."
