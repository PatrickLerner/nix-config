---
name: google-workspace-cli
description: Use the gws Google Workspace CLI (googleworkspace/cli) to read/write Google Docs, Drive, Sheets, Gmail, Calendar, Slides, Tasks and more. Use whenever a task needs Google Workspace data — export a Doc, list/search Drive files, read a Sheet, send/read mail, manage calendar events — instead of running `gws ... --help` to rediscover the invocation. Covers the two-account isolation (gws-work / gws-personal), the generic `<service> <resource> <method> --params/--json` shape, the schema-discovery command, export-writes-to-a-file behavior, and the ownedByMe listing trap. Includes helper scripts for the two most common ops.
---

# Google Workspace CLI (gws)

`gws` is a thin, generated wrapper over every Google Workspace REST API. Binary: `/Users/patrick/.nix-profile/bin/gws` (nix-managed). Every service/resource/method maps directly to an API endpoint, so the CLI shape is uniform and you drive it with JSON.

## Accounts — ALWAYS via a wrapper (never bare `gws`)

Bare `gws` has **no account isolation** and reads the default `~/.config/gws`. Always pick an account:

- `gws-work` → patrick@instaffo.com  (alias: `GOOGLE_WORKSPACE_CLI_CONFIG_DIR=$HOME/.config/gws-work gws`)
- `gws-personal` → ptlerner@gmail.com (alias: `GOOGLE_WORKSPACE_CLI_CONFIG_DIR=$HOME/.config/gws-personal gws`)

These are **shell aliases** (defined in nix home-manager). They work in the Bash tool (it loads the zsh profile) but **not inside `#!/bin/bash` scripts** — a script must set `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` itself and call bare `gws`. The helper scripts below do exactly that (first arg `work|personal`).

## Invocation shape

```
gws <service> <resource> [sub-resource] <method> [flags]
```

Key flags:
- `--params '<JSON>'` — URL/query + path params (fileId, q, pageSize, orderBy, fields, …)
- `--json '<JSON>'` — request **body** for POST/PATCH/PUT (create/update)
- `--upload <PATH>` — local file to upload as media
- `--output <PATH>` / `-o` — write binary/exported response to a file
- `--format json|table|yaml|csv` — default json
- `--page-all` + `--page-limit N` — auto-paginate (NDJSON, one line per page)
- `--dry-run` — validate locally, no API call

Services: `drive sheets gmail calendar docs slides tasks people chat classroom forms keep meet admin-reports script workflow`.

## Discover a method's params instead of guessing (`--help` alternative)

Don't run `... --help` and don't guess param names. Ask for the schema:

```
gws-work schema drive.files.list
gws-work schema drive.files.export --resolve-refs
gws-work schema sheets.spreadsheets.values.get
```

It prints httpMethod, `parameterOrder`, and every parameter with type/required/location. This is the fast path when you hit an unfamiliar method.

## Reading Google Docs — export, don't `documents get`

`gws docs documents get` returns the raw structural JSON (paragraph elements) — verbose and painful to read. **Export via Drive instead**, which gives clean markdown:

```
gws-work drive files export --params '{"fileId":"<id>","mimeType":"text/markdown"}' -o out.md
```

- Export **writes to a file** (default `download.txt`; use `-o`). It prints a JSON status blob (`{"bytes":...,"saved_file":...}`), not the content, plus a `Using keyring backend: keyring` line — filter that when parsing.
- **TRAP: `--output` is sandboxed to the working directory.** gws rejects any output path that resolves outside cwd — an absolute path like `-o /tmp/out.md` fails with `validationError: ... resolves to '...' which is outside the current directory`. With `set -euo pipefail` (and stderr suppressed) a script dies silently at this line. Fix: `cd` into the target dir and export the **basename** (`( cd "$dir" && gws ... -o "$(basename "$out")" )`). The `gws-export-doc.sh` helper does this.
- Useful export MIME types: `text/markdown`, `text/plain`, `application/pdf`, `text/csv` (Sheets), `application/vnd.openxmlformats-officedocument.wordprocessingml.document` (docx).
- For **Gemini meeting-note docs**, `text/markdown` returns the summary/decisions/next-steps AND the full transcript appended under a `# Transcript` heading. Read only the notes portion (usually the first ~100 lines) unless you need the transcript.

## Listing / searching Drive (the ownedByMe trap)

```
gws-work drive files list --params '{"q":"<drive query>","orderBy":"modifiedTime desc","fields":"files(id,name,createdTime,modifiedTime,owners(displayName,emailAddress))","pageSize":50}'
```

- `q` uses Drive query syntax: `mimeType='application/vnd.google-apps.document' and modifiedTime > '2026-07-09T00:00:00'`. Timestamps need a time component.
- **TRAP: do NOT pass `ownedByMe:true`.** It hides shared docs — Gemini meeting notes are owned by whoever organized the meeting, not by you, so recurring-meeting notes vanish from the results. The google-docs import depends on seeing those.
- Always narrow `fields` — the default response is huge.
- Doc mimeType `application/vnd.google-apps.document`; Sheet `...spreadsheet`; Folder `...folder`.

## Other services — quick shapes

```
# Sheets: read a range
gws-work sheets spreadsheets values get --params '{"spreadsheetId":"<id>","range":"Sheet1!A1:D50"}'
# Sheets: write a range (body via --json)
gws-work sheets spreadsheets values update --params '{"spreadsheetId":"<id>","range":"Sheet1!A1","valueInputOption":"RAW"}' --json '{"values":[["a","b"]]}'
# Gmail: list / get
gws-work gmail users messages list --params '{"userId":"me","q":"from:foo newer_than:7d"}'
gws-work gmail users messages get  --params '{"userId":"me","id":"<msgId>","format":"full"}'
# Calendar: list calendars, then events (family calendar: see the family-calendar skill)
gws-work calendar calendarList list --params '{"fields":"items(id,summary,accessRole,primary)"}'
gws-work calendar events list --params '{"calendarId":"primary","timeMin":"2026-07-13T00:00:00Z","singleEvents":true,"orderBy":"startTime"}'
```

Gmail sending: only on explicit send requests — see the `no-gmail-drafts` memory (never save drafts; put drafted text in the conversation/a file).

## Helper scripts (in this skill's `scripts/`)

Both take the account as first arg and set the config dir themselves, so they're safe from cron/non-interactive shells.

- `scripts/gws-list-docs-since.sh <work|personal> <ISO-date> [pageSize]`
  Lists Google Docs modified since a date, newest first, clean JSON, no ownedByMe filter. The import workhorse.
- `scripts/gws-export-doc.sh <work|personal> <fileId> [outfile] [mimeType]`
  Exports a Doc to a file (default `<id>.md`, markdown) and prints `path<TAB>N lines`.

Example — the google-docs import flow:
```
last=$(cat ~/Notes/.claude/.last-google-docs-import)
~/.claude/skills/google-workspace-cli/scripts/gws-list-docs-since.sh work "$last"
~/.claude/skills/google-workspace-cli/scripts/gws-export-doc.sh work <fileId> /path/out.md
```

## Notes / traps recap

- Keyring: uses the macOS keyring backend; a `Using keyring backend: keyring` line leaks to stdout on some commands — strip it before parsing JSON.
- Never `export GOOGLE_WORKSPACE_CLI_CONFIG_DIR` in a shell you reuse for the other account — it poisons subsequent calls. The wrappers/scripts scope it per-invocation.
- `--params` is query/path, `--json` is the body. Mixing them up is the most common create/update error.
- Related: `/Users/patrick/.claude/CLAUDE.md` (gws policy), the `family-calendar` skill (calendar ID), memories `gws-multi-account`, `no-gmail-drafts`.
