#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_root

log "=== RESTAURACIÓN DE COOLIFY ==="
log "Busca tus backups en:"
for d in /mnt/backups/coolify /data/coolify/backups; do
  if [ -d "$d" ]; then
    log "  - $d"
    find "$d" -maxdepth 3 -name '*.dmp' -o -maxdepth 3 -name '*.gz' 2>/dev/null | head -n 10 | sed 's/^/      /' || true
  fi
done

BACKUP_FILE="$(ask 'Ruta al archivo de backup (.dmp/.gz) o Enter para cancelar' '')"
if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
  err "Archivo no válido o cancelado."
  exit 1
fi

warn "Se detendrán los contenedores de Coolify durante la restauración."
if [ "$(ask_yes_no '¿Continuar?' 'n')" != "yes" ]; then
  log "Cancelado."
  exit 0
fi

docker stop coolify coolify-redis coolify-realtime coolify-proxy 2>/dev/null || true

if docker inspect coolify-db >/dev/null 2>&1; then
  if [[ "$BACKUP_FILE" == *.gz ]]; then
    zcat "$BACKUP_FILE" | docker exec -i coolify-db pg_restore --verbose --clean --no-acl --no-owner -U coolify -d coolify
  else
    docker exec -i coolify-db pg_restore --verbose --clean --no-acl --no-owner -U coolify -d coolify < "$BACKUP_FILE"
  fi
  log "Base de datos de Coolify restaurada."
else
  warn "No se encontró el contenedor coolify-db. ¿Está Coolify instalado?"
fi

docker start coolify coolify-redis coolify-realtime coolify-proxy 2>/dev/null || true
log "Restauración finalizada. Revisa http://$(hostname):8000"
log "Para restaurar configuración del sistema (SSH, fail2ban, fstab):"
log "   rsync -a /mnt/backups/coolify/config-snapshots/<fecha>/ssh/ /etc/ssh/sshd_config.d/"
log "   rsync -a /mnt/backups/coolify/config-snapshots/<fecha>/fail2ban/ /etc/fail2ban/"
