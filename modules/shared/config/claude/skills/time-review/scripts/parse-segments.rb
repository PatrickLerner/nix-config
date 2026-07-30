#!/usr/bin/env ruby
# frozen_string_literal: true

# Deterministic timing + participation extraction for the time-review skill.
#
# A Gemini "Notizen" doc has two usable parts:
#   1. A "Details" summary that segments the meeting into topic bullets, each
#      tagged with [HH:MM:SS] anchors. First anchor = topic start; the next
#      bullet's first anchor = its end. -> per-topic durations.
#   2. The full VERBATIM transcript, as "**Name:** ..." speaker turns. -> real
#      participation (words actually spoken), NOT who was talked about.
#
# This script owns all the arithmetic so the model never eyeballs clocks or
# guesses who spoke.
#
# Usage: parse-segments.rb <transcript.md>
# Output: JSON { meeting_min, first, last, segment_count, segments[], speakers[] }
#   segments[]: {idx,title,start,start_sec,duration_min,anchor_count,drivers,text}
#     - anchor_count > 1 => topic revisited / back-and-forth (overrun signal)
#     - drivers = attendees the summary credits with driving the topic
#   speakers[]: {name,turns,words,share_pct} from the verbatim transcript, sorted
#     by words spoken. This is airtime measured from actual turns — someone only
#     MENTIONED (e.g. "to free up Marvin's time") never appears here.

require "json"

path = ARGV[0] or abort "usage: parse-segments.rb <transcript.md>"
text = File.read(path)

TS = /\[(\d{1,2}):(\d{2}):(\d{2})\]/
def to_sec(h, m, s)
  h.to_i * 3600 + m.to_i * 60 + s.to_i
end

# --- participation from verbatim speaker turns ------------------------------
# A turn label is "**Firstname Lastname:**" — the colon sits INSIDE the bold,
# which distinguishes it from summary bullets ("**Topic title**:", colon outside).
LABEL = /\*\*([[:upper:]][[:alpha:]]+(?: [[:upper:]][[:alpha:]]+)?):\*\*/
parts = text.split(LABEL)
turns = Hash.new(0)
words = Hash.new(0)
# parts = [preamble, name1, chunk1, name2, chunk2, ...]
i = 1
while i < parts.length - 1
  name = parts[i]
  chunk = parts[i + 1].to_s
  turns[name] += 1
  words[name] += chunk.split(/\s+/).reject(&:empty?).length
  i += 2
end

total_words = words.values.sum
speakers = words.sort_by { |_n, w| -w }.map do |n, w|
  {
    "name" => n,
    "turns" => turns[n],
    "words" => w,
    "share_pct" => total_words.zero? ? 0 : (100.0 * w / total_words).round(1)
  }
end

# --- topic segments from the Details summary --------------------------------
details = text
if (i = text =~ /^\s*#+\s*.*Details/i)
  details = text[i..]
end
raw = details.split(/^\*\s+\*\*/).drop(1)

segments = []
raw.each do |chunk|
  title = chunk[/\A(.*?)\*\*/m, 1].to_s.strip
  stamps = chunk.scan(TS).map { |h, m, s| to_sec(h, m, s) }
  next if stamps.empty?

  # Credit a topic driver only if that person actually spoke in the meeting
  # (present in the verbatim transcript). Prevents crediting people who are
  # merely mentioned in the summary.
  drivers = speakers.map { |s| s["name"] }.select { |n| chunk.include?(n) }
  segments << {
    "title" => title,
    "start_sec" => stamps.min,
    "anchor_count" => stamps.length,
    "drivers" => drivers,
    "text" => chunk.gsub(/\s+/, " ").strip[0, 400]
  }
end

abort "no timestamped segments found in #{path}" if segments.empty?
segments.sort_by! { |s| s["start_sec"] }

# Meeting end = largest timestamp anywhere, incl. the plain (unbracketed)
# "meeting ended at HH:MM:SS" marker Gemini appends.
all = text.scan(/\b(\d{1,2}):(\d{2}):(\d{2})\b/).map { |h, m, s| to_sec(h, m, s) }
meeting_end = all.max
first = segments.first["start_sec"]

fmt = ->(sec) { format("%d:%02d:%02d", sec / 3600, (sec % 3600) / 60, sec % 60) }

segments.each_with_index do |seg, idx|
  nxt = segments[idx + 1]
  seg_end = nxt ? nxt["start_sec"] : meeting_end
  seg["idx"] = idx
  seg["start"] = fmt.call(seg["start_sec"])
  seg["duration_min"] = ([seg_end - seg["start_sec"], 0].max / 60.0).round(1)
end

puts JSON.pretty_generate(
  "meeting_min" => ((meeting_end - first) / 60.0).round(1),
  "first" => fmt.call(first),
  "last" => fmt.call(meeting_end),
  "segment_count" => segments.length,
  "segments" => segments,
  "speakers" => speakers
)
