---
name: text-to-speech
description: Turn a text or markdown file (a letter, an article, a note) into one mp3 with Azure Speech. Use when Patrick asks to have something read aloud, turned into audio, or "voiced", especially Sophie's letters. Covers the script, voices, where the key lives, and the Sophie letter folder conventions.
---

# Run

```sh
~/.claude/skills/text-to-speech/scripts/tts.rb [--voice NAME] [--out FILE.mp3] INPUT.txt|md
```

- Writes one mp3 next to the input (`foo.txt` -> `foo.mp3`) and prints its path. Progress goes to stderr.
- Strips frontmatter, `![[embeds]]`, wikilink brackets, markdown markers. Paragraph breaks become a short pause.
- Splits at paragraph/sentence boundaries (default 1200 words per request; Azure caps one request at 10 min of audio), then joins with ffmpeg.
- Long letters (~15k words) take a few minutes. Run in the background.

# Key

`AZURE_SPEECH_KEY` and `AZURE_SPEECH_REGION` (eastus) live in `~/nix-secrets/env-vars.age` -> `~/.secrets-env`. The script reads that file itself, so it works from launchd/non-login shells too. Never print the key.

# Voices

- Default `en-US-JessaNeural` (what all earlier Sophie letters used; keep it for continuity).
- British: `en-GB-SoniaNeural`, `en-GB-RyanNeural`. German: `de-DE-KatjaNeural`, `de-DE-ConradNeural`.
- Language for SSML is taken from the voice name prefix.

# Sophie letters

Folder: `~/Library/CloudStorage/GoogleDrive-ptlerner@gmail.com/My Drive/Data Files/Sophie/`

- `YYYY-MM-DD-s.txt` = from Sophie, `YYYY-MM-DD-p.txt` = from Patrick. Audio sits next to it with the same stem.
- The vault copy (`~/Notes/2X People/Friends/Sophie/YYYY-MM-DD (from Sophie).md`) is the source of truth. If the Drive `.txt` is missing, copy the letter body there first (no image embeds, no captions).
- Reply drafts: `YYYY-MM-DD-p-DRAFT.md`. `count.sh` only counts `*-[sp].txt`, so drafts don't skew the word stats.
