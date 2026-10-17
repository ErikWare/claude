---
name: tokens
description: Real token use and cost of Claude Code sessions, read from the transcripts' usage records. Use when the user asks "how many tokens", "token use", "what did this cost", "context size", or when writing the handoff's `tok:` line.
---

# tokens

Run `python3 ~/.claude/skills/tokens/tokens.py` (from the project cwd). Flags: `--all` every session of the project,
`--session <id-prefix>`, `--dir <cwd>`. Subagent transcripts are included. Last line = one int: total tokens.

- Reply with the one line the user asked for (total, ctx, $), nothing else.
- Handoff: when the desk edits `.desk/HANDOFF-desk.md` anyway (a state change), set its `tok: <int>` line from this
  script's last line. Never run it or edit the handoff just to refresh the number.
- `ctx` (the last request's input) is the real context size: use it for the `~Nk` reply line when in doubt.
- Cost uses Opus 5.5 rates (in 4, cache write 8, cache read 0.4, out 20 $/1M); cache reads dominate long sessions.
