# Fase 7 — DNS de la VPN (AdGuard Home + `intellium.lan`)

**Script:** `scripts/07-setup-vpn-dns.sh`

## Problema que resuelve

Coolify asigna por defecto dominios tipo `n8n-<id>.<ip-pública>.sslip.io`. Ese DNS resuelve a tu **IP pública**, que no responde (no hay puertos abiertos), así que dentro de la VPN no carga.

La solución es un **DNS local en la VPN** con tu propio dominio interno:

```
n8n.intellium.lan   → 100.98.109.60 (ProDesk, solo dentro de la VPN)
gitea.intellium.lan → 100.98.109.60
```

## Cómo funciona

1. **AdGuard Home** (desplegado en Coolify) hace de DNS: rewrite de `*.intellium.lan` → IP de Tailscale del servidor.
2. **Split DNS de Tailscale**: solo los subdominios `intellium.lan` se consultan a AdGuard; todo lo demás usa los resolvers normales de tu dispositivo.
3. **Coolify** enruta por Host: `n8n.intellium.lan` llega al proxy y de ahí al contenedor de n8n.

## Paso 1 — Desplegar AdGuard Home

1. Coolify → **Services → New** → plantilla **AdGuard Home** → Deploy.
2. Puertos: `53` UDP y TCP (DNS) y `3000` (panel admin).
3. Abre `http://100.98.109.60:3000`, crea la contraseña de admin.

## Paso 2 — Configurar DNS rewrite (script o manual)

```bash
cd homelab/scripts
sudo bash 07-setup-vpn-dns.sh
```

Te pide usuario/contraseña de AdGuard y agrega el rewrite `*.intellium.lan → <IP-Tailscale>` vía API.

Manual (alternativo): en AdGuard Home → **Filters → DNS rewrites → Add** → dominio `*.intellium.lan`, destino `<IP de Tailscale del servidor>`.

## Paso 3 — Split DNS en Tailscale (manual, una vez)

1. [login.tailscale.com/admin](https://login.tailscale.com/admin)
2. **DNS → Nameservers → Add nameserver** → IP de Tailscale del ProDesk (ej. `100.98.109.60`).
3. Modo **Only domains** → añade `intellium.lan`.
4. Guarda. (MagicDNS debe estar activo.)

## Paso 4 — Asignar dominios en Coolify

En cada recurso (**Configuration → General → Domain**):

```
n8n.intellium.lan
```

Quita la URL sslip.io que trae por defecto. El proxy de Coolify publica 80/443 solo dentro de la VPN.

## Verificación

```bash
# Desde tu laptop (con Tailscale conectado)
nslookup n8n.intellium.lan     # debe dar 100.98.109.60
ping n8n.intellium.lan
```

Y en el navegador: `http://n8n.intellium.lan`.

## Troubleshooting

| Síntoma | Causa / solución |
|---|---|
| `nslookup` no resuelve | El nameserver del split DNS no está aplicado: activa MagicDNS y añade `intellium.lan` en Nameservers. |
| Resuelve con la IP pública del router | AdGuard devuelve el rewrite mal configurado; revisa el destino en **DNS rewrites**. |
| El móvil no lo resuelve | En la app Tailscale, asegúrate de aceptar el DNS de la red (o reinstala el perfil de VPN). |
| Puerto 53 ocupado | Otro servicio lo usa; cambia el bind de AdGuard (p. ej. `127.0.0.1:53` no sirve para otros equipos; usa la IP de Tailscale). |
| El recurso carga pero en blanco | Coolify: el dominio debe ir sin `http://` y el servicio debe escuchar en el puerto que espera el proxy. |

## Seguridad

- Los puertos 53/80/443 solo responden a tu tailnet (UFW + regla `DOCKER-USER`).
- `intellium.lan` no existe en internet: solo se resuelve dentro de tu VPN.
- No se usa HTTPS interno: el tráfico ya va cifrado por WireGuard.
