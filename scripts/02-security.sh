#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_root

HOMELAB_USER="${HOMELAB_USER:-$(detect_user)}"
HOMELAB_SSH_PUBKEY="${HOMELAB_SSH_PUBKEY:-}"

log "=== FASE 2: Seguridad (UFW + Fail2Ban + SSH por llaves) ==="

ufw --force disable >/dev/null 2>&1 || true
ufw default deny incoming
ufw default allow outgoing
ufw allow 41641/udp comment 'Tailscale (conexiones directas)'
ensure_tailscale0_rules
ufw allow from 172.16.0.0/12 to any port 22 proto tcp comment 'Coolify: SSH al host desde Docker'
ufw allow from 10.0.0.0/8 to any port 22 proto tcp comment 'Coolify: SSH al host desde Docker'
ufw --force enable
ufw status verbose | tee -a "$HOMELAB_LOG"

cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
EOF
systemctl enable --now fail2ban
log "Fail2Ban activo (jail sshd)."

SSH_DIR="/home/$HOMELAB_USER/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTH_KEYS"
chown -R "$HOMELAB_USER:$HOMELAB_USER" "$SSH_DIR"

if [ -n "$HOMELAB_SSH_PUBKEY" ]; then
  grep -qF "$HOMELAB_SSH_PUBKEY" "$AUTH_KEYS" 2>/dev/null || echo "$HOMELAB_SSH_PUBKEY" >> "$AUTH_KEYS"
  log "Llave pública agregada a $AUTH_KEYS."
fi

HAS_KEY="$(grep -E '^ssh-(rsa|ed25519|ecdsa) ' "$AUTH_KEYS" 2>/dev/null | head -n1 || true)"
if [ -z "$HAS_KEY" ]; then
  echo ""
  warn "No hay ninguna llave SSH configurada todavía."
  if [ -z "$HOMELAB_SSH_PUBKEY" ]; then
    PK="$(ask_secret 'Pega tu llave pública SSH (ssh-ed25519 ...) [Enter para omitir]: ')"
    if [ -n "$PK" ]; then
      echo "$PK" >> "$AUTH_KEYS"
      HAS_KEY="$PK"
    fi
  fi
fi

if [ -n "$HAS_KEY" ]; then
  cat > /etc/ssh/sshd_config.d/homelab-hardening.conf <<'EOF'
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
ChallengeResponseAuthentication no
EOF
  chmod 600 /etc/ssh/sshd_config.d/homelab-hardening.conf
  sshd -t && systemctl reload ssh
  log "SSH: solo por llaves, login de root por contraseña deshabilitado (llaves OK, requerido por Coolify)."
else
  warn "NO se deshabilitó el login por contraseña (no hay llaves configuradas). Copia tu llave y reejecuta el script."
fi

install -m 0755 /dev/null /usr/local/sbin/apply-docker-tailnet-block.sh 2>/dev/null || true
cp "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/apply-docker-tailnet-block.sh" /usr/local/sbin/apply-docker-tailnet-block.sh
chmod 0755 /usr/local/sbin/apply-docker-tailnet-block.sh

cat > /etc/systemd/system/docker-tailnet-only.service <<'EOF'
[Unit]
Description=Bloquear puertos publicados de Docker fuera de la red Tailscale
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/apply-docker-tailnet-block.sh
Restart=on-failure
RestartSec=30
StartLimitIntervalSec=0

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable docker-tailnet-only.service
if systemctl -q is-active docker 2>/dev/null; then
  systemctl start docker-tailnet-only.service
  log "Puertos publicados de Docker restringidos a la red Tailscale."
else
  log "docker-tailnet-only activado; se aplicará cuando Docker inicie (fase 4)."
fi

log "FASE 2 completa."
warn "Mantén abierta tu sesión SSH. Verifica la conexión por Tailscale antes de cerrarla."
