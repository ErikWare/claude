# Model Scaling

Pick the model and effort for each task. Checked against Anthropic's model-config guide (code.claude.com/docs/en/model-config) on 2026-09-26.

## Cost
| model | $ in / out per 1M tokens | vs Opus 5.5 |
|---|---|---|
| Sonnet 5 | 2 / 10 | 0.5x |
| Opus 5.5 | 4 / 20 | 1x |
| Fable 5.1 | 10 / 50 | 2.5x |

**Haiku is banned** (2026-09-27): it faked a passing check 3 times out of 3 and reported success. The floor is Sonnet · low.

The model sets the price per token. Effort sets how many tokens the model spends (thinking and tool calls). A stronger model at lower effort often beats a weaker model at max effort, so move up a model before pushing effort to the top.

## Ladder
Launch with `claude --model <id> --effort <level>`.

| rung | model · effort | use for |
|---|---|---|
| 1 | Sonnet · low | reading, exploring, grep, summaries, mechanical edits (Anthropic: "short, scoped… not intelligence-sensitive") |
| 2 | Sonnet · medium | one-area fixes and features with a tight brief and tests |
| 3 | Opus · medium | multi-file builds and refactors. This is Opus 5.5's own default |
| 4 | Opus · high | work across components where the contract is already agreed (iOS ↔ API ↔ dashboard), concurrency, bugs with an unclear cause |
| 5 | Fable · low/medium | instead of Opus xhigh/max: architecture, designing contracts, root-cause investigations, a task Opus failed at rung 4 |
| user OK only | Opus xhigh/max, Fable high+, `ultracode` | `max` is "prone to overthinking"; `ultracode` plans a multi-agent workflow per task |

## Rules
- Start on the lowest rung that fits. Move up one rung only after a failure the handoff explains, and log it.
- Split big cross-surface work: Fable writes the spec once, then cheaper workers build each side in parallel.
- **Briefs for Fable describe the outcome, not the steps.** It investigates and verifies on its own, and step-by-step prompts make its work worse. Briefs for Sonnet and Opus stay prescriptive.
- Judge cost per finished task, not per request. A cheap run that needs a redo isn't cheap.
- In-session subagents never inherit Opus: `CLAUDE_CODE_SUBAGENT_MODEL=sonnet` is set in `~/.claude/settings.json`, and the `model` is passed explicitly anyway.
- Check real spend with `~/.claude/tools/tokens.py` every week or so, and move rungs based on what the numbers show.
