#!/usr/bin/env bash
# Simple Rofi power menu. Never acts without an explicit selection.
set -euo pipefail

options="Lock\nLogout\nSuspend\nReboot\nShutdown"
choice=$(printf '%b' "$options" | rofi -dmenu -p "Power" -theme-str 'listview { lines: 5; }')

case "$choice" in
  Lock)     hyprlock ;;
  Logout)   hyprctl dispatch exit ;;
  Suspend)  systemctl suspend ;;
  Reboot)   systemctl reboot ;;
  Shutdown) systemctl poweroff ;;
  *)        exit 0 ;;
esac
