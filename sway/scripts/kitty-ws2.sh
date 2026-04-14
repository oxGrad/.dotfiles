#!/usr/bin/env bash
set -euo pipefail

WORKSPACE=2
TERM_APP="kitty"

swaymsg workspace "$WORKSPACE"

if swaymsg -t get_tree | jq -r '
    recurse(.nodes[]?; .floating_nodes?, .nodes?) |
    select(.type == "workspace" and .name == "'"$WORKSPACE"'") |
    recurse(.nodes[]?; .floating_nodes?, .nodes[]) |
    select(.type == "con") |
    .app_id // .window_properties.class
' | grep -qi "^${TERM_APP}$"; then
	exit 0
fi

exec "$TERM_APP"
