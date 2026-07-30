---
name: family-calendar
description: Resolves "the family calendar" to its concrete Google Calendar ID and gives the gws CLI invocations for reading and writing it. Use whenever Patrick refers to the family calendar, family events, or shared household scheduling — so events land on the right calendar instead of his primary one.
---

# Family calendar

When Patrick says **"family calendar"** (or family events / shared household calendar), it means this calendar, NOT his primary "Home" calendar:

```
family10196146646255952325@group.calendar.google.com
```

Shared with Samira. It lives on the **personal** account (`ptlerner@gmail.com`), so every call goes through `gws-personal` — never `gws-work`. See the `google-workspace-cli` skill for the general CLI shape.

## Invocations

```bash
# list upcoming events
gws-personal calendar events list --params '{"calendarId":"family10196146646255952325@group.calendar.google.com","timeMin":"2026-08-01T00:00:00Z","singleEvents":true,"orderBy":"startTime"}'

# create an event (--params is path/query, --json is the body)
gws-personal calendar events insert \
  --params '{"calendarId":"family10196146646255952325@group.calendar.google.com"}' \
  --json '{"summary":"Zahnarzt Samira","start":{"dateTime":"2026-08-03T10:00:00","timeZone":"Europe/Berlin"},"end":{"dateTime":"2026-08-03T11:00:00","timeZone":"Europe/Berlin"}}'

# all-day event: use date instead of dateTime, end date is exclusive
--json '{"summary":"Urlaub","start":{"date":"2026-08-10"},"end":{"date":"2026-08-15"}}'

# change or delete an existing event (eventId from the list call)
gws-personal calendar events patch  --params '{"calendarId":"family1019...@group.calendar.google.com","eventId":"<id>"}' --json '{"summary":"new title"}'
gws-personal calendar events delete --params '{"calendarId":"family1019...@group.calendar.google.com","eventId":"<id>"}'
```

Add `--dry-run` to validate params and body without hitting the API.

## Rules

- **Never** substitute `primary` for the family calendar.
- Times are `Europe/Berlin` unless stated otherwise.
- If an action needs a different calendar, resolve it instead of guessing:
  `gws-personal calendar calendarList list --params '{"fields":"items(id,summary,accessRole,primary)"}'`
  (Personal account has: `Home` = primary, `Sleeping Shedule`, `Family`.)
- Still ambiguous which calendar is meant? Pause and ask.
- Before creating an event, list the target range first to avoid duplicates.
