# Model tiering: which model does which job

Subagents are spawned with a model chosen per task (the `model` parameter on
the Agent tool, or `model:` in a subagent file: `haiku`, `sonnet`, `opus`,
`fable`, a full model ID, or `inherit`). This page gives the selection rules.

## The ladder, with prices (checked 2026-09-24)

| Tier | ID to use | $/MTok in/out | vs. floor | Context |
|---|---|---|---|---|
| fable | `claude-fable-5-1` | 10 / 50 | 10× | 1M |
| opus | `claude-opus-5-5` | 4 / 20 | 4× | 1M |
| sonnet | `claude-sonnet-5` | 2 / 10 | 2× | 1M |
| haiku | `claude-haiku-4-5` | 1 / 5 | 1× | 200K |

Output is 5× input at every tier, so one ratio covers both. **Each step is
about 2×, except fable at 2.5× opus.** Tiering one step too high costs double;
the top costs ten times the floor. That is the number the rule below trades
against.

**Superseded, so not choices:** `claude-fable-5` (same price as 5.1),
`claude-sonnet-4-6` (1.5× Sonnet 5), `claude-opus-4-7`, `claude-opus-4-6`.
`claude-mythos-5-1` matches Fable 5.1 but needs program access. Two rows keep a
reason to exist: `claude-opus-4-8` is the only Opus with Priority Tier, and
`claude-opus-5` is not simply replaced by `claude-opus-5-5` — **5.5 defaults to
`medium` effort where 5 defaults to `high`**, so the move is 20% cheaper only
if you set effort explicitly.

**The alias hides the ID; a session doesn't.** A subagent named by tier picks up
whatever that alias maps to. A dispatched session takes a full ID, and that is
where a stale default hides: a day of sessions ran `claude-opus-5` while
`claude-opus-5-5` was newer and 20% cheaper. Nothing warned anyone.

**Re-check, don't trust.** Prices and IDs date. `GET /v1/models` lists what the
account can call, and the `claude-api` skill's table carries its own cached
date. Re-check on any release note, and whenever this table is over a quarter
old.

## The rule underneath all the others

> **Tier by the cost of an undetected error, not by how hard the task looks.**

A cheap model is fine for work that a script checks afterwards. If haiku
renumbers an ID wrong, `gates.sh ids` fails and the job is re-done. The check
is what makes the cheap model safe. An expensive model is required where
**nothing checks after it**, because its output *is* the check. That's why
the gate gets the strongest model, even though "compare a diff against a list
and run a suite" sounds easy.

It follows that you don't pick the tier until you've named the check that
runs after the work. If there isn't one, you're at the top tier, or you're
writing the check first.

## The table

| Work | Tier | Why | Width |
|---|---|---|---|
| **Desk / gate**: landing decisions, resolve-vs-refuse, reading reports against the brief | **strongest** (fable, else opus). Never downgraded. | It is the oracle, the last thing between a self-report and the trunk. In one day it caught a branch reporting "0 deleted" that had deleted seven definitions, and two branches that would have silently dropped test coverage. Every one of those passed every automated check. A cheap gate is a false economy. | 1 (the desk is serial by design) |
| **Contributor orchestrator**: holds one item's shape, briefs subagents, runs the done-check | opus, or sonnet for small well-specified items | It has to notice when a premise is wrong. The four premise corrections on record were all orchestrators measuring instead of complying. | 1 per slot |
| **Code edits** by a subagent, on disjoint files | sonnet. Opus for concurrency, security, data migration, or anything the suite can't see. | The done-check and the gate check this work afterwards, so a mid-tier model is enough when those checks are strong. Where they're weak, go up a tier. | ≤ 2 |
| **Research and audit**: read the docs, measure a claim, audit a module | sonnet, or opus for adversarial audits ("prove this claim wrong") | Its output feeds a decision, and nobody re-derives it. But it doesn't touch the trunk. | **1–2, never wide** |
| **Mechanical**: a clean rebase, renumbering an ID, moving an item to Done, reformatting, filling a template | haiku | A script verifies the result: rebase status, `gates.sh ids`, the suite. Its 200K window is the smallest on the ladder, so don't hand it a wide read. | ≤ 2 |

### Sharpened from the starting position

- **"Rebases are mechanical" is only true for clean ones.** A rebase with a
  conflict is a semantic decision (see resolve-vs-refuse in the `desk` skill). The
  rule for a cheap model: if the rebase conflicts, abort and report
  `BLOCKED`. **Never resolve.** The resolution goes up a tier, or back to the
  contributor.
- **Escalate, don't retry.** If a model's output fails its check once, re-run
  one tier up with the failure attached. Don't loop at the same tier. Two
  failed haiku runs cost more than one sonnet run, and they teach you nothing.
- **No subagent at all below the threshold.** For under ~2 files or ~100
  lines, the orchestrator does the work itself. A subagent's boot, reading and
  report cost more than the edit it saves.

## Width: serial or two at a time, never wide

A wide fan-out hit the rate limit and **lost every parallel thread at
once, twice**. The failure isn't gradual. The whole wave dies together, so
the work isn't slowed, it's lost. Three agents run two at a time came back
clean where the wide wave had failed. So:

- **At most two subagents in flight**, from any one session.
- **Every subagent prompt says "do not spawn sub-agents".** Without it, width
  compounds silently: two agents that each spawn three is eight.
- **Every subagent prompt also says "do not ask questions; if blocked, report
  it and stop".** A subagent's question tool can wedge it permanently.
- **Hand claims over as someone else's claims to test**, not as facts to
  confirm. "The brief says the schema blocks this, verify it" gets measured.
  "The schema blocks this" gets repeated.

## Effort is a second dial

Where your client exposes reasoning effort, it's cheaper than switching
tiers. Use high effort for the desk. Use low effort for mechanical work and
lookups where you already know the file.
