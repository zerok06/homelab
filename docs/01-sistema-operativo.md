# Fase 1 — Sistema operativo (Ubuntu Server 24.04 LTS)

**Script:** `scripts/01-install-base.sh`

## Qué hace

- Actualiza e instala paquetes base: `openssh-server`, `ufw`, `fail2ban`, `curl`, `git`, `rsync`, `gnupg`, etc.
- Configura la **zona horaria**.
- Crea el **usuario administrador** (con `sudo`) si no existe.
- Configura el **hostname** del servidor.
- Habilita y arranca **SSH**.

## Instalación del SO (manual, una vez)

1. Graba Ubuntu Server 24.04 LTS en un USB con Rufus/Ventoy.
2. Arranca el ProDesk desde el USB e instala con:
   - Usuario: `jose` (o el que prefieras)
   - Instalación mínima (sin paquetes extra)
   - **No instalar Docker por snap** durante el instalador (se instalará limpio en la fase 4).
3. Al terminar, conecta el ProDesk a tu red (cable/Ethernet recomendado) y anota su IP local: `ip a`.

## Verificación

```bash
whoami && sudo whoami        # debes tener sudo
cat /etc/os-release | grep VERSION_ID   # 24.04
hostname                     # homelab
timedatectl                  # zona horaria correcta
systemctl status ssh         # active (running)
```
