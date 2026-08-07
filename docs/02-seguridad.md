# Fase 2 — Seguridad (UFW + Fail2Ban + SSH por llaves)

**Script:** `scripts/02-security.sh`

> Se ejecuta **después** de la fase Tailscale para que el firewall solo acepte tráfico de la VPN.

## Qué hace

### UFW (Uncomplicated Firewall)

- `default deny incoming` / `default allow outgoing`.
- Permite la interfaz `tailscale0` (acceso entrante solo por VPN).
- Permite UDP `41641` (conexiones directas de Tailscale).
- **Nada más entra**. Sin abrir puertos del router.

### Fail2Ban

- Jail `sshd` con `backend = systemd`, 5 intentos fallidos → baneo de 1 hora.

### SSH por llaves (con protección anti lockout)

1. Agrega tu llave pública a `~/.ssh/authorized_keys` (la pegaste en el setup o la pasas por `HOMELAB_SSH_PUBKEY`).
2. **Solo si existe al menos una llave**, aplica el endurecimiento:

   ```
   PasswordAuthentication no
   PermitRootLogin no
   PubkeyAuthentication yes
   ```

3. Si no hay llaves, **no deshabilita la contraseña** y te avisa, para que no te quedes fuera del servidor.

### Puertos Docker solo vía VPN

Docker publica puertos (8000/80/443 de Coolify) en todas las interfaces y **se salta UFW**. Para que esos puertos tampoco sean accesibles desde tu LAN (solo desde Tailscale), se instala:

- `/usr/local/sbin/apply-docker-tailnet-block.sh` — agrega una regla en la cadena `DOCKER-USER` de iptables: bloquea todo el tráfico entrante a contenedores que no venga de la red `100.64.0.0/10`.
- Servicio `docker-tailnet-only.service` que reaplica la regla en cada arranque.

## Verificación

```bash
sudo ufw status verbose        # default deny incoming + tailscale0 ALLOW
sudo fail2ban-client status sshd
sudo systemctl status docker-tailnet-only.service
ssh -o PasswordAuthentication=no jose@homelab   # debe entrar solo con llave
```

## Restaurar acceso si te quedas fuera

Desde la consola física del ProDesk:

```bash
sudo rm /etc/ssh/sshd_config.d/homelab-hardening.conf
sudo systemctl reload ssh
```
