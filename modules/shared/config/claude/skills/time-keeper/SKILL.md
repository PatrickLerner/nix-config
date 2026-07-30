---
name: time-keeper
description: Generate a time-blocked meeting agenda from an Asana OKR project. Reads each Key Result's latest update via the Asana MCP, scores how much discussion it needs, and a deterministic script allocates minutes so the blocks provably sum to the meeting length — reserving a parking-lot buffer for off-agenda topics and a flex buffer for questions, and batching trivial status items. Use when preparing a recurring OKR review (e.g. the leadership meeting) where each Asana task is an agenda item and its description is the latest status update. Trigger phrases: "time keeper", "agenda for the meeting", "time allocation for topics", "prepare OKR meeting", "meeting agenda from Asana", "allocate time per topic".
---

# Time Keeper

Build a time-blocked agenda for a recurring OKR meeting **before** it starts, while every update is already written in Asana. Each task in the OKR project is one agenda item. The task description (Asana `notes`) is the latest update to be discussed. The skill scores how much discussion each item needs, then a script turns those scores into minute blocks that add up to exactly the meeting length, leaving a flex buffer for questions so the meeting finishes on time.

**Division of labour — this is the whole point.** The model does *judgement* (read each update, assign a 1-5 weight). The script `scripts/allocate.rb` does *arithmetic* (weights → rounded minute blocks that provably sum to the total). Never let the model do the minute math by hand — that is what makes agendas drift so the total no longer matches the meeting.

## Prerequisites

- **Asana MCP** — the working connector is `mcp__claude_ai_Asana_2__*` (note the `_2` and the `asana_` tool prefix). A second connector `mcp__claude_ai_Asana__*` may also be installed with a *different* tool surface; do not use it. If an Asana tool name isn't loaded, fetch it with `ToolSearch`, query `select:mcp__claude_ai_Asana_2__<tool_name>`.
- **`ruby`** on PATH (for `scripts/allocate.rb`).
- **`gws-work`** (Google Workspace CLI) — only if the meeting start time has to be read from the calendar.

## Input the skill needs

1. **Asana OKR project** — URL, GID, or name. If not given, find it (Step 1).
2. **Total meeting duration** — default **135 min** (2h15m) for the leadership meeting. Confirm if unsure.
3. **Meeting start time** — for clock times. If not given, read the calendar (Step 5) or ask.
4. **Buffers** — reserve time for what reliably happens but isn't a topic. Defaults, informed by past reviews: intro 10, wrap-up 10, **emergent/parking-lot ~15%**, flex/questions ~5%. Off-agenda discussion is not noise — leadership meetings routinely spend ~15-20% on emergent topics, so budget it up front instead of letting it blow the clock. Each buffer takes either `<name>_min` (absolute) or `<name>_pct` (fraction of total).

## Workflow

### Step 1 — Find the OKR project

If given a URL/GID, use it. Otherwise:

1. `mcp__claude_ai_Asana_2__asana_list_workspaces` → workspace GID (Instaffo = `instaffo.com`, `681417510474145`).
2. `mcp__claude_ai_Asana_2__asana_typeahead_search` with `resource_type: "project"`, `opt_fields: "name,permalink_url,modified_at,owner.name"`. Try `Company OKR`, then `OKR`, then `OKRs Q<n>/<yy>`.
3. Prefer the project whose name has **Company OKR + the current quarter** (e.g. `Company OKRs Q3/26`), most recently modified. If still ambiguous, list candidates with `permalink_url` and ask.

### Step 2 — Read the board

With the project GID:

1. `mcp__claude_ai_Asana_2__asana_get_project_sections` (`opt_fields: "name"`) — sections are the **objectives**; they group the agenda. Ignore an empty "Untitled section".
2. `mcp__claude_ai_Asana_2__asana_get_tasks` with `project` = GID and `opt_fields: "name,notes,completed,assignee.name,modified_at,memberships.section.name"` — each task is a **Key Result** = one agenda item. `notes` is the latest update.
3. Drop `completed` tasks unless asked to keep them.
4. Only if an update references a prior debate you need context on: `mcp__claude_ai_Asana_2__asana_get_stories_for_task` (last few comments). Skip by default — the `notes` field is the update.

**Preserve the board order — this is non-negotiable.** The agenda lists items in the exact order `asana_get_tasks` returns them within each section (that is the order the board shows and the group reads top-to-bottom). Weight controls **how many minutes** an item gets, NEVER its position. Do not sort by weight, owner, or anything else. Feed the topics to `allocate.rb` in board order (the script preserves input order and only assigns minutes) and render the table in that same order.

### Step 3 — Score each item (weight 1-5)

Instaffo OKR updates follow a fixed template. Read the update and weigh it by **how much live discussion it will trigger**, not raw length:

- **🥶 Problems and decisions (blocker)** — the strongest signal. A non-empty blocker section, an open question (`❓`, "Do we want to…", "decision:"), or an unresolved debate means real discussion. Empty here → mostly a status report.
- **🎯 Next steps** — many items needing alignment or trade-offs raise the weight; a tidy list the owner just executes does not.
- **↗️ Progress** — dense results with surprising numbers invite questions; routine green metrics do not.
- **Strategic stakes** — company-level bets and reversals outweigh steady-state KRs.
- **Ignore noise** — URLs, Metabase/dashboard links and Asana asset embeds are not content; don't let link-heavy updates inflate the score.

| Weight | Profile |
|--------|---------|
| 1 | Empty or near-empty update, or pure green status, no decision |
| 2 | Status with one minor question |
| 3 | Several progress items, one decision, some discussion |
| 4 | Complex update, multiple decisions or a live blocker |
| 5 | Strategic, unresolved debate the group must settle |

Empty `notes` → weight 1 **and** flag it: "no update provided — confirm if this item is needed".

**Batch the trivial ones.** Each agenda item costs at least `min_per_topic` (5 min). Five weight-1 KRs as separate lines burn 25 min on floors alone. Instead, merge low-weight status items into **one** "quick status round" line (weight 2-3 for the batch). Don't give a 3-minute update its own 5-minute block five times over — that is exactly the over-allocation the last review exposed. **A batch may only merge items that are ADJACENT on the board** (same section, consecutive rows) — merging non-adjacent items would break board order. Never batch across a higher-weight item that sits between them.

Apply calibration from the last review first (see [Calibration](#calibration)).

### Step 4 — Allocate time (deterministic)

Build a JSON payload and pipe it to the script. **Do not compute minutes yourself.**

```sh
ruby scripts/allocate.rb <<'JSON'
{
  "total_min": 135, "round_to": 5, "min_per_topic": 5, "max_share": 0.40, "start": "09:00",
  "intro_min": 10, "wrapup_min": 10, "flex_pct": 0.05, "emergent_pct": 0.15,
  "topics": [
    {"name": "<KR name>", "owner": "<assignee>", "weight": <1-5>, "rationale": "<one line: why this long>"}
  ]
}
JSON
```

The script returns each block with `min`, `start`, `end`, plus `ok`, `grand_total_min`, `buffer_pct`, and `warnings`. Contract: every block is a multiple of `round_to` and `intro + Σtopics + emergent + flex + wrapup == total_min`. The **Parking Lot (emergent)** and **Flex/Questions** rows are the slack that keeps the meeting from running over; report `buffer_pct` so the user sees how much of the meeting is held in reserve.

- If `ok` is `false` (e.g. floors overflow the budget because there are too many items), relay the warning and help triage: cut items, merge low-weight ones, shorten buffers, or extend the meeting. **Do not** hand-patch the numbers.
- Read `warnings` even when `ok` is `true` — capped topics and non-multiple buffers surface there.
- **Compression note:** with many items (~10 KRs) the per-topic floor eats most of the discussion budget, so weights barely differentiate and almost everything lands near the floor. When that happens, say so — the real lever is fewer agenda items or a longer meeting, not finer weighting.

### Step 5 — Clock times & confirmation

If no start time was given, read it from the calendar:

```sh
gws-work calendar events list --params '{"calendarId":"primary","timeMin":"<today>T00:00:00Z","timeMax":"<today>T23:59:59Z","singleEvents":true,"orderBy":"startTime"}'
```

Find the meeting by name, take its start, and pass `start` to the script. Present the agenda as a markdown table grouped by objective:

| Time | Item | Owner | Min | Why this long |
|------|------|-------|-----|---------------|
| 09:20-09:35 | <KR name> | <assignee> | 15 | open decision in the blocker section, unresolved |

State the end time and confirm the meeting fits. Ask the user to adjust (move/lengthen/shorten/drop an item, add a break) — re-run the script with edited weights or buffers, never by editing minutes directly. **The agenda is a proposal; the human has final say on every block.**

### Step 6 — Write the agenda

After confirmation, write it to the meeting notes file:

- Leadership Meeting → `7X Work Areas/Leadership Meeting/YYYY-MM-DD Leadership Meeting.md`
- Other → ask for the location.

Put the confirmed agenda table at the **top** of the file, before notes get taken. The printed clock times are what keeps the meeting on track.

## Calibration

Before scoring, check the previous meeting's notes file for a `## Time Review` section (produced by the `time-review` skill). Use it three ways:

- **Weights** — an item that ran well over its block gets a higher weight; one that finished early gets cut (and probably batched).
- **Batching** — items the review shows at only a few minutes each belong in the quick-status round, not on separate lines.
- **Emergent buffer** — set `emergent_pct` from the measured off-agenda share last time (e.g. review found 17% off-agenda → `emergent_pct` ≈ 0.15). Recurring emergent topics that keep reappearing should graduate to a real agenda item.

Note in the rationale when a weight was calibrated from the last review rather than the update alone. This closes the loop: plan → run → review → re-plan.

## Notes

- MCP for data gathering only — never hit the Asana REST API directly.
- >25 active tasks on the board → flag it and suggest triaging before the meeting. No agenda survives 25+ items in two hours.
- Group items by Asana section (objective) in the agenda — it matches how the meeting flows.
