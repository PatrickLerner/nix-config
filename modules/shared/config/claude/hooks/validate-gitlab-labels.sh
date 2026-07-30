#!/usr/bin/env bash
set -euo pipefail

# Delegate to the newest cached plugin version's script
SCRIPT=$(ls -d ~/.claude/plugins/cache/instaffo-skills/instaffo-dev/*/skills/setup-label-hook/validate-gitlab-labels.sh 2>/dev/null | sort -V | tail -1)
[ -z "$SCRIPT" ] && echo '{"decision":"approve"}' && exit 0
exec bash "$SCRIPT" "$@"
