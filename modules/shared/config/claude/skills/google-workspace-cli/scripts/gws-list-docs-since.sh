#!/usr/bin/env bash
# List Google Docs modified since a date, newest first.
# Workhorse for the google-docs import flow.
#
# Usage: gws-list-docs-since.sh <work|personal> <ISO-date> [pageSize]
#   e.g. gws-list-docs-since.sh work 2026-07-09
#
# Outputs clean JSON: id, name, createdTime, modifiedTime, owners.
# IMPORTANT: intentionally does NOT filter ownedByMe — that would hide
# shared Gemini meeting-note docs owned by other organizers.
set -euo pipefail

acct="${1:?account required: work|personal}"
since="${2:?ISO date required, e.g. 2026-07-09}"
page_size="${3:-50}"

case "$acct" in
  work)     export GOOGLE_WORKSPACE_CLI_CONFIG_DIR="$HOME/.config/gws-work" ;;
  personal) export GOOGLE_WORKSPACE_CLI_CONFIG_DIR="$HOME/.config/gws-personal" ;;
  *) echo "unknown account '$acct' (use work|personal)" >&2; exit 2 ;;
esac

q="mimeType='application/vnd.google-apps.document' and modifiedTime > '${since}T00:00:00'"
params=$(printf '{"q":"%s","orderBy":"modifiedTime desc","fields":"files(id,name,createdTime,modifiedTime,owners(displayName,emailAddress))","pageSize":%s}' \
  "$q" "$page_size")

# Drop the "Using keyring backend: keyring" stderr/stdout noise; keep JSON.
gws drive files list --params "$params" --format json 2>/dev/null \
  | grep -v '^Using keyring backend'
