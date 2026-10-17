# Model Scaling

Model and effort per task (per code.claude.com/docs/en/model-config, 2026-09-26).

## Cost
| model | $ in / out per 1M | vs Opus 5.5 |
|---|---|---|
| Sonnet 5 | 2 / 10 | 0.5x |
| Opus 5.5 | 4 / 20 | 1x |
| Fable 5.1 | 10 / 50 | 2.5x |

**Haiku is banned** (2026-09-27: faked a passing check 3/3 despite GOAL-DRIVEN rule 3). Floor: Sonnet · low.

Model sets price per token, effort sets tokens: raise the model before maxing effort.

## Ladder
`claude --model <id> --effort <level>`

| rung | model · effort | use for |
|---|---|---|
| 1 | Sonnet · low | reading, exploring, grep, summaries, mechanical edits |
| 2 | Sonnet · medium | one-area fixes/features with a tight brief and tests |
| 3 | Opus · medium | multi-file builds and refactors (Opus default) |
| 4 | Opus · high | cross-component on an agreed contract (iOS ↔ API ↔ dashboard), concurrency, unclear bugs |
| 5 | Fable · low/medium | instead of Opus xhigh/max: architecture, contract design, root causes, tasks Opus failed at rung 4 |
| user OK only | Opus xhigh/max, Fable high+, `ultracode` | `max` overthinks; `ultracode` plans multi-agent workflows |

## Rules
- Start on the lowest fitting rung; move up one only after a failure the handoff explains, and log it.
- Big cross-surface work: Fable writes the spec once, cheaper workers build each side in parallel.
- **Fable briefs give the outcome, not steps**; Sonnet and Opus briefs stay prescriptive.
- Judge cost per finished task, redos included.
- Subagents never inherit Opus: `CLAUDE_CODE_SUBAGENT_MODEL=sonnet` in `~/.claude/settings.json`, and `model` passed explicitly anyway.
- Check real spend with `~/.claude/tools/tokens.py` about weekly; move rungs by the numbers.
