#!/usr/bin/env ruby
# frozen_string_literal: true

# Deterministic time allocation for the time-keeper skill.
#
# The model does the JUDGEMENT (assign a complexity weight per topic).
# This script does the MATH (turn weights into minute blocks that provably
# sum to the meeting length). Keeping arithmetic out of the model is what
# stops the agenda from drifting so the total no longer matches the meeting.
#
# Input: JSON on stdin
#   {
#     "total_min":     135,          # whole meeting length
#     "round_to":      5,            # granularity of every block
#     "min_per_topic": 5,            # floor per topic
#     "max_share":     0.40,         # cap: no topic > this fraction of discussion time
#     "start":         "09:00",      # meeting start (24h clock); optional
#
#     # Buffers — each may be given as absolute "<name>_min" OR as a fraction of
#     # the meeting "<name>_pct" (0..1). _min wins if both are present.
#     "intro_min":     10,           # fixed opening block
#     "wrapup_min":    10,           # fixed closing block
#     "flex_pct":      0.10,         # in-topic questions buffer
#     "emergent_pct":  0.15,         # parking lot for off-agenda / emergent topics
#
#     "topics": [ {"name": "...", "owner": "...", "weight": 3, "rationale": "..."}, ... ]
#   }
#
# Output: JSON with per-topic minutes + clock times and an `ok` flag. Every
# block is a multiple of round_to and
# intro + Sum(topics) + emergent + flex + wrapup == total_min, guaranteed.

require "json"

cfg = JSON.parse($stdin.read)

total  = cfg.fetch("total_min").to_i
step   = cfg.fetch("round_to", 5).to_i
floor  = cfg.fetch("min_per_topic", 5).to_i
maxshr = cfg.fetch("max_share", 1.0).to_f
start  = cfg["start"]
topics = cfg.fetch("topics")

abort "round_to must be > 0" if step <= 0
warnings = []

# Resolve a buffer given as <name>_min (absolute) or <name>_pct (fraction),
# snapped to a multiple of round_to.
resolve = lambda do |name, default_min = 0|
  if cfg.key?("#{name}_min")
    cfg["#{name}_min"].to_i
  elsif cfg.key?("#{name}_pct")
    ((total * cfg["#{name}_pct"].to_f) / step).round * step
  else
    default_min
  end
end

intro    = resolve.call("intro", 10)
wrapup   = resolve.call("wrapup", 10)
flex     = resolve.call("flex", 0)
emergent = resolve.call("emergent", 0)

[["total_min", total], ["intro", intro], ["wrapup", wrapup], ["flex", flex],
 ["emergent", emergent], ["min_per_topic", floor]].each do |name, v|
  warnings << "#{name} (#{v}) is not a multiple of round_to (#{step})" if v.positive? && (v % step != 0)
end

discussion = total - intro - wrapup - flex - emergent
if discussion <= 0
  puts JSON.pretty_generate("ok" => false,
                            "error" => "no discussion time left: #{total} - intro #{intro} - wrapup #{wrapup} - flex #{flex} - emergent #{emergent} = #{discussion}")
  exit 1
end

units_total = discussion / step
floor_units = floor / step
n = topics.length
if n.zero?
  puts JSON.pretty_generate("ok" => false, "error" => "no topics given")
  exit 1
end

if floor_units * n > units_total
  warnings << "cannot fit #{n} topics at #{floor} min each into #{discussion} min of discussion. " \
              "Batch low-weight status items into one block, cut items, shrink buffers, or extend the meeting. Floors overflow the budget."
end

# --- largest-remainder (Hamilton) apportionment ---------------------------
weights = topics.map { |t| [t.fetch("weight", 1).to_f, 0.0].max }
weights = Array.new(n, 1.0) if weights.sum <= 0 # all-zero -> equal split
wsum = weights.sum

surplus = [units_total - floor_units * n, 0].max
exact = weights.map { |w| surplus * w / wsum }
base  = exact.map(&:floor)
alloc = base.each_with_index.map { |b, i| b + floor_units }
leftover = surplus - base.sum
frac = exact.each_with_index.map { |e, i| [e - e.floor, i] }.sort_by { |f, i| [-f, i] }
leftover.times { |k| alloc[frac[k % n][1]] += 1 }

# --- max-share cap, with redistribution ------------------------------------
cap_units = (maxshr * discussion / step).floor
cap_units = units_total if cap_units <= 0
capped = Array.new(n, false)
loop do
  over = (0...n).select { |i| alloc[i] > cap_units && !capped[i] }
  break if over.empty?

  excess = 0
  over.each do |i|
    excess += alloc[i] - cap_units
    alloc[i] = cap_units
    capped[i] = true
    warnings << "topic '#{topics[i]["name"]}' capped at #{cap_units * step} min (#{(maxshr * 100).round}% of discussion); consider splitting or deferring it"
  end
  open = (0...n).reject { |i| capped[i] }
  break if open.empty?

  ow = open.map { |i| weights[i] }
  ow = Array.new(open.length, 1.0) if ow.sum <= 0
  ows = ow.sum
  ex_exact = open.each_with_index.map { |i, j| excess * ow[j] / ows }
  ex_base = ex_exact.map(&:floor)
  open.each_with_index { |i, j| alloc[i] += ex_base[j] }
  rem = excess - ex_base.sum
  ex_frac = ex_exact.each_with_index.map { |e, j| [e - e.floor, open[j]] }.sort_by { |f, i| [-f, i] }
  rem.times { |k| alloc[ex_frac[k % open.length][1]] += 1 }
end

# --- assemble output --------------------------------------------------------
def hhmm(mins)
  format("%02d:%02d", (mins / 60) % 24, mins % 60)
end

cursor = nil
if start && start =~ /\A(\d{1,2}):(\d{2})\z/
  cursor = Regexp.last_match(1).to_i * 60 + Regexp.last_match(2).to_i
end

rows = []
add = lambda do |name, mins, owner: nil, rationale: nil, kind: "topic"|
  row = { "name" => name, "min" => mins, "kind" => kind }
  row["owner"] = owner if owner
  row["rationale"] = rationale if rationale
  if cursor
    row["start"] = hhmm(cursor)
    row["end"] = hhmm(cursor + mins)
    cursor += mins
  end
  rows << row
end

add.call("Intro & Agenda Review", intro, rationale: "welcome, agenda, attendance", kind: "fixed") if intro.positive?
topics.each_with_index { |t, i| add.call(t["name"], alloc[i] * step, owner: t["owner"], rationale: t["rationale"]) }
add.call("Parking Lot (off-agenda / emergent)", emergent, rationale: "reserve for topics not on the agenda", kind: "emergent") if emergent.positive?
add.call("Flex / Questions", flex, rationale: "buffer for in-topic overruns and questions", kind: "flex") if flex.positive?
add.call("Wrap-up & Next Steps", wrapup, rationale: "decisions, action items, close", kind: "fixed") if wrapup.positive?

topic_sum = alloc.sum * step
grand = intro + topic_sum + emergent + flex + wrapup
ok = (grand == total) && warnings.none? { |w| w.include?("overflow") }

puts JSON.pretty_generate(
  "ok" => ok,
  "total_min" => total,
  "intro_min" => intro,
  "wrapup_min" => wrapup,
  "flex_min" => flex,
  "emergent_min" => emergent,
  "buffer_min" => intro + wrapup + flex + emergent,
  "buffer_pct" => (100.0 * (intro + wrapup + flex + emergent) / total).round,
  "discussion_min" => discussion,
  "allocated_min" => topic_sum,
  "grand_total_min" => grand,
  "start" => start,
  "rows" => rows,
  "warnings" => warnings
)
