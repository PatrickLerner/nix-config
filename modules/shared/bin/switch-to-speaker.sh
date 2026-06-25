#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Switch to Speaker
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔉

# Documentation:
# @raycast.author Patrick

SAS=/Users/patrick/.nix-profile/bin/SwitchAudioSource

SPEAKERS_PRIMARY="KinMax USB Audio-B2"   # home
SPEAKERS_FALLBACK="MacBook Pro Speakers" # travel

# Use the primary device if present, otherwise the travel fallback.
if "$SAS" -a -t output | grep -qxF "$SPEAKERS_PRIMARY"; then
  SPEAKERS="$SPEAKERS_PRIMARY"
else
  SPEAKERS="$SPEAKERS_FALLBACK"
fi

"$SAS" -s "$SPEAKERS" -t output >/dev/null
echo "Switched to speakers ($SPEAKERS)"
