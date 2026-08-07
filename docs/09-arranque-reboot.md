# Arranque y reinicio del servidor

Cómo se comporta el homelab cuando el HP ProDesk se reinicia, y cómo verificar que todo quedó bien.

## Orden de arranque

```
power on
  │
  ├─ systemd
  │   ├─ sshd            (acceso SSH vía Tailscale una vez la VPN esté)
  │   ├─ tailscaled      (crea la interfaz tailscale0 y la IP 100.98.109.60)
  │   ├─ UFW             (reglas de firewall, arranque temprano)
  │   ├─ fail2ban
  │   ├─ docker          (arranca todos los contenedores con restart policy)
  │   │   ├─ coolify-db, coolify-redis, coolify-realtime
  │   │   ├─ coolify-proxy (Traefik, 80/443)
  │   │   ├─ coolify-sentinel
  │   │   ├─ adguard     (DNS :53 y web :3000 en la IP de Tailscale)
  │   │   └─ coolify     (panel :8000; gestiona el resto vía SSH local)
  │   └─ docker-tailnet-only (bloquea puertos Docker fuera de la VPN)
```

## Qué esperar tras el reinicio

| Momento | Estado |
|---|---|
| 0-10 s | Servidor arranca, Docker levanta contenedores |
| ~1-2 min | Tailscale conecta y crea `tailscale0` |
| 1-3 min | AdGuard queda escuchando en `100.98.109.60:53` (espera a que exista la IP de Tailscale; si Docker arrancó antes, reintenta solo gracias a `restart: unless-stopped`) |
| 2-4 min | Todo operativo: DNS VPN + Coolify + proxy |

> Si Docker intentó arrancar AdGuard antes de que existiera la IP de Tailscale, el bind a `100.98.109.60:53` falla una o dos veces y Docker lo reintenta automáticamente (~1 min de backoff). No hace falta intervenir.

## Verificación rápida

```bash
cd ~/repos/homelab
sudo bash scripts/check-status.sh
```

Salida esperada: todos `[OK]`, `X OK / 0 fallos`.

### Manual

```bash
# Docker y contenedores
docker ps                      # coolify*, adguard Up
# VPN
tailscale ip -4                # 100.98.109.60
tailscale status
# Firewall
sudo ufw status                # active, default deny incoming
# DNS de la VPN
getent hosts test.intellium.lan   # → 100.98.109.60
# Accesos
curl -sI http://127.0.0.1:8000   # Coolify 200
curl -sI http://100.98.109.60:3000  # AdGuard 200
```

## Troubleshooting post-reboot

| Síntoma | Qué hacer |
|---|---|
| `check-status.sh` marca fallo en AdGuard | `sudo docker logs adguard-u9jijqbzculcs53ve9iqobra --tail 30`; si dice `bind ... address already in use` espera 1 min y vuelve a mirar (arrancó antes que Tailscale). |
| No resuelve `*.intellium.lan` | `systemctl status tailscaled`; reinicia Tailscale: `sudo systemctl restart tailscaled`. Luego `tailscale up`. |
| Coolify no responde en :8000 | `sudo docker logs coolify --tail 50`. Si `coolify-db` no arrancó, revisa disco/volúmenes. |
| Puerto 53 ocupado tras reboot | El stub de systemd-resolved usa `127.0.0.53:53` (loopback) — no interfiere. Si algo más usa `0.0.0.0:53`, revisa `ss -tulnp`. |
| El iPhone/otro dispositivo no resuelve | Reinicia la app Tailscale o reactiva el perfil VPN (el split DNS se propaga al reconectar). |

## Persistencia garantizada

- **Docker**: `systemctl enable --now docker` (arranca en boot).
- **Contenedores**: todos con `restart: always` / `unless-stopped` (verificado).
- **Tailscale**: servicio systemd habilitado; hostname `homelab` estable en el tailnet.
- **UFW + Fail2Ban**: habilitados en boot.
- **Datos**: volúmenes Docker (`coolify-*`, `*_adguard-conf`, `*_adguard-work`) — sobreviven reinicios y recreación de contenedores.
- **Parches del SO**: `unattended-upgrades` instala actualizaciones de seguridad automáticamente.
- **Backups**: cron semanal (domingo 02:00) copia config + volúmenes de AdGuard al disco `/mnt/backups`.
