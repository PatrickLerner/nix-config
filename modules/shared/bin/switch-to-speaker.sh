#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Switch to Speaker
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔉

# Documentation:
# @raycast.author Patrick

SPEAKERS="KinMax USB Audio-B2"
SwitchAudioSource -s "$SPEAKERS" -t output >/dev/null
echo "Switched to speakers"