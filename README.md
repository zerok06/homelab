# Homelab v1 — Intellium

Arquitectura autoalojada en el HP ProDesk. **Todo el acceso es únicamente mediante Tailscale (VPN)**: no se abre ningún puerto en el router y no se expone IP pública.

```
                          Laptop
                             │
                      Tailscale VPN
                             │
              ┌──────────────┴──────────────┐
              │                             │
         PC Personal                  HP ProDesk
                                     Ubuntu Server 24.04 LTS
                                          │
                                   Docker Engine
                                          │
                                   Coolify Platform
```

## Acceso (desde cualquier lugar)

| Recurso | Comando / URL |
|---|---|
| SSH al servidor | `ssh jose@homelab` |
| Panel Coolify | `http://homelab:8000` |
| IP VPN | `tailscale ip -4` (tipo `100.x.x.x`) |

Requisito: Tailscale instalado y conectado en **Laptop y PC Personal** (`tailscale up` una vez en cada equipo).

## Instalación en una sola ejecución

En el HP ProDesk con Ubuntu Server 24.04 recién instalado:

```bash
# En tu laptop: copia la llave SSH (opcional, se puede pegar durante el setup)
ssh-copy-id jose@<ip-del-prodesk>

# En el ProDesk
cd homelab/scripts
sudo bash setup.sh
```

El script te pedirá copiar y pegar los datos interactivos:

1. **Usuario administrador**, **hostname** y **zona horaria**.
2. **Llave pública SSH** (`ssh-ed25519 AAAA...`): si no existe, **no deshabilita el login por contraseña** para no dejarte afuera.
3. **Auth key de Tailscale** (`tskey-...`): si dejas Enter, Tailscale abre una URL de login en el navegador que deberás aceptar manualmente.

> El setup se ejecuta en este orden: `01` base → `03` Tailscale → `02` seguridad → `04` Docker → `05` Coolify. Tailscale va **antes** que la seguridad para que el firewall solo acepte tráfico de la VPN.

Todo queda registrado en `/var/log/homelab-setup.log`. El script es idempotente: si algo falla, reejecútalo.

## Fases

| Fase | Script | Documento |
|---|---|---|
| 1. Sistema operativo | `01-install-base.sh` | [docs/01-sistema-operativo.md](docs/01-sistema-operativo.md) |
| 2. Seguridad | `02-security.sh` | [docs/02-seguridad.md](docs/02-seguridad.md) |
| 3. Tailscale | `03-tailscale.sh` | [docs/03-tailscale.md](docs/03-tailscale.md) |
| 4. Docker | `04-docker.sh` | [docs/04-docker.md](docs/04-docker.md) |
| 5. Coolify | `05-install-coolify.sh` | [docs/05-coolify.md](docs/05-coolify.md) |
| 6. Backups | `06-backup-config.sh` | [docs/06-backups.md](docs/06-backups.md) |
| 7. DNS VPN | `07-setup-vpn-dns.sh` | [docs/07-dns-vpn.md](docs/07-dns-vpn.md) |
| Guía recursos | — | [docs/08-recursos.md](docs/08-recursos.md) |
| Restauración | `99-restore.sh` | [docs/06-backups.md](docs/06-backups.md) |
| Desinstalación | `uninstall.sh` | — |

## Desinstalación

Para revertir todo (Coolify, Docker, Tailscale, UFW, Fail2Ban, SSH, backups):

```bash
cd homelab/scripts
sudo bash uninstall.sh
```

Pide confirmación paso a paso; los datos (volúmenes Docker, `/data/coolify`, `/var/lib/docker`) solo se borran si lo confirmas.

## Backups (resumen)

- **Nativos de Coolify**: cada base de datos desplegada y la propia DB de Coolify se respaldan con cron (archivos `.dmp` en `/data/coolify/backups`).
- **Disco local**: un USB montado en `/mnt/backups` recibe cada domingo (02:00) un snapshot de `/data/coolify` (config + backups) + config de SSH/fail2ban, conservando las últimas 7 copias.
- **Restauración**: `sudo bash scripts/99-restore.sh`.

## Estructura

```
homelab/
├── README.md
├── docs/                  # Guías paso a paso por fase
└── scripts/
    ├── common.sh                       # Funciones compartidas
    ├── setup.sh                        # MASTER: ejecuta todo (interactivo)
    ├── 01-install-base.sh
    ├── 02-security.sh
    ├── 03-tailscale.sh
    ├── 04-docker.sh
    ├── 05-install-coolify.sh
    ├── 06-backup-config.sh
    ├── 07-setup-vpn-dns.sh             # AdGuard Home + dominio intellium.lan
    ├── 99-restore.sh
    ├── uninstall.sh                      # Revierte todo el setup
    └── apply-docker-tailnet-block.sh   # Bloqueo de puertos Docker fuera de la VPN
```

## Reglas de oro

- **Nunca** abras puertos en el router. Todo pasa por Tailscale.
- **Nunca** deshabilites el login por contraseña sin tener una llave SSH instalada.
- **Nunca** expongas Coolify a Internet.
