#!/usr/bin/env node
// Turn an opencode --format json stream into transcript.md + meta.json, and
// print a summary small enough to paste into a Claude context.
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const TOOL_OUTPUT_LINES = 40;
const TOOL_OUTPUT_CHARS = 4000;

const flags = {};
for (let i = 2; i < process.argv.length; i += 2) {
  flags[process.argv[i].replace(/^--/, "")] = process.argv[i + 1];
}
const log = flags.log;
if (!log) {
  console.error("render-glm-log: --log is required");
  process.exit(2);
}

const events = [];
const streamPath = join(log, "stream.jsonl");
if (existsSync(streamPath)) {
  for (const line of readFileSync(streamPath, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed.startsWith("{")) continue;
    try {
      events.push(JSON.parse(trimmed));
    } catch {
      // A truncated final line means the run was killed; the rest still renders.
    }
  }
}

const clip = (value) => {
  const text = typeof value === "string" ? value : JSON.stringify(value ?? "", null, 2);
  const byLines = text.split("\n").slice(0, TOOL_OUTPUT_LINES).join("\n");
  const clipped = byLines.slice(0, TOOL_OUTPUT_CHARS);
  return clipped.length < text.length ? `${clipped}\n… (truncated, see stream.jsonl)` : clipped;
};

const label = (tool, input = {}) =>
  input.command ?? input.filePath ?? input.pattern ?? input.path ?? input.description ?? tool;

const tokens = { input: 0, output: 0, reasoning: 0, cache_read: 0, cache_write: 0 };
const toolCounts = {};
const filesTouched = new Set();
const errors = [];
const body = [];
let sessionId = null;
let cost = 0;
let finalText = "";

for (const event of events) {
  sessionId ??= event.sessionID ?? null;
  const part = event.part ?? {};
  switch (event.type) {
    case "text": {
      const text = (part.text ?? "").trim();
      if (text) {
        finalText = text;
        body.push(text, "");
      }
      break;
    }
    case "tool_use": {
      const tool = part.tool ?? "tool";
      const state = part.state ?? {};
      const input = state.input ?? {};
      toolCounts[tool] = (toolCounts[tool] ?? 0) + 1;
      if (/^(edit|write|patch|multiedit)$/i.test(tool) && input.filePath) {
        filesTouched.add(input.filePath);
      }
      body.push(`### ${tool} — ${label(tool, input)}`);
      if (state.status && state.status !== "completed") {
        body.push(`status: ${state.status}`);
      }
      const detail = state.metadata?.diff ?? state.output ?? state.error ?? "";
      if (detail) body.push("```", clip(detail), "```");
      body.push("");
      if (state.status === "error" || state.error) {
        errors.push(`${tool}: ${clip(state.error ?? state.output ?? "error").split("\n")[0]}`);
      }
      break;
    }
    case "step_finish": {
      cost += part.cost ?? 0;
      const t = part.tokens ?? {};
      tokens.input += t.input ?? 0;
      tokens.output += t.output ?? 0;
      tokens.reasoning += t.reasoning ?? 0;
      tokens.cache_read += t.cache?.read ?? 0;
      tokens.cache_write += t.cache?.write ?? 0;
      break;
    }
    case "error": {
      errors.push(clip(part.message ?? JSON.stringify(part)).split("\n")[0]);
      break;
    }
    default:
      break;
  }
}

const stderrPath = join(log, "stderr.txt");
const stderr = existsSync(stderrPath) ? readFileSync(stderrPath, "utf8").trim() : "";
if (stderr) errors.push(...stderr.split("\n").slice(-5));

const started = flags.started ?? null;
const ended = flags.ended ?? null;
const durationS =
  started && ended ? Math.round((Date.parse(ended) - Date.parse(started)) / 1000) : null;
const exitCode = Number(flags.exit ?? 0);
const timedOut = exitCode === 124 || exitCode === 137;
if (timedOut) errors.push("run hit the wall-clock cap and was killed");

const diffPath = join(log, "diff.patch");
const diff = existsSync(diffPath) ? readFileSync(diffPath, "utf8") : "";
const diffFiles = [...diff.matchAll(/^\+\+\+ b\/(.+)$/gm)].map((m) => m[1]);
const untracked = existsSync(join(log, "git-after.txt"))
  ? readFileSync(join(log, "git-after.txt"), "utf8")
      .split("\n")
      .filter((l) => l.startsWith("?? "))
      .map((l) => l.slice(3))
  : [];

const meta = {
  slug: flags.slug ?? null,
  model: flags.model ?? null,
  dir: flags.dir ?? null,
  session_id: sessionId,
  exit_code: exitCode,
  timed_out: timedOut,
  started_at: started,
  ended_at: ended,
  duration_s: durationS,
  cost_usd: Number(cost.toFixed(6)),
  tokens,
  tool_counts: toolCounts,
  files_edited: [...filesTouched],
  diff_files: diffFiles,
  untracked_files: untracked,
  errors,
  final_text: finalText,
  log_dir: log,
};
writeFileSync(join(log, "meta.json"), `${JSON.stringify(meta, null, 2)}\n`);

const header = [
  `# GLM handover: ${meta.slug}`,
  "",
  `- model: ${meta.model}`,
  `- dir: ${meta.dir}`,
  `- session: ${meta.session_id ?? "(none)"}`,
  `- exit: ${exitCode}${durationS === null ? "" : ` after ${durationS}s`}`,
  `- cost: $${meta.cost_usd}`,
  diffFiles.length ? `- changed: ${diffFiles.join(", ")}` : "- changed: (no tracked changes)",
  untracked.length ? `- new files: ${untracked.join(", ")}` : null,
  errors.length ? `- errors: ${errors.length}` : null,
  "",
  "## Transcript",
  "",
].filter((line) => line !== null);
writeFileSync(join(log, "transcript.md"), `${header.concat(body).join("\n")}\n`);

const summary = [
  `glm-handover ${
    exitCode === 0 ? "ok" : timedOut ? "TIMED OUT" : `FAILED (exit ${exitCode})`
  } — ${meta.slug}`,
  `log:     ${log}`,
  `session: ${meta.session_id ?? "(none)"}`,
  `cost:    $${meta.cost_usd}${durationS === null ? "" : `  time: ${durationS}s`}`,
  `tools:   ${Object.entries(toolCounts).map(([t, n]) => `${t}×${n}`).join(" ") || "(none)"}`,
  `changed: ${diffFiles.length ? diffFiles.join(", ") : "(no tracked changes)"}`,
  untracked.length ? `new:     ${untracked.join(", ")}` : null,
  errors.length ? `errors:\n  ${errors.join("\n  ")}` : null,
  "",
  finalText ? `GLM says:\n${finalText}` : "GLM produced no final message.",
]
  .filter((line) => line !== null)
  .join("\n");
console.log(summary);
