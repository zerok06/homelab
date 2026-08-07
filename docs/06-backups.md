# Fase 6 — Backups y restauración

**Scripts:** `scripts/06-backup-config.sh` (config) y `scripts/99-restore.sh` (restauración)

## Estrategia

Dos capas, ambas en **disco local** (USB en el ProDesk, montado en `/mnt/backups`):

1. **Backups nativos de Coolify** (bases de datos):
   - En la UI de Coolify, para **cada base de datos desplegada**: pestaña `Backups` → define un cron (ej. `0 2 * * *` = diario 02:00).
   - Coolify también respalda **su propia DB**: `Settings → Backup` → activa el backup automático (cron diario).
   - Los archivos `.dmp` (formato `pg_dump --custom`) quedan en `/data/coolify/backups/<id>/`.
   - Opcionalmente puedes añadir un destino **S3-compatible** para réplica offsite.

2. **Snapshot de configuración** (script + cron):
   - `/usr/local/sbin/homelab-config-snapshot.sh`, ejecutado **domingos 02:00** por `/etc/cron.d/homelab-backup-config`.
   - Copia al USB: `/data/coolify` (config + backups nativos), `sshd_config.d`, fail2ban, y el servicio de bloqueo Docker.
   - Conserva las **últimas 7 copias** en `/mnt/backups/coolify/config-snapshots/<fecha>/`.

## Disco USB

`06-backup-config.sh` te pide el dispositivo (ej. `/dev/sdb1`), lo monta por **UUID** en `/mnt/backups` con `nofail,x-systemd.automount`: si el disco falta, el sistema arranca igual. Si no hay USB, usa `/mnt/backups` como directorio local.

Verifica el montaje y el cron:

```bash
lsblk -f | grep -i ext4
mount | grep /mnt/backups
cat /etc/cron.d/homelab-backup-config
sudo /usr/local/sbin/homelab-config-snapshot.sh && ls /mnt/backups/coolify/config-snapshots/
```

## Restauración de Coolify (máquina nueva o recuperación)

```bash
sudo bash scripts/99-restore.sh
```

1. Te lista los backups disponibles y pide la ruta del `.dmp`.
2. Detiene `coolify`, `coolify-redis`, `coolify-realtime`, `coolify-proxy`.
3. Restaura la DB con `pg_restore --clean --no-acl --no-owner -U coolify -d coolify`.
4. Arranca de nuevo los contenedores.

> Los avisos de `pg_restore` sobre claves foráneas/secuencias suelen ser inofensivos si la estructura base quedó intacta.

## Restauración de configuración del sistema

```bash
# Copia el USB a la máquina nueva y monta /mnt/backups
rsync -a /mnt/backups/coolify/config-snapshots/<fecha>/ssh/ /etc/ssh/sshd_config.d/
rsync -a /mnt/backups/coolify/config-snapshots/<fecha>/fail2ban/ /etc/fail2ban/
rsync -a /mnt/backups/coolify/config-snapshots/<fecha>/systemd/docker-tailnet-only.service /etc/systemd/system/
systemctl daemon-reload
```

## Recordatorio mensual

El snapshot vive en el mismo servidor (disco USB local). Si quieres protección ante robo/incendio, añade una copia offsite (p. ej. `rclone copy /mnt/backups remote:S3-Bucket`) en una fase futura.
