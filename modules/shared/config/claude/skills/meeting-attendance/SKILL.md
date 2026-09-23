---
name: meeting-attendance
description: Determine who actually attended a Google Meet, using the Meet log events audit report (join/leave with durations) rather than the invitee list. Use whenever the question is who was in a meeting, who was missing, who skipped, or whether someone joined — and before writing an "Attendees:" line into any meeting note. Covers the two traps that produce wrong answers: Gemini notes list invitees not attendees, and calendar RSVP status does not predict attendance.
---

# Meeting attendance

## The three traps

**Gemini meeting-note docs list invitees, not attendees.** The header line and the "Invited ..." line in the Full notes section are both the calendar invite list. A struck-through name (`~~Name~~`) means that person *declined the invite*, not that they were the only absentee. Gemini never records who joined.

**Calendar RSVP does not predict attendance.** `responseStatus: needsAction` is the default for people who ignore invites and attend anyway. Both error directions occur in practice: someone who never responded attended the full meeting, and someone who accepted never joined.

**Transcript speakers are a floor, not the answer.** Anyone silent is invisible. One observed meeting had 9 speakers and 13 attendees.

Only the Meet log events report answers the question. If none of it is available, label the line `Invited:` and say so — never write `Attended:` without Meet log data behind it.

## Path A: Admin console UI (preferred)

https://admin.google.com/ac/sc/investigation?ref=reporting&journey=218

Reporting → Audit and investigation → **Meet log events**. Filter on **Meeting code**: take the `xxx-xxxx-xxx` from the event's `hangoutLink` and enter it uppercased without hyphens. Export to CSV, then:

```sh
node ~/.claude/skills/meeting-attendance/scripts/parse-meet-log.js ~/Downloads/export.csv
```

Add `--invited a@example.com,b@example.com` to also get the absentee list.

Get the meeting code and invitee list from the calendar first:

```sh
gws-work calendar events list --params '{"calendarId":"primary","timeMin":"2026-09-18T00:00:00Z","timeMax":"2026-09-19T00:00:00Z","singleEvents":true,"q":"<meeting title>","fields":"items(summary,start,hangoutLink,conferenceData(conferenceId),attendees(email,responseStatus))"}'
```

The export needs the Workspace **Reports** admin privilege. Ask the user to run it; they hold it.

## Path B: gws API — currently blocked, do not retry blind

```sh
gws-work admin-reports activities list --params '{"userKey":"all","applicationName":"meet","startTime":"...","endTime":"...","maxResults":500}'
```

Returns `403 insufficientPermissions` (verified 2026-09-21). Unblocking needs all of:

1. Admin SDK (`admin.googleapis.com`) enabled on the GCP project backing the gws OAuth client — see `project_id` in `gws-work auth status`.
2. A gcloud login as the account that **owns** that project. The gws client project may belong to a different Google account than the one whose Workspace you are querying, in which case the querying account gets `PERMISSION_DENIED` on `serviceusage.services.enable`.
3. Scope `https://www.googleapis.com/auth/admin.reports.audit.readonly` added to the gws token.

Likely fourth blocker: an OAuth client in a personal GCP project calling the Admin SDK against a company tenant can be refused by Workspace API controls.

Four interactive steps to replace one browser export. Not worth it — use path A.

If it ever is worth it, build the re-auth command from the live token; `gws-work auth login --scopes` **replaces** the scope set rather than adding to it, and dropping a scope breaks Drive/Gmail/Calendar until consent is redone:

```sh
gws-work auth status 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s.replace(/^Using keyring.*\n/,""));console.log("gws-work auth login --scopes \""+[...j.scopes,"https://www.googleapis.com/auth/admin.reports.audit.readonly"].join(",")+"\"")})'
```

## Reading the CSV

Only `Endpoint left` rows carry attendance. There are **no join events**: `Start time` is the join and `Duration (seconds)` the session length; the `Date` column is the leave time. One person can produce several rows after dropping and rejoining, so sum durations rather than counting rows. Other event types (`Reaction sent`, `Hand raised`, `Streaming session decision`) are noise here.

Actor emails in the log can differ from calendar invite emails on the domain (`user@company.com` vs `user@company.de`), so match on the local part when diffing against the invitee list.
