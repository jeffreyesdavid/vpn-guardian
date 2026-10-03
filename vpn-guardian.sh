#!/bin/bash
# ------------------------------------------------------------
# VPN Guardian v1 (macOS)
# A personal security agent that watches your connection,
# catches VPN drops and leaks, and alerts your Mac and phone.
#
# Run:    chmod +x vpn-guardian.sh && ./vpn-guardian.sh
# Stop:   Ctrl+C
# Log:    ~/.vpn-guardian/log.txt
# Config: ~/.vpn-guardian/config  (see README)
#
# Start once with your VPN OFF so it learns your real IP.
# ------------------------------------------------------------

VERSION="1.0"
DIR="$HOME/.vpn-guardian"
LOG="$DIR/log.txt"
REAL_IP_FILE="$DIR/real_ip"
CONFIG="$DIR/config"
mkdir -p "$DIR"

# Defaults (override in ~/.vpn-guardian/config)
INTERVAL=30          # seconds between checks
NTFY_TOPIC=""        # set to a long random name to get phone alerts via ntfy.sh
NTFY_SERVER="https://ntfy.sh"
[ -f "$CONFIG" ] && . "$CONFIG"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S')  $1" | tee -a "$LOG"; }

# --- Alerts: Mac notification + optional phone push -------------
notify() {
  log "ALERT: $1"
  osascript -e 'on run argv' \
            -e 'display notification (item 1 of argv) with title "VPN Guardian" sound name "Basso"' \
            -e 'end run' "$1" >/dev/null 2>&1
  if [ -n "$NTFY_TOPIC" ]; then
    curl -s --max-time 5 -H "Title: VPN Guardian" -H "Tags: shield" \
         -d "$1" "$NTFY_SERVER/$NTFY_TOPIC" >/dev/null 2>&1
  fi
}

# --- What the world sees (free check from Mullvad, no account) --
json_field() {  # json_field <json> <key>
  echo "$1" | sed -n "s/.*\"$2\": *\"\([^\"]*\)\".*/\1/p"
}

lookup_public() {
  local j
  j=$(curl -s --max-time 6 https://am.i.mullvad.net/json)
  PUB_IP=$(json_field "$j" ip)
  PUB_CITY=$(json_field "$j" city)
  PUB_COUNTRY=$(json_field "$j" country)
  PUB_ORG=$(json_field "$j" organization)
  if [ -z "$PUB_IP" ]; then  # fallback if Mullvad is unreachable
    PUB_IP=$(curl -s --max-time 5 https://api.ipify.org)
    PUB_CITY=""; PUB_COUNTRY=""; PUB_ORG=""
  fi
  if [ -n "$PUB_COUNTRY" ]; then
    PUB_LOC="${PUB_CITY:+$PUB_CITY, }$PUB_COUNTRY"
  else
    PUB_LOC="unknown location"
  fi
}

# --- Local network state -----------------------------------------
vpn_interfaces() {
  for iface in $(ifconfig -l); do
    case "$iface" in
      utun*|ipsec*|ppp*|tun*|wg*)
        ifconfig "$iface" 2>/dev/null | grep -q "inet [0-9]" && echo "$iface" ;;
    esac
  done
}

is_tunnel() {
  case "$1" in utun*|ipsec*|ppp*|tun*|wg*) return 0 ;; *) return 1 ;; esac
}

route_iface() {
  route -n get 1.1.1.1 2>/dev/null | awk '/interface:/{print $2}'
}

dns_servers() {
  scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/{print $3}' | sort -u | tr '\n' ' ' | sed 's/ $//'
}

wifi_name() {
  local dev ssid
  dev=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/{getline; print $2; exit}')
  [ -z "$dev" ] && { echo "none"; return; }
  ssid=$(ipconfig getsummary "$dev" 2>/dev/null | awk -F' SSID : ' '/ SSID : /{print $2; exit}')
  echo "${ssid:-not on Wi-Fi}"
}

# --- Main loop -----------------------------------------------------
trap 'log "Stopped."; exit 0' INT TERM

first=1
prev_vpn=""; prev_ip=""; prev_loc=""; prev_dns=""; prev_wifi=""; prev_leak=""

log "VPN Guardian v$VERSION starting (every ${INTERVAL}s, phone alerts: ${NTFY_TOPIC:+on}${NTFY_TOPIC:-off})"

while true; do
  vpn=$(vpn_interfaces | tr '\n' ' ' | sed 's/ $//')
  lookup_public
  ip="$PUB_IP"; loc="$PUB_LOC"
  dns=$(dns_servers)
  rif=$(route_iface)
  wifi=$(wifi_name)

  if [ -z "$ip" ]; then
    [ "$prev_ip" != "OFFLINE" ] && notify "No internet connection."
    prev_ip="OFFLINE"
    sleep "$INTERVAL"; continue
  fi

  [ -z "$vpn" ] && echo "$ip" > "$REAL_IP_FILE"
  real_ip=$(cat "$REAL_IP_FILE" 2>/dev/null)

  if [ $first -eq 1 ]; then
    log "VPN: ${vpn:-OFF} | Sites see: $ip ($loc) ${PUB_ORG:+via $PUB_ORG} | Route: $rif | DNS: $dns | Wi-Fi: $wifi"
    [ -z "$vpn" ] && notify "Heads up: no VPN is active. Sites see you in $loc."
    first=0
  else
    if [ -n "$prev_vpn" ] && [ -z "$vpn" ]; then
      notify "VPN DROPPED on $wifi. Your real IP ($ip, $loc) is exposed."
    elif [ -z "$prev_vpn" ] && [ -n "$vpn" ]; then
      notify "VPN connected. Sites now see you in $loc ($ip)."
    elif [ -n "$vpn" ] && [ "$loc" != "$prev_loc" ] && [ "$prev_ip" != "OFFLINE" ]; then
      notify "VPN location changed: $prev_loc -> $loc"
    fi
    if [ "$ip" != "$prev_ip" ] && [ "$prev_ip" != "OFFLINE" ]; then
      log "IP changed: $prev_ip -> $ip"
    fi
    [ "$dns" != "$prev_dns" ] && log "DNS changed: $prev_dns -> $dns"
    [ "$wifi" != "$prev_wifi" ] && notify "Network changed: $prev_wifi -> $wifi"
  fi

  leak=""
  if [ -n "$vpn" ]; then
    if [ -n "$real_ip" ] && [ "$ip" = "$real_ip" ]; then
      leak="IP LEAK: VPN is on but sites still see your real IP ($ip)."
    elif [ -n "$rif" ] && ! is_tunnel "$rif"; then
      leak="ROUTE LEAK: VPN is up but traffic is leaving through $rif, not the tunnel."
    fi
  fi
  if [ -n "$leak" ] && [ "$leak" != "$prev_leak" ]; then
    notify "$leak"
  elif [ -z "$leak" ] && [ -n "$prev_leak" ]; then
    log "Leak cleared."
  fi

  prev_vpn="$vpn"; prev_ip="$ip"; prev_loc="$loc"; prev_dns="$dns"; prev_wifi="$wifi"; prev_leak="$leak"
  sleep "$INTERVAL"
done
