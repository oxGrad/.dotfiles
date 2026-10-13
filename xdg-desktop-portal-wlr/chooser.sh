#!/bin/sh
# xdpw chooser: pick a monitor or a single window with wofi
list=$({
  swaymsg -t get_outputs | jq -r '.[] | select(.active) | "  \(.name)\tMonitor: \(.name)"'
  swaymsg -t get_tree | jq -r '.. | objects | select(.foreign_toplevel_identifier?)
    | "  \(.app_id // .window_properties.class) — \(.name)\tWindow: \(.foreign_toplevel_identifier)"'
})
pick=$(printf '%s\n' "$list" | cut -f1 | wofi --dmenu --prompt "Share") || exit 0
printf '%s\n' "$list" | awk -F'\t' -v p="$pick" '$1 == p { print $2; exit }'
