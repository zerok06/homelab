#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_root

cat <<'BANNER'
============================================================
   DESINSTALACIÓN Homelab v1 - Intellium
   Elimina o revierte TODO lo que hizo setup.sh
   (Coolify, Docker, Tailscale, UFW, Fail2Ban, SSH, backups)
============================================================
BANNER

warn "Esto es DESTRUCTIVO. Se pedirá confirmación por cada paso."
if [ "$(ask_yes_no '¿Continuar con la desinstalación?' 'n')" != "yes" ]; then
  log "Cancelado."
  exit 0
fi

confirm() {
  local msg="$1"
  [ "$(ask_yes_no "$msg" 'n')" = "yes" ]
}

DID_ANY="no"

# ---------- 1. Coolify ----------
if confirm '1) ¿Detener y eliminar Coolify (contenedores + /data/coolify)?'; then
  DID_ANY="yes"
  if [ -f /data/coolify/source/docker-compose.yml ]; then
    cd /data/coolify/source
    docker compose down 2>/dev/null || true
  fi
  docker stop coolify coolify-redis coolify-realtime coolify-proxy coolify-db 2>/dev/null || true
  docker rm coolify coolify-redis coolify-realtime coolify-proxy coolify-db 2>/dev/null || true
  if confirm '   ¿Eliminar también los volúmenes de datos de Docker y /data/coolify? (se pierden backups)'; then
    docker volume ls --format '{{.Name}}' | grep -E '^coolify' | xargs -r docker volume rm -f 2>/dev/null || true
    rm -rf /data/coolify
    log "Coolify eliminado (con datos)."
  else
    rm -f /data/coolify/source/docker-compose.yml 2>/dev/null || true
    log "Coolify detenido. /data/coolify y volúmenes conservados."
  fi
fi

# ---------- 2. Bloqueo Docker/Tailnet ----------
if confirm '2) ¿Quitar el bloqueo de puertos Docker solo-VPN (docker-tailnet-only)?'; then
  DID_ANY="yes"
  systemctl disable --now docker-tailnet-only.service 2>/dev/null || true
  rm -f /etc/systemd/system/docker-tailnet-only.service
  rm -f /usr/local/sbin/apply-docker-tailnet-block.sh
  systemctl daemon-reload
  log "Bloqueo docker-tailnet-only eliminado."
fi

# ---------- 3. SSH hardening ----------
if confirm '3) ¿Revertir endurecimiento SSH (volver a permitir contraseñas y root)?'; then
  DID_ANY="yes"
  rm -f /etc/ssh/sshd_config.d/homelab-hardening.conf
  sshd -t && systemctl reload ssh
  log "SSH revertido a configuración por defecto."
fi

# ---------- 4. Fail2Ban ----------
if confirm '4) ¿Eliminar Fail2Ban (config + paquete)?'; then
  DID_ANY="yes"
  rm -f /etc/fail2ban/jail.local
  systemctl disable --now fail2ban 2>/dev/null || true
  apt-get purge -y fail2ban 2>/dev/null || true
  apt-get autoremove -y 2>/dev/null || true
  log "Fail2Ban eliminado."
fi

# ---------- 5. UFW ----------
if confirm '5) ¿Resetear UFW (eliminar todas las reglas y desactivarlo)?'; then
  DID_ANY="yes"
  ufw --force reset 2>/dev/null || true
  ufw --force disable 2>/dev/null || true
  systemctl disable --now ufw 2>/dev/null || true
  log "UFW desactivado y reglas eliminadas (no se desinstala el paquete)."
fi

# ---------- 6. Tailscale ----------
if confirm '6) ¿Desconectar y eliminar Tailscale del servidor?'; then
  DID_ANY="yes"
  tailscale down 2>/dev/null || true
  apt-get purge -y tailscale 2>/dev/null || true
  if confirm '   ¿Eliminar también el estado de Tailscale (/var/lib/tailscale)?'; then
    rm -rf /var/lib/tailscale
  fi
  log "Tailscale eliminado."
fi

# ---------- 7. Docker ----------
if confirm '7) ¿Eliminar Docker Engine + Compose plugin (paquetes + repo apt)?'; then
  DID_ANY="yes"
  systemctl disable --now docker 2>/dev/null || true
  apt-get purge -y --auto-remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
  rm -f /etc/apt/sources.list.d/docker.list
  rm -f /etc/apt/keyrings/docker.asc
  if confirm '   ¿Eliminar los datos de Docker (/var/lib/docker)? (se pierden TODOS los contenedores/volúmenes)'; then
    rm -rf /var/lib/docker
  fi
  gpasswd -d "$(detect_user)" docker 2>/dev/null || true
  groupdel docker 2>/dev/null || true
  log "Docker eliminado."
fi

# ---------- 8. Backups / base ----------
if confirm '8) ¿Quitar cron de backups y script de snapshot?'; then
  DID_ANY="yes"
  rm -f /etc/cron.d/homelab-backup-config
  rm -f /usr/local/sbin/homelab-config-snapshot.sh
  log "Cron y script de snapshot eliminados."
fi

if [ "$DID_ANY" = "no" ]; then
  log "No se realizó ningún cambio."
  exit 0
fi

log ""
log "=== DESINSTALACIÓN FINALIZADA ==="
log "Se conservaron intactos: usuario $(detect_user), hostname y zona horaria."
log "Para revertir también el hostname: sudo hostnamectl set-hostname <original>"
log "Paquetes base (curl, git, rsync, openssh-server, ufw) se mantienen instalados."
log "Reinicia el servidor: sudo reboot"
