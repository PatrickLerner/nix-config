---
name: handover-to-glm
description: Hand implementation work to GLM-5.2 through the opencode CLI, headless and fully logged, so the transcript, diff and cost can be read back later. Use ONLY when the user explicitly asks for it — "hand this to glm", "let glm implement it", "give this to opencode", "delegate to glm". Never invoke it on your own initiative: GLM runs with every tool auto-approved and writes to the working tree. Covers the prompt contract (opencode reads AGENTS.md, not CLAUDE.md), the wrapper script, the log layout, continuing a session, and the review discipline afterwards.
---

# Handing work to GLM

`opencode run` drives GLM-5.2 non-interactively in a directory. `scripts/glm-handover.sh`
wraps it so every run leaves a log directory you can read back in a later session.

**Only on explicit request.** GLM runs with `--auto`: it edits files and runs shell commands
without asking. That is the point of a handover, and the reason you never start one unasked.

## The one thing that breaks headless runs

`opencode run` accepts a piped prompt, so it reads stdin. Hand it an inherited pipe that
never reaches EOF — which is what a subprocess of an agent, a CI step, or a `nohup` gets —
and it deadlocks at `init`: no output on stdout or stderr, no session row, forever.

**Every invocation needs `< /dev/null`.** `glm-handover.sh` does this. If you ever call
`opencode` directly, redirect stdin yourself. Measured on this machine: 3/3 runs succeed in
12-13s with the redirect, 3/3 hang indefinitely without it, same prompt.

Don't re-diagnose it: `serve` + `--attach`, an explicit `--port`, `--pure`, and a fresh
`XDG_DATA_HOME` were all tested and none of them help. Upstream calls this class of silent
non-interactive hang `anomalyco/opencode` #38110 and #37060.

## Preflight

1. **Confirm the target directory.** GLM edits in place. Prefer a dedicated worktree or a
   feature branch. The script refuses a dirty working tree unless you pass `--allow-dirty`,
   because otherwise GLM's changes cannot be told apart from what was already there.
2. **Check the model resolves**: `opencode models | grep glm-5.2`. `zai/glm-5.2` is the
   default; `opencode/glm-5.2` and `zai-coding-plan/glm-5.2` are alternative routes to it.
3. **Never commit or push on GLM's behalf** unless the user asked for that. Say so in the
   prompt too — GLM will otherwise sometimes commit.

## Write the prompt to a file first

Long prompts belong in a file, not in argv. Put it in the session scratchpad, then pass
`--prompt-file`. The prompt is copied into the log, so it stays reviewable.

**opencode reads `AGENTS.md` from the target directory, not `CLAUDE.md`.** (Verified: given
both files with conflicting instructions, GLM follows `AGENTS.md`.) In a repo whose conventions
live only in `CLAUDE.md`, or in nested/plugin instruction files, restate the binding rules in
the prompt or point GLM at the exact paths to read.

A prompt that produces usable work states:

- The goal, in one or two sentences.
- The exact files to change, and the ones to leave alone.
- The conventions that apply, or the path to the file holding them.
- The verification command (test/gate) GLM must run before reporting done.
- Explicitly: do not commit, do not push, do not open an MR (unless intended).

## Run it

```sh
~/.claude/skills/handover-to-glm/scripts/glm-handover.sh \
  --slug fix-retry-backoff \
  --dir ~/Projects/Instaffo/some-repo \
  --prompt-file "$SCRATCHPAD/glm-prompt.md"
```

Options: `--model <id>`, `--variant high|max` (reasoning effort), `--session <ses_id>`,
`--allow-dirty`, `--timeout <seconds>` (default 1800, `0` disables), `--log-root <path>`.

**Run it in the background.** A one-line edit takes under a minute; a real implementation task
takes many. Use `run_in_background: true` and read the log directory as it fills, rather than
blocking a foreground Bash call.

## Reading it back

Logs live in `~/.claude/glm-handover/<YYYYMMDD-HHMMSS>-<slug>/`:

| File | What it holds |
|------|---------------|
| `meta.json` | session id, exit code, cost, tokens, tool counts, files changed, errors, final message |
| `transcript.md` | header plus every tool call with its diff/output (clipped), then GLM's final message |
| `prompt.md` | the exact prompt sent |
| `stream.jsonl` | raw opencode event stream, unclipped — the source of truth |
| `diff.patch` | `git diff HEAD` in the target dir after the run |
| `git-before.txt` / `git-after.txt` | branch, HEAD and porcelain status either side of the run |
| `stderr.txt` | opencode's stderr |

Start with `meta.json` (small, structured), then `transcript.md`. Go to `stream.jsonl` only
when you need a full tool output. To find an older handover: `ls -t ~/.claude/glm-handover/`.

## Continuing a handover

Take `session_id` from `meta.json` and pass `--session`. Follow-up turns keep GLM's context,
which is far cheaper than restating the task:

```sh
glm-handover.sh --slug fix-retry-backoff-followup --dir <same dir> \
  --session ses_0005347d… --prompt-file "$SCRATCHPAD/glm-followup.md"
```

`opencode session list` and `opencode stats` show sessions and spend outside the log dirs.

## Review discipline

**GLM's final message is a claim, not evidence.** Before reporting anything to the user:

1. Read `diff.patch` (or `git diff`) yourself — that is what actually changed.
2. Run the repo's own gate/test command yourself. Do not accept "tests pass" from the
   transcript; a `--auto` run can also have run something you would not have allowed.
3. Check `meta.json` `errors` and the exit code. A non-zero exit with edits already on disk
   is the normal half-done case — decide whether to continue the session or revert.
4. Report cost and duration if the user cares about spend.

## Troubleshooting

- **`opencode is not on PATH`** — installed via nix (`~/.nix-profile/bin/opencode`); a stripped
  PATH in a subshell is the usual cause.
- **Auth failure** — keys live in `~/.local/share/opencode/auth.json` (`zai`, `zai-coding-plan`).
  Re-add with `opencode providers`. Never print the file.
- **Provider overrides** — `~/.config/opencode/opencode.json` and `opencode.jsonc` both exist;
  the `.jsonc` routes `zai` through a local Headroom proxy on `127.0.0.1:8787`. If runs fail
  with a connection error, that proxy is the first suspect.
- **Hangs with no output** — the stdin deadlock above, i.e. something is calling `opencode`
  without `< /dev/null`. `meta.json` shows `timed_out: true` and an empty `stream.jsonl`.
- **Empty transcript, exit 0** — GLM answered without tools. Check `prompt.md`: it probably
  read as a question rather than an instruction to edit files.
- **Cost** — each handover re-sends a large cached system prompt (~250k cached input tokens;
  94 skills are loaded from `~/.claude/skills` and `~/.agents/skills`). A small task runs
  ~$0.09-0.15. Continuing a session with `--session` is much cheaper than restating a task.
