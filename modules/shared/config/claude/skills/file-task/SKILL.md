---
name: file-task
description: Files, edits and closes Patrick's personal tasks in his Notes vault (~/Notes/tasks) with the karamd CLI. Use when Patrick asks to create a task, todo or reminder, to "schedule" something for later, to put something in his notes or task list, or to change or complete one. Never write task files by hand and never use the taskmd binary. For the file format itself see taskmd-format; for karamd flags in depth see karamd-cli.
---

# Filing tasks

Tasks live in the vault `~/Notes` (config `~/Notes/.taskmd.yaml`, files in
`~/Notes/tasks/`). Every write goes through `karamd`:

- Never create or edit a task file with Write, Edit, sed or a heredoc. karamd picks the
  id, the filename, `created_at` and the status timestamps.
- Never use `taskmd`. karamd is the tool for this vault.

## Create

```bash
karamd create --vault ~/Notes "Review feature naming enforcement" \
  --priority medium --phase later --due 2026-11-16 --tag work \
  --body "$(cat <<'MD'
# Review feature naming enforcement

Context in one or two lines. Links to the MR or issue go here.

## Tasks

- [ ] Step one
- [ ] Step two
MD
)"
```

- "Schedule it for X" or "remind me in N weeks" means `--due YYYY-MM-DD`. Compute the
  absolute date from today.
- Tags: `work` (Instaffo) or `personal`. Add more only when Patrick names them.
- Phases: `ongoing`, `now`, `next`, `soon`, `later`. Something due weeks out is `later`.
- Priority: `medium` unless Patrick says otherwise.
- Title: short, starts with a verb, no trailing period.
- Body: what to check or do, as a checklist, plus the links needed to do it. Write it
  so it makes sense in four weeks without this conversation.
- If karamd refuses because an open task has the same title, show Patrick the existing
  task (`karamd show <id>`) instead of passing `--force`.

## Change, complete, find

```bash
karamd list --vault ~/Notes 'status:pending AND tag:work'
karamd show --vault ~/Notes 456
karamd edit --vault ~/Notes 456 --due 2026-12-01 --body "..."
karamd status --vault ~/Notes 456 in-progress
karamd complete --vault ~/Notes 456
karamd cancel --vault ~/Notes 456
```

`edit` does not change status. Use `status`, `complete` or `cancel` for that.

## After writing

Run `karamd validate --vault ~/Notes` and report the new task's id and path.
