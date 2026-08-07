# Fase 3 — Tailscale (VPN)

**Script:** `scripts/03-tailscale.sh`

## Qué hace

- Instala Tailscale con la one-liner oficial.
- Une el servidor a tu tailnet con hostname `homelab`, usando:
  - **Auth key** (`tskey-...`): si la pegas en el setup, no requiere navegador.
  - O **login manual**: Tailscale imprime una URL que debes abrir y aceptar en el navegador (un solo paso, sin teclear nada más).
- Habilita DNS de Tailscale (MagicDNS).
- Aplica las reglas UFW de la interfaz `tailscale0`.

## Acceso desde tus otras máquinas

Instala Tailscale y haz `tailscale up` una vez en **cada** equipo:

```bash
# Laptop y PC Personal (cada una)
curl -fsSL https://tailscale.com/install.sh | sh   # o instalador gráfico
sudo tailscale up
```

Resultado: las 3 máquinas se ven por su nombre e IP `100.x.x.x` desde cualquier lugar.

## Configuración recomendada en la consola de Tailscale

En [login.tailscale.com/admin](https://login.tailscale.com/admin):

- **DNS → Enable MagicDNS** (para usar `homelab` en vez de la IP `100.x.x.x`).
- **Machines → homelab → Disable key expiry** (la llave de la máquina no debe expirar, o pierdes acceso sin intervención).

## Verificación

```bash
tailscale status      # homelab y tus equipos en línea
tailscale ip -4       # 100.x.x.x
```

Desde la laptop:

```bash
ssh jose@homelab
```

## Nota

Todo el tráfico viaja cifrado (WireGuard) y el servidor **no está expuesto a Internet**: los escaneos contra tu IP pública no encontrarán nada.
