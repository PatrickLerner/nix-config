---
name: handover-to-opencode
description: Hand implementation work to Kimi K3.1 Pro through the opencode v2 CLI, headless and fully logged, so the transcript, diff and token use can be read back later. Use ONLY when the user explicitly asks for it — "hand this to kimi", "let kimi implement it", "give this to opencode", "delegate to opencode", or the old "hand this to glm". Never invoke it on your own initiative: the model runs with every tool auto-approved and writes to the working tree. Covers the prompt contract (opencode reads AGENTS.md, not CLAUDE.md), the wrapper script, the log layout, continuing a session, and the review discipline afterwards.
---

# Handing work to opencode

`opencode run` (v2) drives Kimi K3.1 Pro non-interactively in a directory.
`scripts/opencode-handover.sh` wraps it so every run leaves a log directory you can read back
in a later session.

**Only on explicit request.** The model runs with `--auto`: it edits files and runs shell
commands without asking. That is the point of a handover, and the reason you never start one
unasked.

## What the wrapper handles for you

- **`< /dev/null` on stdin.** `opencode run` accepts a piped prompt, so it reads stdin. Given
  an inherited pipe that never reaches EOF (any agent subprocess, CI step, `nohup`) it hangs at
  `init` with no output, forever. Measured on v1; the redirect stays on v2. If you ever call
  `opencode` directly, redirect stdin yourself.
- **`--standalone`.** By default v2 `run` connects to a shared background service
  (`opencode service status`), and tools run inside that service with its env and PATH, not
  the wrapper's. `--standalone` starts a private server for the run.
- **Variant syntax.** v2 has no `--variant` flag; effort is part of the model id,
  `provider/model#variant`. The wrapper's `--variant high` builds that.
- **Token totals.** v2's json stream has no `step_finish` events, so the wrapper saves
  `opencode session export` as `session.json` and reads totals from there.

## Preflight

1. **Confirm the target directory.** The model edits in place. Prefer a dedicated worktree or
   a feature branch. The script refuses a dirty working tree unless you pass `--allow-dirty`,
   because otherwise the model's changes cannot be told apart from what was already there.
2. **Check the model resolves**: `opencode models < /dev/null | grep k3.1`. The default is
   `kimi-code-plan-global/k3.1-pro` (Kimi Code plan). `k3.1-pro-highspeed` is the faster
   variant on the same plan.
3. **Never commit or push on the model's behalf** unless the user asked for that. Say so in the
   prompt too; otherwise it sometimes commits.

## Write the prompt to a file first

Long prompts belong in a file, not in argv. Put it in the session scratchpad, then pass
`--prompt-file`. The prompt is copied into the log, so it stays reviewable.

**opencode reads `AGENTS.md` from the target directory, not `CLAUDE.md`.** In a repo whose
conventions live only in `CLAUDE.md`, or in nested/plugin instruction files, restate the
binding rules in the prompt or point the model at the exact paths to read.

A prompt that produces usable work states:

- The goal, in one or two sentences.
- The exact files to change, and the ones to leave alone.
- The conventions that apply, or the path to the file holding them.
- The verification command (test/gate) the model must run before reporting done.
- Explicitly: do not commit, do not push, do not open an MR (unless intended).

## Run it

```sh
~/.claude/skills/handover-to-opencode/scripts/opencode-handover.sh \
  --slug fix-retry-backoff \
  --dir ~/Projects/Instaffo/some-repo \
  --prompt-file "$SCRATCHPAD/handover-prompt.md"
```

Options: `--model <provider/model>`, `--variant high|max`, `--session <ses_id>`,
`--allow-dirty`, `--timeout <seconds>` (default 1800, `0` disables), `--log-root <path>`.

**Run it in the background.** A one-line edit takes under a minute; a real implementation task
takes many. Use `run_in_background: true` and read the log directory as it fills, rather than
blocking a foreground Bash call.

## Reading it back

Logs live in `~/.claude/opencode-handover/<YYYYMMDD-HHMMSS>-<slug>/` (runs before the switch
to Kimi are in `~/.claude/glm-handover/`):

| File | What it holds |
|------|---------------|
| `meta.json` | session id, exit code, tokens (`token_source` says where from), tool counts, files changed, errors, final message |
| `transcript.md` | header plus every tool call with its diff/output (clipped), then the final message |
| `prompt.md` | the exact prompt sent |
| `stream.jsonl` | raw opencode event stream, unclipped — the source of truth |
| `session.json` | `opencode session export` after the run |
| `diff.patch` | `git diff HEAD` in the target dir after the run |
| `git-before.txt` / `git-after.txt` | branch, HEAD and porcelain status either side of the run |
| `stderr.txt` | opencode's stderr |

Start with `meta.json`, then `transcript.md`. Go to `stream.jsonl` only when you need a full
tool output. To find an older handover: `ls -t ~/.claude/opencode-handover/`.

`cost_usd` is 0 on the Kimi plan: it bills by plan quota, not per token. With `--session`, the
token totals cover the whole session, not only the last turn.

## Continuing a handover

Take `session_id` from `meta.json` and pass `--session`. Follow-up turns keep the model's
context, which is far cheaper than restating the task:

```sh
opencode-handover.sh --slug fix-retry-backoff-followup --dir <same dir> \
  --session ses_0005347d… --prompt-file "$SCRATCHPAD/handover-followup.md"
```

v2 `opencode session list` shows only sessions of the current project, so run it from the
target dir. `opencode stats` shows usage.

## Review discipline

**The final message is a claim, not evidence.** Before reporting anything to the user:

1. Read `diff.patch` (or `git diff`) yourself — that is what actually changed.
2. Run the repo's own gate/test command yourself. Do not accept "tests pass" from the
   transcript; a `--auto` run can also have run something you would not have allowed.
3. Check `meta.json` `errors` and the exit code. A non-zero exit with edits already on disk
   is the normal half-done case — decide whether to continue the session or revert.
4. Report token use and duration if the user cares about spend.

## Troubleshooting

- **`opencode is not on PATH`** — installed via nix (`~/.nix-profile/bin/opencode`); a stripped
  PATH in a subshell is the usual cause.
- **Auth failure** — `opencode auth list < /dev/null` must show "Kimi For Coding" as stored.
  Re-add with `opencode auth login`. Never run `opencode auth export`: it prints secrets.
- **Exit 1, no tools, no final message** — read `stream.jsonl` and `stderr.txt` first. A
  quota or provider error is usually a single line there. Probe the route cheaply with
  `opencode run --model kimi-code-plan-global/k3.1-pro 'Reply with exactly: OK' < /dev/null`.
  Do not switch to another provider without asking: it spends from a different account.
- **Hangs with no output** — something is calling `opencode` without `< /dev/null`.
  `meta.json` shows `timed_out: true` and an empty `stream.jsonl`.
- **Empty transcript, exit 0** — the model answered without tools. Check `prompt.md`: it
  probably read as a question rather than an instruction to edit files.
