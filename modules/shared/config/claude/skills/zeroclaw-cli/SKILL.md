---
name: zeroclaw-cli
description: Operate the zeroclaw CLI, a self-hosted Rust AI agent runtime (single binary, connects LLM providers to channels like Telegram/Discord/email/CLI). Use when running any zeroclaw command, checking its subcommands, setting up cron/scheduled tasks, managing channels or memory, or debugging the daemon. Covers the traps: zeroclaw is NOT on PATH (run via nix-shell -p zeroclaw), cron 0.7.5 has no native channel delivery, and poisoned memories cause silent refusals.
---

# zeroclaw CLI

zeroclaw is a self-hosted Rust AI agent runtime: one binary that connects LLM providers to channels (Telegram, Discord, email, webhooks, CLI).

## The binary is not on PATH

`zeroclaw` is not on `$PATH`. Always wrap invocations:

```bash
nix-shell -p zeroclaw --run "zeroclaw --help"
nix-shell -p zeroclaw --run "zeroclaw <subcommand> --help"
```

**Always check `--help` via nix-shell before guessing CLI syntax.** Do not invent flags or subcommands. Config dir is `~/.zeroclaw/` (`config.toml` + `workspace/`). The `service` subcommand manages the OS service lifecycle (launchd on macOS).

## Subcommands (0.7.5)

```
onboard  agent  gateway  acp  daemon  service  doctor  status  estop
cron  models  providers  channel  integrations  skills  sop  migrate
auth  hardware  peripheral  memory  config  update  self-test
completions  desktop
```

`sop` has `list`, `validate`, `show` — there is **no** `sop run`. Manual execution goes through `cron`, `daemon`, or `agent`.

## Cron — the key trap

Two modes:
- **Without `--agent`**: runs a shell command, gated by `security.allowed_commands` in `config.toml`.
- **With `--agent`**: runs an agent prompt headlessly. **The response goes to the runtime trace log, NOT to any channel.**

**Cron on 0.7.5 has no native channel delivery.** Flags are only `--agent`, `--allowed-tool`, `--tz`, `--config-dir`. There is no `--announce`, `--channel`, or `--to` (web docs describing those refer to OpenClaw or unshipped features). To deliver scheduled output to a channel, use a **shell cron** that calls `zeroclaw channel send`:

```bash
# add "zeroclaw" to allowed_commands in config.toml first
zeroclaw cron add '0 9 * * *' \
  'zeroclaw channel send "Good morning" --channel-id telegram --recipient <CHAT_ID>' \
  --tz Europe/Berlin
```

For agent-generated content delivered to a channel, wrap it in a shell script in `~/bin/`:

```bash
#!/usr/bin/env bash
MSG=$(zeroclaw agent --prompt "Tell one short joke" 2>/dev/null | tail -1)
zeroclaw channel send "$MSG" --channel-id telegram --recipient <CHAT_ID>
```

Then `zeroclaw cron add '0 9 * * *' '/home/patrick/bin/daily.sh' --tz Europe/Berlin`, and add the script path to `allowed_commands`.

Other cron CLI:

```bash
zeroclaw cron list
zeroclaw cron pause   TASK_ID
zeroclaw cron resume  TASK_ID
zeroclaw cron remove  TASK_ID
zeroclaw cron update  TASK_ID --expression '0 8 * * *' --tz Europe/London
zeroclaw cron once    30s 'do thing' --agent
zeroclaw cron add-every 3600000 'do thing' --agent      # millis interval
zeroclaw cron add-at  2026-01-15T14:00:00Z 'do thing' --agent
```

## Gotchas

- **Poisoned memories cause silent refusals.** When the agent fails (tool error, gate block) it stores a `daily_*` memory like "user was unable to access X". On the next request it recalls that memory and refuses without ever calling the LLM. Symptom in the log: `No reply [Refused]` with no `Starting LLM call` between memory_recall and refusal. Fix:
  ```bash
  sqlite3 ~/.zeroclaw/workspace/memory/brain.db "DELETE FROM memories WHERE id LIKE 'daily_%';"
  ```
- **Intent classifier rejects DMs** as "not directed at the assistant" unless the message is unambiguous. Workarounds: use a stronger model (gpt-4o-mini misclassifies, gpt-4o is fine) and an aggressive `IDENTITY.md` ("this is a DM, always reply").
- **MCP tool names are prefixed `<server_name>__<tool_name>`** (double underscore) and must be added explicitly to the `auto_approve` list.
- **`mcp-obsidian` npm package ships broken schemas** (`type: None` instead of `type: object`), which OpenAI rejects with a 400. Use `@modelcontextprotocol/server-filesystem` instead — the vault is just markdown.
- **`ack_reactions = true`** in the telegram channel config makes the bot send emoji reactions instead of replies. Turn it off for normal behaviour.

## Deployment / host

zeroclaw runs on a self-hosted home server, not a VPS and not the Mac. The deploy + host config is a private NixOS flake checked out locally at **`~/Projects/dastyar`** (cloned via the `github-repos` agenix secret list; see `modules/darwin/home-manager.nix`). `./deploy.sh` pushes, the box pulls and runs `nixos-rebuild switch`. Read that repo's own `CLAUDE.md` for hardware, service definitions, vault sync, and backup. Service lifecycle is declarative there, not hand-managed with `loginctl`/`systemctl --user`.

State layout inside `~/.zeroclaw/` on the box (referenced by the fixes above):
- Workspace files read into the system prompt: `workspace/{IDENTITY,AGENTS,SOUL,USER,HEARTBEAT}.md`
- State DBs: `workspace/memory/brain.db`, `sessions/sessions.db`, `cron/jobs.db`, `devices.db`
