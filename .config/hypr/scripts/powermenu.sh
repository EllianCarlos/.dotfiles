#!/bin/sh
entries="Logout\nShutdown\nReboot"
selected=$(echo -e $entries | wofi --show dmenu --insensitive -p "Power Menu")

case $selected in
Logout)
  hyprctl dispatch exit
  ;;
Shutdown)
  systemctl poweroff
  ;;
Reboot)
  systemctl reboot
  ;;
esac
