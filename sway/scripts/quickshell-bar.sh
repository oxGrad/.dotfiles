#!/bin/sh
# Sway always appends `-b <bar_id>` to swaybar_command; qs has no such flag
# and exits immediately on it, so this wrapper drops all passed args.
# QT_QPA_PLATFORMTHEME makes native widgets (tray right-click menus) use the
# Monokai palette from ~/.config/qt6ct instead of the unthemed default.
export QT_QPA_PLATFORMTHEME=qt6ct
exec qs
