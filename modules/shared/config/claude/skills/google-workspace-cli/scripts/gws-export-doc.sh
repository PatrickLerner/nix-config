#!/usr/bin/env bash
# Export a Google Doc (or Sheet/Slide) to a local file and print its path.
# Google Docs API `documents get` returns verbose structural JSON — this uses
# Drive export instead, which yields clean markdown/text.
#
# Usage: gws-export-doc.sh <work|personal> <fileId> [outfile] [mimeType]
#   e.g. gws-export-doc.sh work 1GKNTf... notes.md
#   default outfile: <fileId>.md   default mimeType: text/markdown
#
# For Gemini meeting-note docs, text/markdown includes the summary AND the
# full transcript (under a "# Transcript" heading) — read only what you need.
set -euo pipefail

acct="${1:?account required: work|personal}"
file_id="${2:?fileId required}"
out="${3:-${file_id}.md}"
mime="${4:-text/markdown}"

case "$acct" in
  work)     export GOOGLE_WORKSPACE_CLI_CONFIG_DIR="$HOME/.config/gws-work" ;;
  personal) export GOOGLE_WORKSPACE_CLI_CONFIG_DIR="$HOME/.config/gws-personal" ;;
  *) echo "unknown account '$acct' (use work|personal)" >&2; exit 2 ;;
esac

params=$(printf '{"fileId":"%s","mimeType":"%s"}' "$file_id" "$mime")
# gws sandboxes --output to its working directory and rejects any path that
# resolves outside it (incl. absolute paths like /tmp/x.md). So cd into the
# target dir and export the basename there.
out_dir=$(cd "$(dirname "$out")" && pwd)
out_base=$(basename "$out")
( cd "$out_dir" && gws drive files export --params "$params" -o "$out_base" >/dev/null 2>&1 )
out="$out_dir/$out_base"
printf '%s\t%s lines\n' "$out" "$(wc -l < "$out" | tr -d ' ')"
