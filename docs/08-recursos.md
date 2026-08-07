# Guía rápida — Desplegar un recurso en Coolify

Cómo se accede a los servicios dentro de tu VPN y qué hay que tocar (y qué **no**).

## Regla de oro

> **El DNS ya está resuelto para todo.** La regla wildcard `*.intellium.lan` (AdGuard + split-dns de Tailscale) cubre **cualquier subdominio presente o futuro**. Nunca agregas nada en AdGuard ni en Tailscale al crear un servicio.
> Solo defines el **dominio dentro de Coolify** y su reverse proxy (Traefik) se encarga del resto.

## Flujo (3 pasos) — servicio web nuevo

1. **Coolify → Services (o Applications) → New** → elige el template/repo.
2. **Configuration → General → Domain**: escribe `nombre.intellium.lan`
   - Sin `http://`, sin puerto.
   - Ej: `gitea.intellium.lan`, `grafana.intellium.lan`.
3. **Deploy / Redeploy**.

Acceso desde cualquier dispositivo con Tailscale: `http://nombre.intellium.lan`.

> Si dejas el campo **Domain vacío**, Coolify genera uno automático usando el *Wildcard Domain* del servidor (ya configurado en `intellium.lan`), con formato `https://<recurso>-<uuid>.intellium.lan`. Funciona, pero los nombres llevan UUID; el método bonito es escribir el nombre a mano (paso 2).

## ¿Y si el servicio no tiene interfaz web?

Bases de datos o servicios sin web UI:
- Se acceden por la IP de Tailscale del servidor y su puerto: `100.98.109.60:<puerto>`.
- Para conectarte desde una app, usa la IP `100.98.109.60` (o el hostname `homelab`) y el puerto publicado.
- El puerto 80/443 (proxy) no es necesario para estos.

## ¿Quién enruta?

| Capa | Qué hace | Configuración |
|---|---|---|
| **DNS** (AdGuard + Tailscale) | `*.intellium.lan` → `100.98.109.60` | Ya hecha, no se toca |
| **Reverse proxy** (Traefik en Coolify) | Recibe en `100.98.109.60:80` y enruta por `Host` | Se actualiza solo al redeploy |
| **Firewall** (UFW + iptables) | Solo permite tu tailnet a 80/443/53 | Ya hecha, no se toca |

## Recursos actuales

| Servicio | Dominio | Estado |
|---|---|---|
| AdGuard Home | `http://100.98.109.60:3000` (admin) | ✅ corriendo (DNS en `:53`) |
| Coolify | `http://100.98.109.60:8000` | ✅ corriendo |

> n8n se eliminó para dejar la base limpia; se recreará cuando lo necesites (mismo flujo de 3 pasos).

## Sobre el reverse proxy

**No necesitas instalar ningún reverse proxy aparte** (Traefik, Nginx Proxy Manager, Caddy...). Coolify ya trae **Traefik** como proxy integrado (`coolify-proxy`, escucha en `80/443`). Al asignar un dominio a un recurso, Coolify genera las reglas de enrutamiento automáticamente en cada deploy.

Por eso todos tus servicios pueden vivir en la **misma IP y el mismo puerto** (`100.98.109.60:80`): Traefik decide el contenedor según el `Host` que pide el navegador.

## HTTPS opcional en la VPN (futuro)

Si algún día quieres `https://n8n.intellium.lan` con certificado válido **sin** abrir puertos ni comprar dominio, Tailscale ofrece **Tailscale Serve/HTTPS**:
- En el servidor: `sudo tailscale serve --bg http://127.0.0.1:80` (o apunta al puerto del servicio).
- Tailscale emite un certificado para `n8n.homelab.<tailnet>.ts.net` automáticamente.
- No lo implementamos aún: el http por WireGuard ya es seguro. Queda como mejora futura.

## Notas

- **Sin HTTPS interno**: el tráfico va cifrado por WireGuard. No configures Let's Encrypt para `intellium.lan` (no existe en internet; el certificado fallaría).
- Si un servicio necesita exponerse a internet algún día, tendrás que abrir puertos en el router y usar un dominio público real — **fuera del alcance de este homelab**.
