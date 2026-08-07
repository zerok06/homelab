#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_root

HOMELAB_USER="${HOMELAB_USER:-$(detect_user)}"
HOMELAB_HOSTNAME="${HOMELAB_HOSTNAME:-homelab}"
HOMELAB_TIMEZONE="${HOMELAB_TIMEZONE:-America/Lima}"

log "=== FASE 1: Sistema operativo ==="

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get upgrade -y
apt-get install -y openssh-server ufw fail2ban curl wget git rsync gnupg ca-certificates apt-transport-https lsb-release jq unattended-upgrades

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
systemctl enable --now unattended-upgrades 2>/dev/null || true
log "unattended-upgrades: parches de seguridad automáticos activos."

timedatectl set-timezone "$HOMELAB_TIMEZONE"
log "Zona horaria: $HOMELAB_TIMEZONE"

if ! id "$HOMELAB_USER" >/dev/null 2>&1; then
  local_pass="$(ask_secret 'Contraseña para el usuario nuevo (no se muestra): ')"
  if [ -n "$local_pass" ]; then
    useradd -m -s /bin/bash "$HOMELAB_USER"
    echo "$HOMELAB_USER:$local_pass" | chpasswd
    usermod -aG sudo "$HOMELAB_USER"
    log "Usuario $HOMELAB_USER creado con permisos sudo."
  else
    warn "No se creó el usuario (sin contraseña). Se continúa con el usuario actual."
  fi
else
  log "El usuario $HOMELAB_USER ya existe."
fi

hostnamectl set-hostname "$HOMELAB_HOSTNAME"
if ! grep -q "$HOMELAB_HOSTNAME" /etc/hosts; then
  echo "127.0.0.1 $HOMELAB_HOSTNAME" >> /etc/hosts
fi

systemctl enable --now ssh
log "SSH habilitado."
log "FASE 1 completa."
