#!/usr/bin/env bash
# Run an implementation task on GLM via `opencode run`, logging everything to a
# directory Claude can read back later.
set -euo pipefail

MODEL="zai/glm-5.2"
SLUG="handover"
WORKDIR="$PWD"
PROMPT_FILE=""
SESSION=""
VARIANT=""
ALLOW_DIRTY=0
TIMEOUT_S="${GLM_HANDOVER_TIMEOUT:-1800}"
LOG_ROOT="${GLM_HANDOVER_LOG_ROOT:-$HOME/.claude/glm-handover}"

usage() {
  cat <<'EOF'
glm-handover.sh --prompt-file <path|-> [options]

  --prompt-file <path>  Prompt to send. `-` reads stdin. Required.
  --slug <name>         Short label for the log dir. Default: handover
  --dir <path>          Repo/dir GLM works in. Default: cwd
  --model <id>          Default: zai/glm-5.2
  --variant <name>      Reasoning effort (e.g. high, max)
  --session <ses_id>    Continue an earlier handover (see meta.json)
  --allow-dirty         Run even with uncommitted changes present
  --timeout <seconds>   Wall-clock cap; 0 disables. Default: 1800
  --log-root <path>     Default: $HOME/.claude/glm-handover

GLM runs with every tool auto-approved: it edits files and runs shell commands
without asking. Point --dir at a worktree or a clean branch.
EOF
}

die() {
  printf 'glm-handover: %s\n' "$1" >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prompt-file) PROMPT_FILE="${2:-}"; shift 2 ;;
    --slug) SLUG="${2:-}"; shift 2 ;;
    --dir) WORKDIR="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --variant) VARIANT="${2:-}"; shift 2 ;;
    --session) SESSION="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT_S="${2:-}"; shift 2 ;;
    --log-root) LOG_ROOT="${2:-}"; shift 2 ;;
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$PROMPT_FILE" ] || { usage >&2; die "--prompt-file is required"; }
command -v opencode >/dev/null 2>&1 || die "opencode is not on PATH"
[ -d "$WORKDIR" ] || die "--dir does not exist: $WORKDIR"
WORKDIR="$(cd "$WORKDIR" && pwd)"

if [ "$PROMPT_FILE" = "-" ]; then
  PROMPT="$(cat)"
else
  [ -f "$PROMPT_FILE" ] || die "prompt file not found: $PROMPT_FILE"
  PROMPT="$(cat "$PROMPT_FILE")"
fi
[ -n "${PROMPT//[[:space:]]/}" ] || die "prompt is empty"

IS_GIT=0
if git -C "$WORKDIR" rev-parse --git-dir >/dev/null 2>&1; then
  IS_GIT=1
  DIRTY="$(git -C "$WORKDIR" status --porcelain)"
  if [ -n "$DIRTY" ] && [ "$ALLOW_DIRTY" -eq 0 ]; then
    printf '%s\n' "$DIRTY" >&2
    die "working tree is dirty; GLM's changes would be indistinguishable from these. Commit/stash first, or pass --allow-dirty"
  fi
fi

SAFE_SLUG="$(printf '%s' "$SLUG" | tr -cs '[:alnum:]._-' '-' | sed 's/^-*//; s/-*$//')"
[ -n "$SAFE_SLUG" ] || SAFE_SLUG="handover"
LOG="$LOG_ROOT/$(date +%Y%m%d-%H%M%S)-$SAFE_SLUG"
mkdir -p "$LOG"
printf '%s\n' "$PROMPT" > "$LOG/prompt.md"

if [ "$IS_GIT" -eq 1 ]; then
  {
    printf 'branch: %s\n' "$(git -C "$WORKDIR" rev-parse --abbrev-ref HEAD)"
    printf 'head: %s\n' "$(git -C "$WORKDIR" rev-parse HEAD)"
    printf 'status:\n%s\n' "$(git -C "$WORKDIR" status --porcelain)"
  } > "$LOG/git-before.txt"
fi

ARGS=(run --model "$MODEL" --format json --auto --title "$SAFE_SLUG")
if [ -n "$SESSION" ]; then
  ARGS+=(--session "$SESSION")
fi
if [ -n "$VARIANT" ]; then
  ARGS+=(--variant "$VARIANT")
fi

# `opencode run` also accepts a piped prompt, so it blocks on stdin: given an
# inherited pipe that never reaches EOF it deadlocks at `init` and emits nothing,
# forever. Redirecting stdin from /dev/null below is what makes headless runs work.
# The timeout stays as a net for the other documented silent-hang paths.
CMD=(opencode "${ARGS[@]}" "$PROMPT")
if [ "$TIMEOUT_S" != "0" ]; then
  TIMEOUT_BIN="$(command -v timeout || command -v gtimeout || true)"
  if [ -n "$TIMEOUT_BIN" ]; then
    CMD=("$TIMEOUT_BIN" --kill-after=10 "$TIMEOUT_S" "${CMD[@]}")
  else
    printf 'glm-handover: no timeout(1) found, running uncapped\n' >&2
  fi
fi

STARTED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RC=0
(cd "$WORKDIR" && "${CMD[@]}") < /dev/null > "$LOG/stream.jsonl" 2> "$LOG/stderr.txt" || RC=$?
ENDED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ "$IS_GIT" -eq 1 ]; then
  {
    printf 'branch: %s\n' "$(git -C "$WORKDIR" rev-parse --abbrev-ref HEAD)"
    printf 'head: %s\n' "$(git -C "$WORKDIR" rev-parse HEAD)"
    printf 'status:\n%s\n' "$(git -C "$WORKDIR" status --porcelain)"
  } > "$LOG/git-after.txt"
  git -C "$WORKDIR" diff HEAD > "$LOG/diff.patch" 2>/dev/null || true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
node "$SCRIPT_DIR/render-glm-log.mjs" \
  --log "$LOG" --slug "$SAFE_SLUG" --model "$MODEL" --dir "$WORKDIR" \
  --exit "$RC" --started "$STARTED" --ended "$ENDED"

exit "$RC"
