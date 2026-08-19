#!/bin/bash
# idle-action.sh
# Checks AC state before running an idle action.
# Usage: idle-action.sh <battery_cmd> <ac_cmd>
# Pass "skip" as either argument to do nothing on that power state.

BATTERY_CMD="$1"
AC_CMD="$2"

AC_ONLINE=$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo "1")

if [ "$AC_ONLINE" = "1" ]; then
  [ "$AC_CMD" != "skip" ] && eval "$AC_CMD"
else
  [ "$BATTERY_CMD" != "skip" ] && eval "$BATTERY_CMD"
fi
