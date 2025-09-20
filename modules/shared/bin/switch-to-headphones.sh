#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Switch to Headphones
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🎧

# Documentation:
# @raycast.author Patrick

HEADPHONES="ZR USB AUDIO"
SwitchAudioSource -s "$HEADPHONES" -t output >/dev/null
echo "Switched to headphones"