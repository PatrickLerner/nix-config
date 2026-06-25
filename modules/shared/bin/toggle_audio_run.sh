#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Audio
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔈

# Documentation:
# @raycast.description Toggle Audio from Monitor to Headphones
# @raycast.author Patrick

SAS=/Users/patrick/.nix-profile/bin/SwitchAudioSource

SPEAKERS_PRIMARY="KinMax USB Audio-B2"   # home
SPEAKERS_FALLBACK="MacBook Pro Speakers" # travel
HEADPHONES_PRIMARY="ZR USB AUDIO"        # home
HEADPHONES_FALLBACK="WH-CH720N"          # travel

AVAILABLE="$("$SAS" -a -t output)"

# Resolve each role to the primary device if present, otherwise the fallback.
resolve() {
  if grep -qxF "$1" <<<"$AVAILABLE"; then echo "$1"; else echo "$2"; fi
}
SPEAKERS="$(resolve "$SPEAKERS_PRIMARY" "$SPEAKERS_FALLBACK")"
HEADPHONES="$(resolve "$HEADPHONES_PRIMARY" "$HEADPHONES_FALLBACK")"

if [[ "$("$SAS" -c -t output)" == "$HEADPHONES" ]]; then
  "$SAS" -s "$SPEAKERS" -t output >/dev/null
  echo "Switched to speakers ($SPEAKERS)"
else
  "$SAS" -s "$HEADPHONES" -t output >/dev/null
  echo "Switched to headphones ($HEADPHONES)"
fi
