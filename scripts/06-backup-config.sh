#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_root

log "=== FASE 6: Backups (disco local + config de Coolify) ==="

BACKUP_DIR="${HOMELAB_BACKUP_DIR:-/mnt/backups}"

if ! mountpoint -q "$BACKUP_DIR"; then
  DEVICE="$(ask 'Dispositivo del disco de backups (ej. /dev/sdb1) o Enter para usar directorio local' '')"
  if [ -n "$DEVICE" ] && [ -b "$DEVICE" ]; then
    UUID="$(blkid -s UUID -o value "$DEVICE" 2>/dev/null || true)"
    mkdir -p "$BACKUP_DIR"
    if [ -n "$UUID" ]; then
      if ! grep -q "$BACKUP_DIR" /etc/fstab; then
        echo "UUID=$UUID $BACKUP_DIR ext4 nofail,x-systemd.automount,user 0 2" >> /etc/fstab
        systemctl daemon-reload
      fi
      mount "$BACKUP_DIR" 2>/dev/null || true
      log "Disco montado por UUID en $BACKUP_DIR (no bloquea el arranque si falta)."
    else
      warn "No se pudo leer el UUID de $DEVICE. Monta el disco manualmente."
    fi
  else
    log "Usando directorio local $BACKUP_DIR (sin disco externo)."
    mkdir -p "$BACKUP_DIR"
  fi
else
  log "$BACKUP_DIR ya está montado."
fi
mkdir -p "$BACKUP_DIR/coolify"

SNAP="/usr/local/sbin/homelab-config-snapshot.sh"
cat > "$SNAP" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DEST="/mnt/backups/coolify/config-snapshots/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DEST"
rsync -a --delete /data/coolify/ "$DEST/coolify-data/"
rsync -a /etc/ssh/sshd_config.d/ "$DEST/ssh/" 2>/dev/null || true
rsync -a /etc/fail2ban/ "$DEST/fail2ban/" 2>/dev/null || true
rsync -a /etc/systemd/system/docker-tailnet-only.service "$DEST/systemd/" 2>/dev/null || true
tailscale status > "$DEST/tailscale-status.txt" 2>/dev/null || true
for VOL in $(docker volume ls --format '{{.Name}}' | grep -i adguard || true); do
  mkdir -p "$DEST/adguard-volumes"
  docker run --rm -v "$VOL":/data -v "$DEST/adguard-volumes":/backup alpine:3 tar czf "/backup/$VOL.tar.gz" -C /data . 2>/dev/null || true
done
find /mnt/backups/coolify/config-snapshots -mindepth 1 -maxdepth 1 -type d | sort | head -n -7 | xargs -r rm -rf
EOF
chmod 0755 "$SNAP"

cat > /etc/cron.d/homelab-backup-config <<EOF
SHELL=/bin/bash
0 2 * * 0 root $SNAP
EOF
chmod 0600 /etc/cron.d/homelab-backup-config
log "Snapshot semanal de configuración (domingos 02:00): $SNAP"
log "Se conservan las 7 últimas copias."

log ""
log "FASE 6 completa. Pasos restantes en la interfaz de Coolify (http://$(hostname):8000):"
log "  1. Settings > Backup: activa el backup automático de la DB de Coolify (cron diario)."
log "  2. En cada base de datos desplegada > Backup: crea un backup programado (cron)."
log "  3. Los archivos .dmp quedan en /data/coolify/backups y se copian al USB con el snapshot semanal."
