#!/usr/bin/env node
// Parse a Google Admin "Meet log events" CSV export into per-person attendance.
// Usage: parse-meet-log.js <export.csv> [--invited a@x.com,b@x.com]

const fs = require('fs');

const [, , file, ...rest] = process.argv;
if (!file) {
  console.error('usage: parse-meet-log.js <export.csv> [--invited a@x.com,b@x.com]');
  process.exit(1);
}
const invIx = rest.indexOf('--invited');
const invited = invIx === -1 ? [] : (rest[invIx + 1] || '').split(',').map(s => s.trim()).filter(Boolean);

// RFC4180: fields may contain embedded newlines and doubled quotes
function parseCsv(s) {
  const rows = [];
  let row = [], field = '', inQuotes = false;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (inQuotes) {
      if (c === '"') { if (s[i + 1] === '"') { field += '"'; i++; } else inQuotes = false; }
      else field += c;
    } else if (c === '"') inQuotes = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n') { row.push(field); field = ''; rows.push(row); row = []; }
    else if (c !== '\r') field += c;
  }
  if (field || row.length) { row.push(field); rows.push(row); }
  return rows;
}

const rows = parseCsv(fs.readFileSync(file, 'utf8'));
const hdr = rows[0];
const col = name => hdr.indexOf(name);
const [cEvent, cActor, cName, cDur, cStart] =
  ['Event', 'Actor', 'Actor name', 'Duration (seconds)', 'Start time'].map(col);

// Only "Endpoint left" rows carry attendance; there are no join events.
const people = new Map();
for (const r of rows.slice(1)) {
  if (r[cEvent] !== 'Endpoint left') continue;
  const email = r[cActor];
  if (!email) continue;
  const p = people.get(email) || { name: r[cName], seconds: 0, sessions: 0, first: null };
  p.seconds += parseFloat(r[cDur]) || 0;
  p.sessions++;
  if (!p.first || r[cStart] < p.first) p.first = r[cStart];
  people.set(email, p);
}

const attended = [...people.entries()]
  .map(([email, p]) => ({ email, ...p, mins: p.seconds / 60 }))
  .sort((a, b) => b.mins - a.mins);

console.log(`Attended: ${attended.length}\n`);
for (const a of attended) {
  const rejoin = a.sessions > 1 ? `  (${a.sessions} sessions)` : '';
  console.log(
    `${a.mins.toFixed(1).padStart(6)} min  joined ${(a.first || '').slice(11, 16)}  ${a.name || a.email}${rejoin}`
  );
}

if (invited.length) {
  const local = e => e.split('@')[0].toLowerCase();
  const present = new Set([...people.keys()].map(local));
  const absent = invited.filter(e => !present.has(local(e)));
  console.log(`\nInvited but absent: ${absent.length}`);
  for (const e of absent) console.log(`  ${e}`);
}
