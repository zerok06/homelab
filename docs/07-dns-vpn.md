# Fase 7 — DNS de la VPN (AdGuard Home + `intellium.lan`)

**Script:** `scripts/07-setup-vpn-dns.sh`

## Problema que resuelve

Coolify asigna por defecto dominios tipo `n8n-<id>.<ip-pública>.sslip.io`, que resuelven a tu IP pública (inaccesible, no hay puertos abiertos). La solución es un **DNS local dentro de la VPN** con tu propio dominio interno:

```
n8n.intellium.lan   → 100.98.109.60 (ProDesk, solo dentro de la VPN)
gitea.intellium.lan → 100.98.109.60
```

## Cómo funciona

1. **AdGuard Home** (desplegado en Coolify) resuelve `*.intellium.lan` → IP de Tailscale del servidor (rewrite).
2. **Split DNS de Tailscale**: solo `intellium.lan` se consulta a AdGuard; el resto usa DNS normal.
3. **Coolify (Traefik)** enruta por Host: `n8n.intellium.lan` → contenedor de n8n.

## Paso 1 — Desplegar AdGuard Home en Coolify

> Importante: publica los puertos **solo en la IP de Tailscale** (`100.98.109.60:53:53`, `100.98.109.60:3000:3000`). Si los publicas en `0.0.0.0:53`, chocan con el stub de `systemd-resolved` (127.0.0.53:53) y el contenedor no arranca.

1. Coolify → **Services → New** → plantilla **AdGuard Home** → Deploy.
2. En **Ports Mappings** cambia el bind a la IP de Tailscale:
   - `100.98.109.60:53:53/tcp`
   - `100.98.109.60:53:53/udp`
   - `100.98.109.60:3000:3000/tcp`
3. Coolify arranca el contenedor con `-c /opt/adguardhome/conf/AdGuardHome.yaml`.

## Paso 2 — Configuración inicial de AdGuard

Opcional A (web): abre `http://100.98.109.60:3000`, asiste al wizard y crea el admin.

Opcional B (headless, la que usa este homelab): la API `/control/install` a veces responde 302 sin instalar, así que se escribe el archivo de configuración directamente:

```bash
# Dentro del volumen de Coolify
CONF=/var/lib/docker/volumes/<servicio>_adguard-conf/_data/AdGuardHome.yaml
# Contenido mínimo (solo parte clave):
#   http.address: 0.0.0.0:3000
#   users: [admin, <hash bcrypt>]
#   dns.bind_hosts: [0.0.0.0], dns.port: 53
#   schema_version: 29
#   upstream_dns + bootstrap_dns
chown nobody:nogroup $CONF && chmod 0600 $CONF
docker restart <contenedor-adguard>
```

Genera el hash bcrypt con Python (`crypt.crypt('pass', crypt.mksalt(crypt.METHOD_BLOWFISH))`).

## Paso 3 — DNS rewrite

```bash
cd ~/repos/homelab
sudo bash scripts/07-setup-vpn-dns.sh   # pide usuario/contraseña de AdGuard
```

Añade `*.intellium.lan → <IP de Tailscale>` vía API (o manual: **Filters → DNS rewrites**).

## Paso 4 — Split DNS en Tailscale

Con API key (recomendado, el script lo hace si defines `HOMELAB_TAILSCALE_APIKEY`):

```bash
HOMELAB_TAILSCALE_APIKEY=tskey-api-... sudo bash scripts/07-setup-vpn-dns.sh
```

Endpoint correcto (ojo: **`split-dns`**, no `splitnameservers`):

```bash
curl -X PUT "https://api.tailscale.com/api/v2/tailnet/<tailnet>/dns/split-dns" \
  -u ":tskey-api-..." -H "Content-Type: application/json" \
  -d '{"intellium.lan":["100.98.109.60"]}'
```

El tailnet es el sufijo MagicDNS (ej. `taile6868c.ts.net`), visible con `tailscale status`.

Manual (alternativa): [login.tailscale.com/admin](https://login.tailscale.com/admin) → **DNS → Nameservers → Add nameserver** → `100.98.109.60` → **Only domains** → `intellium.lan`.

## Paso 5 — Asignar dominios en Coolify

En cada recurso (**Configuration → General → Domain**): `n8n.intellium.lan` (quita la URL sslip.io) y redeploy. El proxy publica 80/443 solo dentro de la VPN.

## Verificación

```bash
nslookup n8n.intellium.lan      # → 100.98.109.60 (desde tu laptop)
http://n8n.intellium.lan        # en el navegador
```

## Troubleshooting

| Síntoma | Causa / solución |
|---|---|
| Contenedor no arranca, `bind host port 0.0.0.0:53: address already in use` | Stub de systemd-resolved. Publica en la IP de Tailscale (`100.x:53`) en vez de `0.0.0.0`. |
| AdGuard dice "first launch" aunque escribí el archivo | Coolify usa `-c .../AdGuardHome.yaml` (con "Home"); nombre correcto y `schema_version: 29`. |
| `nslookup` no resuelve | Split DNS no aplicado: comprueba el nameserver en la consola de Tailscale y que el dispositivo use el DNS de la red. |
| El móvil no resuelve | Reinstala el perfil VPN / `accept-dns=true`. |
| El recurso carga en blanco | En Coolify, el dominio sin `http://` y el servicio debe escuchar en el puerto esperado. |

## Seguridad y notas

- Puertos 53/80/443 solo responden a tu tailnet (UFW + regla `DOCKER-USER`).
- `intellium.lan` no existe en internet: solo se resuelve dentro de tu VPN.
- **Cambia la contraseña de admin de AdGuard** (default `admin`/`admin123`) en su panel.
- La API de Coolify quedó habilitada y se creó un token (`homelab-cli`); revócalo en **Coolify → Keys & Tokens** si no lo vas a usar.
- No se usa HTTPS interno: el tráfico ya va cifrado por WireGuard.
