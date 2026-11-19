---
name: jeff-local
description: Run Firelex's open-source Jeff decision model on this Mac (clone in ~/Projects/jeff, MLX) and send it ad-hoc decisions. Use when asked to run, start, stop, update or benchmark local Jeff, to classify or route text offline, or to compare local Jeff against Jev. Not the hosted TypeSafe Jev API (api.typesafe.ai, needs TYPESAFE_API_KEY): that is jev-api. Not Ollama: Jeff is a classifier and needs its own engine.
---

# Local Jeff

Jeff (github.com/firelex/jeff) is a Qwen3.5-0.8B fine-tune that uses Jev's request format. It returns a calibrated probability per option from one forward pass and generates no text. English only.

- Script: `~/.claude/skills/jeff-local/scripts/jeff.rb` (alias `jeff-local`)
- Repo: `~/Projects/jeff` (override with `JEFF_HOME`), venv from `uv sync`
- Weights: `~/.cache/huggingface/hub/models--mstrasser--jeff-base`, 1.7 GB bf16
- Runtime state: `~/.cache/jeff/` (socket, pids, `engine.log`, `server.log`)
- Endpoint: `POST http://127.0.0.1:8765/v1/systemone` (override with `JEFF_PORT`)

## Run

```bash
jeff-local setup                 # clone or git pull, then uv sync
jeff-local start                 # base model only; the first start downloads it
jeff-local start guard spam      # load catalogue adapters by name instead (jeffhub.ai/catalogue)
jeff-local decide request.json   # or pipe JSON on stdin; prints answers plus _server_ms
jeff-local status
jeff-local stop                  # always stop it when done
```

`start` picks the newest base in `catalogue/bases.yaml`. The engine refuses any base or adapter version not listed there, so after `setup` pulls a new release, adapters must match it.

## Request

```json
{
  "state": {
    "message": "Hi, I applied last week and heard nothing. Is the job still open?"
  },
  "questions": {
    "intent": {
      "type": "choice",
      "instructions": "What does the talent want?",
      "criteria": {
        "1": "Status of an application",
        "2": "Delete my account",
        "3": "Report a bug"
      }
    },
    "urgent": {
      "type": "noul",
      "instructions": "Does this need a human reply today?"
    },
    "mood": {
      "type": "score",
      "instructions": "How satisfied is the writer?",
      "criteria": ["Furious", "Unhappy", "Mixed", "Happy", "Delighted"]
    }
  }
}
```

- `choice`: up to 254 options; returns `probabilities`, `choice`, `confidence`.
- `noul`: yes/no; returns `noul`, the probability of yes.
- `score`: ordered `criteria` list, lowest first, required; returns `score` (expected level) and `probabilities`.
- State each option's consequence in words. Jeff picks between options, it does not reason over several steps.

## Measured (M5 Pro, base v1.4, 2026-11-18)

About 30 ms per question warm (p50 over 50 runs), 70 ms for two questions over 260 tokens. The first call after start takes about 3.5 s. Clear cases came back at 0.88 to 0.998 confidence. Vague ones (urgency, a game move) came back near 0.5, which is the signal to pass the case to a bigger model.
