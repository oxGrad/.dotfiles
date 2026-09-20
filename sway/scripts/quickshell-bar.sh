#!/bin/sh
# Sway always appends `-b <bar_id>` to swaybar_command; qs has no such flag
# and exits immediately on it, so this wrapper drops all passed args.
exec qs
