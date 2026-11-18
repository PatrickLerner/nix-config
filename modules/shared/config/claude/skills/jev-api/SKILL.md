---
name: jev-api
description: Call Jev, TypeSafe's scoring model (api.typesafe.ai), to score any JSON state against rubric questions. Use when asked to score, rate, rank or classify profiles, jobs or texts with Jev or TypeSafe, or to test a rubric against it. "Jeff" or "Jev" in an Instaffo context means this model, not a person. In the app repo, production code calls it through `lib/jev_api.rb`; this skill is for raw, ad-hoc requests outside the app.
---

# Jev API (TypeSafe)

Jev answers questions about a JSON `state`. A `score` question returns the expected level as a float from 0 to (number of criteria − 1). It returns scores with a probability per level, no text or reasons.

- Endpoint: `POST https://api.typesafe.ai/v1/systemone`, `Authorization: Bearer $TYPESAFE_API_KEY`
- Model: `jev-1.13.0` (the app pins the same in `lib/jev_api.rb`)
- Key: `TYPESAFE_API_KEY` in `~/.secrets-env` (agenix `env-vars.age`). Never print it.
- Speed: about 0.3 s per request with 10 questions. Several questions in one request cost one round trip.

## Run

```bash
~/.claude/skills/jev-api/scripts/jev.rb request.json   # or pipe JSON on stdin
```

```json
{
  "state": { "role": { "title": "Head of Sales" }, "candidate_profile": { "work": [] } },
  "questions": {
    "leadership": {
      "type": "score",
      "instructions": "Rate the evidence in `candidate_profile` for leading teams, as needed for `role`.",
      "criteria": [
        "No evidence: nothing about leading teams.",
        "Weak: in passing, long ago or adjacent.",
        "Solid: clear, repeated evidence.",
        "Strong: a core, recent part of the profile at a senior level."
      ]
    }
  }
}
```

Output: `{"leadership": {"type": "score", "score": 1.68, "confidence": 0.7, "legend": {...}, "probabilities": {"0": 0.0, "1": 0.4, "2": 0.5, "3": 0.1}}}`. `score` is the expected level; `probabilities` holds the distribution over levels and `confidence` the top level's share.

## Writing questions

- Refer to state keys in backticks in `instructions`; Jev reads them as pointers into `state`.
- Criteria are ordered levels, lowest first. Four levels work well; each one says what evidence earns it.
- Divide by the top level (criteria count − 1) to normalise to 0–1 before you weight questions.
- Talent profiles are personal data: strip names and contact details from `state`.

## Known quality

On a Head of Sales rubric (10 questions, 8 talent profiles, 2026-11-18), Jev ranked the profiles in the same order as Claude Opus for the top 5, with per-question correlation 0.81 against Opus. The Apple on-device model failed the same test.
