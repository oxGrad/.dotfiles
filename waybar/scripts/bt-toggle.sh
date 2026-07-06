#!/usr/bin/env bash
# bt-toggle.sh — convergent bluetooth toggle for the XF86Bluetooth key.
# `rfkill toggle bluetooth` flips tpacpi_bluetooth_sw and hci0 independently;
# their states diverge when the tpacpi block removes the USB adapter, leaving
# the key apparently dead. Decide once from current state, then apply to all.
if rfkill list bluetooth | grep -q "Soft blocked: yes"; then
  rfkill unblock bluetooth
else
  rfkill block bluetooth
fi
