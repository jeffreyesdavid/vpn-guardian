# 🛡️ VPN Guardian

A personal security agent that watches your internet connection, catches VPN drops and leaks, and alerts you on your Mac and your phone. Built entirely with free tools.

> Most people trust their VPN blindly. VPN Guardian checks that it's actually working.

## What it does (v1)

- **VPN drop alerts:** notifies you the moment your VPN disconnects and your real IP is exposed
- **IP leak detection:** catches when the VPN says "connected" but websites still see your real IP
- **Route leak detection:** catches when traffic is leaving outside the VPN tunnel
- **Location tracking:** shows the city and country websites think you're in, and alerts when it changes
- **Network awareness:** alerts on Wi-Fi changes and going offline, and logs DNS changes
- **Phone alerts:** free push notifications through [ntfy.sh](https://ntfy.sh)
- **Full log** at `~/.vpn-guardian/log.txt`

## Website

The landing page lives in `docs/`. Turn it on in **Settings → Pages → Deploy from branch → main → /docs**, and it goes live at `https://jeffreyesdavid.github.io/vpn-guardian/`.

## Quick start (macOS)

```bash
git clone https://github.com/jeffreyesdavid/vpn-guardian.git
cd vpn-guardian
chmod +x vpn-guardian.sh
./vpn-guardian.sh
```

Run it once with your VPN **off** so it learns your real IP, then turn your VPN on.

### Optional: phone alerts

```bash
mkdir -p ~/.vpn-guardian
cp config.example ~/.vpn-guardian/config
```

Install the **ntfy** app, subscribe to a long random topic name, and put that name in `NTFY_TOPIC` in the config.

## How it works

Every 30 seconds it checks:

| Check | How |
|---|---|
| Is a VPN tunnel up? | Looks for `utun`/`ipsec`/`ppp`/`wg` interfaces with an IPv4 address |
| What IP and location do sites see? | Free lookup from `am.i.mullvad.net` (falls back to ipify) |
| Is traffic using the tunnel? | `route get` shows which interface internet traffic leaves through |
| Did anything change? | Compares against the last check and alerts only on changes |

## Roadmap

- [x] **v0:** VPN drop, IP leak, and route leak alerts
- [x] **v1:** location tracking + free phone alerts (ntfy)
- [ ] **v2:** DNS leak test, IPv6/WebRTC leak checks, risky Wi-Fi warnings
- [ ] **v3:** VPN app auditor that grades installed VPNs A–F (owner, country, permissions, trackers)
- [ ] **v4:** self-hosted WireGuard on a Raspberry Pi or free-tier cloud server, with server rotation
- [ ] **v5:** AI layer with [Ollama](https://ollama.com) (runs locally, free) that explains alerts in plain English
- [ ] **v6:** home network watch with Pi-hole + CrowdSec, and a dashboard

## Free tools this builds on

WireGuard · Tailscale/Headscale · Mullvad leak check · ntfy · Pi-hole · LuLu · CrowdSec · Ollama

## Limitations

- macOS only for now
- Tailscale and similar mesh tools count as VPN tunnels
- Split-tunnel VPNs will show as route leaks (that's by design: it tells you some traffic is outside the tunnel)

## License

MIT
