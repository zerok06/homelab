# Fase 4 — Docker Engine + Compose plugin

**Script:** `scripts/04-docker.sh`

## Qué hace

- **Elimina Docker de snap** si existe (Coolify no lo soporta).
- Agrega el **repositorio oficial de Docker** (apt) con firma GPG.
- Instala **únicamente**:

  ```
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  ```

- Habilita el daemon, agrega tu usuario al grupo `docker` y aplica el bloqueo de puertos de la VPN (`docker-tailnet-only`).

> Nada más: **no** se instala Portainer ni otras herramientas. Docker es solo el runtime de Coolify.

## Verificación

```bash
docker info
docker compose version
systemctl status docker
```

Para usar `docker` sin `sudo` desde tu usuario, **vuelve a iniciar sesión** (logout/login) para que el grupo `docker` surta efecto.

## Nota sobre el firewall y Docker

Docker publica puertos (8000/80/443) con sus propias reglas iptables que **ignoran UFW**. Por eso `apply-docker-tailnet-block.sh` inserta una regla en la cadena `DOCKER-USER` que descarta el tráfico entrante hacia contenedores que no provenga de `100.64.0.0/10` (la red de Tailscale). Así Coolify y sus apps solo son accesibles desde tu VPN, ni siquiera desde tu propia LAN.

Si algún día quieres publicar una app a Internet (p. ej. con Cloudflare + dominio), elimina la regla con `sudo systemctl disable --now docker-tailnet-only.service`.
