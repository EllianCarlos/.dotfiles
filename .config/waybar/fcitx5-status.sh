#!/usr/bin/env bash
# Report the active fcitx5 input method for waybar's custom/language module.
# Toggle with SUPER+I (hyprland.conf) or by clicking this module.

im="$(fcitx5-remote -n 2>/dev/null)"

case "$im" in
  mozc) echo "JP" ;;
  keyboard-*) echo "EN" ;;
  "")
    # No input context yet (nothing focused) reports empty too, not just
    # "fcitx5 is not running" -- so check the process before assuming.
    # Not `pgrep -x`: Nix wraps the binary, so its comm is
    # ".fcitx5-wrapped", not "fcitx5".
    if pgrep fcitx5 >/dev/null; then echo "EN"; else echo "OFF"; fi
    ;;
  *) echo "$im" ;;
esac
