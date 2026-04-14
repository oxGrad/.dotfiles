#!/bin/bash

# Define the options for the powermenu
options="Shutdown\nReboot\nSuspend\nLock\nLogout"

# Use wofi to get the user's choice
choice=$(echo -e "$options" | wofi --dmenu -p "Power Menu:")

case "$choice" in
    "Shutdown")
        exec systemctl poweroff
        ;;
    "Reboot")
        exec systemctl reboot
        ;;
    "Suspend")
        exec systemctl suspend
        ;;
    "Lock")
        exec swaylock # Assuming swaylock is installed for Sway
        ;;
    "Logout")
        exec swaymsg exit # Assuming 'swaymsg exit' logs out of Sway
        ;;
esac