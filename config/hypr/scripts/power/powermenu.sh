#!/usr/bin/env bash

chosen=$(printf "  Lock\n  Suspend\n  Reboot\n  Shutdown\n  Logout\n  Hibernate" \
  | rofi -dmenu \
         -markup-rows \
         -no-fixed-num-lines \
         -theme ~/.config/rofi/powermenu.rasi \
         -kb-row-down "j,Down" \
         -kb-row-up "k,Up" \
         -kb-accept-entry "Return" \
         -p "power")

case "$chosen" in
  *Lock)      loginctl lock-session ;;
  *Suspend)   systemctl suspend ;;
  *Reboot)    systemctl reboot ;;
  *Shutdown)  systemctl poweroff ;;
  *Logout)    loginctl terminate-user "$USER" ;;
  *Hibernate) systemctl hibernate ;;
esac
