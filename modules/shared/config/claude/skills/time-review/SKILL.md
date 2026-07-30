---
name: time-review
description: Analyse a finished meeting from its transcript — where the time actually went per topic and per person, which discussions ran long, why the meeting ran over, and how to streamline the next one. Reads the Gemini "Notizen" doc from Google Drive (which carries [HH:MM:SS] anchors), computes real per-segment durations, compares them against the planned agenda, and writes a Time Review the time-keeper skill reuses to calibrate the next agenda. Trigger phrases: "time review", "analyse the meeting", "who took too long", "why did the meeting run over", "meeting retro", "how do we make the meeting shorter", "review last leadership meeting".
---

# Time Review

Post-mortem for a recurring meeting. Given the meeting's transcript, work out where the time really went, which topics overran their plan, who drove the longest discussions, why the meeting ran over, and what to change so the next one finishes on time. Writes a `## Time Review` block into the meeting notes file that the `time-keeper` skill reads to re-weight the next agenda — closing the plan → run → review loop.

**Division of labour** — same split as time-keeper. The script `scripts/parse-segments.rb` does the *clock arithmetic* (anchors → per-segment minutes). The model does the *judgement* (map segments to agenda items, read the discussion, write feedback). Never eyeball durations from raw timestamps.

## Prerequisites

- **`gws-work`** (Google Workspace CLI) + `ruby` + `jq`.
- The meeting transcript is a **Gemini "Notizen von …"** Google Doc. It segments the meeting into topic bullets, each tagged with `[HH:MM:SS]` anchor links — that's what makes timing recoverable. A doc without those anchors can't be timed; say so and fall back to a content-only review.

## Input

1. **Meeting date** (and name filter, e.g. "Leadership").
2. **The planned agenda** — optional but strongly preferred. If a `## Agenda` table from `time-keeper` exists in the meeting notes file (`7X Work Areas/Leadership Meeting/YYYY-MM-DD Leadership Meeting.md`), read it: comparing actual vs planned is the core of the review.

## Workflow

### Step 1 — Fetch the transcript

```sh
scripts/gws-fetch-meeting-transcript.sh work <YYYY-MM-DD> "<name filter>" <outfile>
```

Prints `path<TAB>name<TAB>lines` on success. Without a name filter it lists all docs from that day as TSV so you can pick the right one. (The script `cd`s into the output dir before exporting — the gws CLI rejects output paths outside its working directory.)

### Step 2 — Extract timing

```sh
ruby scripts/parse-segments.rb <outfile> > /tmp/segments.json
```

Returns:
- `meeting_min`, `first`, `last` — total wall-clock from first to last anchor.
- `segments[]` — each with `title`, `start`, `duration_min`, `anchor_count`, `drivers`, and a `text` excerpt. **`anchor_count` > 1 means the topic was revisited / went back-and-forth** — a strong overrun signal. `drivers` are attendees the summary credits with driving the topic (restricted to people who actually spoke).
- `speakers[]` — from the **verbatim transcript**: `turns`, `words`, and `share_pct` per person, sorted by words spoken. This is airtime measured from real speaker turns, so someone who was only *mentioned* (talked about, not present) never appears. Note the split between turns and words: many short turns with few words = interjector; few turns with many words = holds the floor.

### Step 3 — Map segments to agenda items

Segments are finer-grained than agenda items and include non-agenda time. Group them:

- **Agenda topics** — fold related segments into the matching OKR item (e.g. TPS/Google Ads/Multiposting/Flexsourcing segments → the CPI KR). Sum their minutes.
- **Overhead** — icebreaker/small-talk, wrap-up, logistics.
- **Off-agenda / emergent** — real topics that weren't on the plan (e.g. office-location, all-hands redesign). Call these out; they're a top reason meetings run over.

### Step 4 — Analyse

Produce:

1. **Actual vs planned** — per agenda item, planned min vs actual min, and the delta. Flag items that ran > ~50% over or under. If there's no planned agenda, just report actual distribution.
2. **Overran the whole meeting?** — `meeting_min` vs planned total. By how much, and which segments account for the overage.
3. **Longest discussions** — top segments by `duration_min` and by `anchor_count`. For each, one line on *why* it ran (open decision, disagreement, tangent, under-prepared).
4. **Participation** — `speakers` (words spoken + turns). Note anyone who dominated the floor and anyone near-silent. Distinguish floor-holders (high words) from interjectors (high turns, low words).
5. **Off-agenda time** — total minutes on emergent topics, **as a share of the meeting**. This share is the single most useful number for next time: it sets `emergent_pct` for the next `time-keeper` run. Name the recurring emergent topics — anything that shows up every meeting should become a real agenda item, not parking-lot time.
6. **Over-allocated items** — items that consistently finish in a few minutes. Recommend batching them into one quick-status round next time instead of a block each.

### Step 5 — Feedback

- **Group-level** — the 2-3 changes with the most impact: timebox the specific topic that always overruns, move a recurring emergent topic onto the agenda or into a separate session, pre-read for decision-heavy items, park rabbit-holes.
- **Individual** — only when the data clearly supports it, and keep it constructive and specific: e.g. "the AI-slop debate ran 13 min with no decision — pre-frame it as a yes/no next time." Attribute to the topic, not a character judgement. Skip individual feedback if the signal is thin.

Be direct and concrete. No filler. This is for Patrick's own use to run a tighter meeting.

### Step 6 — Write the review

Append a `## Time Review` section to the meeting notes file (same file the agenda lives in). Include:
- the actual-vs-planned table,
- overrun summary (meeting over/under by how much),
- longest discussions,
- participation (words + turns per speaker),
- **calibration hints for next time**, stated explicitly so `time-keeper` can act on them:
  - `emergent_pct` ≈ the measured off-agenda share,
  - which items to bump (consistent overruns),
  - which items to batch into the quick-status round (consistent under-runs),
  - any recurring emergent topic that should graduate to a real agenda item.

`time-keeper` reads this section next cycle. Be concrete: "off-agenda was 17% → set emergent_pct 0.15; CPI and activated-jobs ran ~2.5x their block → weight 5; batch CAC/invoicing/inactive/new-winback into one round."

## Notes

- MCP/CLI for data only — never scrape the browser or hit an API directly.
- Durations are as good as Gemini's segmentation. If two topics share one bullet, their split is an estimate — say so rather than inventing precision.
- Keep the written review tight. The value is the few changes that make the next meeting finish on time, not an exhaustive log.
