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

SPEAKERS="KinMax USB Audio-B2"
HEADPHONES="ZR USB AUDIO"

if [[ "$(/Users/patrick/.nix-profile/bin/SwitchAudioSource -c -t output)" == "$HEADPHONES" ]]; then
  /Users/patrick/.nix-profile/bin/SwitchAudioSource -s "$SPEAKERS" -t output >/dev/null
  echo "Switched to speakers"
else
  /Users/patrick/.nix-profile/bin/SwitchAudioSource -s "$HEADPHONES" -t output >/dev/null
  echo "Switched to headphones"
fi