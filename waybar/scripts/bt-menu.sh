#!/usr/bin/env bash
# bt-menu.sh — wofi-based bluetooth device picker (bluetoothctl backend)
set -uo pipefail

WOFI="wofi --dmenu -i --prompt"

notify() { command -v notify-send >/dev/null && notify-send "Bluetooth" "$1"; }

if bluetoothctl show | grep -q "Powered: yes"; then
  powered=yes
  toggle_label="󰂲  Turn bluetooth off"
else
  powered=no
  toggle_label="󰂯  Turn bluetooth on"
fi

menu=""
declare -A mac_of conn_of

if [ "$powered" = yes ]; then
  while read -r mac name; do
    [ -z "$mac" ] && continue
    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
      entry=$(printf '󰂱  %-24s ' "$name")
      conn_of["$entry"]=yes
      menu="$entry"$'\n'"$menu"
    else
      entry=$(printf '󰂯  %-24s' "$name")
      conn_of["$entry"]=no
      menu="$menu$entry"$'\n'
    fi
    mac_of["$entry"]="$mac"
  done < <(bluetoothctl devices | awk '{mac=$2; $1=""; $2=""; sub(/^ +/, ""); print mac" "$0}')
fi

extras="$toggle_label
󰑐  Scan (5s)"

choice=$(printf '%s%s' "$menu" "$extras" | $WOFI "bluetooth ") || exit 0

case "$choice" in
  "󰂲  Turn bluetooth off")
    bluetoothctl power off >/dev/null && notify "Bluetooth disabled" ;;
  "󰂯  Turn bluetooth on")
    bluetoothctl power on >/dev/null && notify "Bluetooth enabled"
    sleep 1
    exec "$0" ;;
  "󰑐  Scan (5s)")
    bluetoothctl --timeout 5 scan on >/dev/null 2>&1
    exec "$0" ;;
  *)
    mac="${mac_of[$choice]:-}"
    [ -z "$mac" ] && exit 0
    name=$(printf '%s' "$choice" | sed 's/^..  //; s/ *$//')
    if [ "${conn_of[$choice]}" = yes ]; then
      bluetoothctl disconnect "$mac" >/dev/null && notify "Disconnected from $name"
    elif bluetoothctl connect "$mac" >/dev/null 2>&1; then
      notify "Connected to $name"
    else
      bluetoothctl pair "$mac" >/dev/null 2>&1 && bluetoothctl trust "$mac" >/dev/null 2>&1
      if bluetoothctl connect "$mac" >/dev/null 2>&1; then
        notify "Paired and connected to $name"
      else
        notify "Failed to connect to $name"
      fi
    fi ;;
esac
