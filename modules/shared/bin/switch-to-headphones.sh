#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Switch to Headphones
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🎧

# Documentation:
# @raycast.author Patrick

SAS=/Users/patrick/.nix-profile/bin/SwitchAudioSource

HEADPHONES_PRIMARY="ZR USB AUDIO"      # home
HEADPHONES_FALLBACK="WH-CH720N"        # travel

# Use the primary device if present, otherwise the travel fallback.
if "$SAS" -a -t output | grep -qxF "$HEADPHONES_PRIMARY"; then
  HEADPHONES="$HEADPHONES_PRIMARY"
else
  HEADPHONES="$HEADPHONES_FALLBACK"
fi

"$SAS" -s "$HEADPHONES" -t output >/dev/null
echo "Switched to headphones ($HEADPHONES)"
