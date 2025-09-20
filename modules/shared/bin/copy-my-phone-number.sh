#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Copy My Phone Number
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📱

# Documentation:
# @raycast.description Copies my phone number to clipboard
# @raycast.author Patrick

PHONE_NUMBER=$(cat ~/.phone_number 2>/dev/null || echo "Phone number not found")
echo "$PHONE_NUMBER" | pbcopy
echo "Copied phone number"