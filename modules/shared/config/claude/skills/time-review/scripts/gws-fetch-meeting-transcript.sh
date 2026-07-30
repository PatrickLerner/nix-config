#!/usr/bin/env bash
# Find and export a meeting transcript (Gemini doc) from Google Drive by date.
# Searches for Google Docs modified on a specific date, optionally filtered by name.
#
# Usage: gws-fetch-meeting-transcript.sh <work|personal> <ISO-date> [search_term] [outfile]
#   e.g. gws-fetch-meeting-transcript.sh work 2026-07-14 "Leadership"
#        gws-fetch-meeting-transcript.sh work 2026-07-14
#
# With search_term: exports the first match to <outfile> and prints "path<TAB>name<TAB>lines".
# Without search_term: lists all matching docs as TSV (id, name, modifiedTime, owner) for selection.
set -euo pipefail

acct="${1:?account required: work|personal}"
date="${2:?ISO date required, e.g. 2026-07-14}"
search="${3:-}"
outfile="${4:-/tmp/transcript.md}"

case "$acct" in
  work)     export GOOGLE_WORKSPACE_CLI_CONFIG_DIR="$HOME/.config/gws-work" ;;
  personal) export GOOGLE_WORKSPACE_CLI_CONFIG_DIR="$HOME/.config/gws-personal" ;;
  *) echo "unknown account '$acct' (use work|personal)" >&2; exit 2 ;;
esac

# Compute next day for the date range (macOS BSD date)
next_day=$(date -j -v+1d -f "%Y-%m-%d" "$date" "+%Y-%m-%d" 2>/dev/null || true)
if [[ -z "$next_day" ]]; then
  # Fallback for non-macOS
  next_day=$(date -d "$date + 1 day" "+%Y-%m-%d" 2>/dev/null || echo "$date")
fi

# Drive query: docs modified on that specific day
q="mimeType='application/vnd.google-apps.document' and modifiedTime >= '${date}T00:00:00' and modifiedTime < '${next_day}T00:00:00'"

if [[ -n "$search" ]]; then
  q="${q} and name contains '${search}'"
fi

params=$(printf '{"q":"%s","orderBy":"modifiedTime desc","fields":"files(id,name,createdTime,modifiedTime,owners(displayName,emailAddress))","pageSize":20}' "$q")

# List matching docs (strip keyring noise)
docs=$(gws drive files list --params "$params" --format json 2>/dev/null | grep -v '^Using keyring backend')
count=$(echo "$docs" | jq '.files | length')

if [[ "$count" -eq 0 ]]; then
  echo "No docs found on $date${search:+ matching '$search'}" >&2
  exit 1
fi

if [[ -n "$search" ]]; then
  # Export first match
  file_id=$(echo "$docs" | jq -r '.files[0].id')
  file_name=$(echo "$docs" | jq -r '.files[0].name')

  export_params=$(printf '{"fileId":"%s","mimeType":"text/markdown"}' "$file_id")
  # gws sandboxes --output to the current directory and rejects absolute/escaping
  # paths, so cd into the target dir and export the basename there.
  out_dir=$(cd "$(dirname "$outfile")" && pwd)
  out_base=$(basename "$outfile")
  ( cd "$out_dir" && gws drive files export --params "$export_params" -o "$out_base" >/dev/null 2>&1 )
  outfile="$out_dir/$out_base"

  printf '%s\t%s\t%s lines\n' "$outfile" "$file_name" "$(wc -l < "$outfile" | tr -d ' ')"
else
  # List all matches as TSV for manual selection
  echo "$docs" | jq -r '.files[] | "\(.id)\t\(.name)\t\(.modifiedTime)\t\(.owners[0].displayName)"'
fi
