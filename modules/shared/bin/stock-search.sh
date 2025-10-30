#!/bin/bash

# Raycast Script Command
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Stock Search
# @raycast.mode silent
# @raycast.packageName OnVista
# @raycast.icon 📈
# @raycast.argument1 { "type": "text", "placeholder": "Search term" }

set -euo pipefail

SEARCH_TERM="$1"

if [ -z "$SEARCH_TERM" ]; then
    echo "Error: Search term is required"
    exit 1
fi

# URL encode the search term
ENCODED_TERM=$(printf %s "$SEARCH_TERM" | jq -sRr @uri)

# API endpoint
API_URL="https://api.onvista.de/api/v1/main/search?limit=5&scapaId=ef785585-9e7b-490b-a1bf-79a6d2b9cb8d&searchValue=${ENCODED_TERM}"

# Call the API
echo "Searching for: $SEARCH_TERM"
RESPONSE=$(curl -s "$API_URL")

# Check if curl succeeded
if [ -z "$RESPONSE" ]; then
    echo "Error: Failed to fetch data from API"
    exit 1
fi

# Extract the stock URL from the JSON response
# The API returns a list, we'll take the first result
STOCK_URL=$(echo "$RESPONSE" | jq -r '.instrumentList.list[0].urls.WEBSITE // empty' 2>/dev/null)

# Check if we got a URL
if [ -z "$STOCK_URL" ]; then
    echo "Error: Could not find stock URL in API response"
    echo "No results found for: $SEARCH_TERM"
    exit 1
fi

# Transform the URL to the kennzahlen (financial metrics) page
# Replace /aktien/ with /aktien/kennzahlen/
KENNZAHLEN_URL=$(echo "$STOCK_URL" | sed 's|/aktien/|/aktien/kennzahlen/|')

echo "Opening: $KENNZAHLEN_URL"

# Open the URL in the default browser
open "$KENNZAHLEN_URL"
