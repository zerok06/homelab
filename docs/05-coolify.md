# Fase 5 — Coolify

**Script:** `scripts/05-install-coolify.sh`

## Qué hace

- Instala **Coolify v4** con el instalador oficial (`cdn.coollabs.io/coolify/install.sh`).
- Usa **PostgreSQL** por defecto (la DB propia de Coolify).
- Detecta Docker ya instalado (fase 4) y crea el directorio de datos `/data/coolify`.

## Qué es Coolify

- Panel de administración y **gestor de Docker** (imágenes, contenedores, redes, volúmenes).
- **Gestor Docker Compose**: despliega servicios/databases desde UI.
- **Gestor Git**: integración con GitHub/GitLab/Bitbucket para **deploy automático** en cada push.
- **Variables de entorno** por aplicación.
- **Backups** nativos de bases de datos.

No instala Portainer: Coolify lo reemplaza por completo.

## Primer acceso

```bash
# Desde tu laptop (con Tailscale)
http://homelab:8000
```

Crea tu cuenta de administrador en el primer arranque. En `Settings → Instance` puedes cambiar el puerto, pero 8000 sobre la VPN es suficiente.

## Uso rápido

1. **Añadir servidor**: en `Servers → Localhost` (usa el servidor local; Coolify ya tiene acceso a Docker).
2. **Desplegar**: `Applications → New` (Git/GitHub/Public repo) o `Databases → New` (Postgres/MySQL/Mongo/Redis).
3. **Deploy automático**: conecta un repo de GitHub y habilita webhooks.
4. **Dominio**: como todo es interno, accede por `http://homelab:8000` o por la IP de Tailscale del servicio (`http://<ip-de-prodesk>:<puerto>`).

## Verificación

```bash
docker ps                     # coolify, coolify-db, coolify-proxy, etc.
tailscale status              # tú y el ProDesk en línea
```

## Seguridad

- **Nunca expongas Coolify a Internet.** El acceso es únicamente `http://homelab:8000` por VPN.
- No se configura SSL interno: el tráfico ya viaja cifrado por WireGuard dentro de Tailscale.
