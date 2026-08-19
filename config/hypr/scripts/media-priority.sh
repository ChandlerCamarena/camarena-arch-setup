#!/bin/bash
# Watch all MPRIS players and pause mpv when anything else plays,
# resume mpv when everything else stops — but only if mpv was playing
# before the interruption.

mpv_was_playing=false

playerctl --follow --player=spotify,firefox,chromium,vlc,mpv metadata --format '{{playerName}} {{status}}' 2>/dev/null | \
while read -r player status; do
  if [[ "$player" == "mpv" ]]; then
    # Track mpv state changes that weren't caused by us
    : # we manage mpv externally; ignore its own status events here
  else
    if [[ "$status" == "Playing" ]]; then
      # Check if mpv is currently playing before we pause it
      mpv_status=$(playerctl --player=mpv status 2>/dev/null)
      if [[ "$mpv_status" == "Playing" ]]; then
        mpv_was_playing=true
      else
        mpv_was_playing=false
      fi
      playerctl --player=mpv pause 2>/dev/null
    elif [[ "$status" == "Paused" || "$status" == "Stopped" ]]; then
      # Only resume mpv if no other non-mpv player is still playing
      other_playing=$(playerctl -l 2>/dev/null | grep -v mpv | xargs -I{} playerctl --player={} status 2>/dev/null | grep -c Playing)
      if [[ "$other_playing" == "0" ]] && [[ "$mpv_was_playing" == "true" ]]; then
        playerctl --player=mpv play 2>/dev/null
      fi
    fi
  fi
done
