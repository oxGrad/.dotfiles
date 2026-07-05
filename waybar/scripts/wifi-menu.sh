#!/usr/bin/env bash
# wifi-menu.sh — wofi-based wifi picker (nmcli backend)
set -uo pipefail

WOFI="wofi --dmenu -i --prompt"

notify() { command -v notify-send >/dev/null && notify-send "Wi-Fi" "$1"; }

radio=$(nmcli radio wifi)
if [ "$radio" = "enabled" ]; then
  toggle_label="  Turn wifi off"
else
  toggle_label="  Turn wifi on"
fi

menu=""
declare -A ssid_of

if [ "$radio" = "enabled" ]; then
  while IFS= read -r line; do
    inuse=${line%%:*};  rest=${line#*:}
    signal=${rest%%:*}; rest=${rest#*:}
    security=${rest%%:*}
    ssid=${rest#*:}
    ssid=${ssid//\\:/:}
    [ -z "$ssid" ] && continue
    if   [ "$signal" -gt 75 ]; then bars="▰▰▰▰"
    elif [ "$signal" -gt 50 ]; then bars="▰▰▰▱"
    elif [ "$signal" -gt 25 ]; then bars="▰▰▱▱"
    else                            bars="▰▱▱▱"; fi
    lock=""
    case "$security" in ""|"--") ;; *) lock=" ";; esac
    mark=""
    [ "$inuse" = "*" ] && mark="  "
    entry=$(printf '%-28s %s%s%s' "$ssid" "$bars" "$lock" "$mark")
    ssid_of["$entry"]="$ssid"
    if [ "$inuse" = "*" ]; then
      menu="$entry"$'\n'"$menu"
    else
      menu="$menu$entry"$'\n'
    fi
  done < <(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list | sort -t: -k2 -rn | awk -F: '!seen[$4]++')
fi

extras="  Disconnect
$toggle_label
  Rescan"

choice=$(printf '%s%s' "$menu" "$extras" | $WOFI "wifi ") || exit 0

case "$choice" in
  "  Rescan")
    nmcli dev wifi rescan >/dev/null 2>&1
    sleep 2
    exec "$0" ;;
  "  Turn wifi off")
    nmcli radio wifi off && notify "Wi-Fi disabled" ;;
  "  Turn wifi on")
    nmcli radio wifi on && notify "Wi-Fi enabled"
    sleep 2
    exec "$0" ;;
  "  Disconnect")
    active=$(nmcli -t -f NAME,TYPE con show --active | awk -F: '$2 ~ /wireless/ {print $1; exit}')
    if [ -n "$active" ]; then
      nmcli con down "$active" >/dev/null && notify "Disconnected from $active"
    else
      notify "No active wifi connection"
    fi ;;
  *)
    ssid="${ssid_of[$choice]:-}"
    [ -z "$ssid" ] && exit 0
    if nmcli -t -f NAME con show | grep -qxF -- "$ssid"; then
      if nmcli con up "$ssid" >/dev/null 2>&1; then
        notify "Connected to $ssid"
      else
        notify "Failed to connect to $ssid"
      fi
    else
      secured=$(nmcli -t -f SSID,SECURITY dev wifi list | awk -F: -v s="$ssid" '$1==s {print $2; exit}')
      pw=""
      case "$secured" in ""|"--") ;; *)
        pw=$(wofi --dmenu --password --prompt "password: $ssid" --lines 1) || exit 0 ;;
      esac
      if [ -n "$pw" ]; then
        out=$(nmcli dev wifi connect "$ssid" password "$pw" 2>&1)
      else
        out=$(nmcli dev wifi connect "$ssid" 2>&1)
      fi
      if printf '%s' "$out" | grep -qi error; then
        notify "Failed: $ssid"
      else
        notify "Connected to $ssid"
      fi
    fi ;;
esac
