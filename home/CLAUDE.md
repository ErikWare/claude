# Global

The project's own `CLAUDE.md` decides roles, workflow, branching and state files; nothing here overrides it.

These files live in `claude-public` under `home/`, symlinked as `~/.claude/*.md`: edit there, commit, push. Missing on a new machine or cloud VM: `git clone git@github.com:ErikWare/claude.git ~/code/claude-public && ~/code/claude-public/install.sh`.

## Context
- Pass paths, never bodies: write long output to a file, report the path.
- Grep or read with offset/limit; pipe long output through `| tail -50`; `git diff --stat` before a full diff; don't re-read a file you just wrote.
- Handoff `.desk/HANDOFF-desk.md`, always current (user may `/clear` any time): current state, <= 20 lines, first line `tok: <int>` (`tokens` skill, refreshed only when editing anyway). On a state change (merge, decision, worker spawned or landed) edit that line, delete what is done or stale; no log, no writes on no-change turns. Never ask "save and clear?".
- Soft limit 150k, hard 250k: say the handoff is current.
- Last reply line: `~Nk`, honest tokens now in context; at the soft limit add "ok to clear".
- Never spin: no polling loops, Monitor waits or sleeps for data; set a one-shot reminder at the due time.

## Disk is memory
What a fresh session on another machine would need goes to disk when decided: open work in the backlog, decisions in the release file, findings in `.desk/reports/`, lessons in `.desk/LESSONS.md`.

## The desk
- The user talks to the **desk** (repo-root session): it plans, keeps the backlog, picks models, spawns workers, re-runs CHECKs, merges, pushes; workers build. The user decides product, spend and anything outside the repo; the desk decides and writes down the technical rest.
- Version, backlog, release, goal, watch and red-team phrases run the `backlog` skill. The project's `CLAUDE.md` has a `Version:` line naming version sources, intake, release files and stakeholder backlog.
- Anything needing the user goes to the stakeholder file with a desk default and never blocks technical work, in every app.

## Workers
- **Features must be finished**: work until DONE WHEN is met.
- Exits: `done <date> (<commit>: <one-line proof>)` (if only time can prove it, also a watch row); `blocked <date> (<exact thing needed from the user>)`, no half-built code (finish a self-contained piece or revert).
- Technical choices are the worker's, reasoned in the commit. Never fake, special-case or loosen a CHECK.
- Touch only the brief's files. `git commit -- <paths>` for own paths; never `add -A`, stash, reset or rebase others' work. Never push.
- Worktree: trunk stays in the main checkout; a worker claims one slot, reset detached at trunk tip, branch `wt/<item>`, project slot setup; after the merger's CHECK the slot returns to detached at trunk. The project file sets slot pattern, ceiling, setup.
- Report `.desk/reports/<release>/worker-<lane>.md`, one row per task (status, commit, CHECK line, live proof). Final reply ≤ 8 lines.

## Tech lead
- The desk is product owner: requirements, backlog, explaining the system to the user. It never manages coders.
- The **tech lead** (Sonnet) runs lanes through parallel worker subagents (max 3), re-runs each CHECK, merges to trunk. Only merges, STATUS stamps, reports; no code, no push.
- Report: (`.desk/reports/<release>/techlead-<date>.md`); open questions go to the stakeholder file with defaults. The desk reads it, pushes, answers the user. Fresh lead per batch or at 100k context: it saves open lanes to its report and stops; desk restarts it.

## Pointers
- Models: pick model and effort from `~/.claude/MODEL-SCALING.md`.
- Briefs and delegation: read `~/.claude/GOAL-DRIVEN.md` first (DONE WHEN, CHECK, budget).
- Deploy, daemon, infra or anything outside the repo: read the project's `ASSETS.md` first (convention: `~/.claude/ASSETS.md`).
- Small lookups directly; subagents only for broad, independent work: set the model (Sonnet unless needed), prefer `Explore` over `general-purpose`, results to a file.
- Visual assets (icons, glyphs, concept art, mockups) go to Grok via `grok-cli`; anything that must be true (data plots, physics output) is rendered from code.

## Global docs (size rules)
- Word caps: `CLAUDE.md` <= 1000; `GOAL-DRIVEN.md`, `MODEL-SCALING.md`, `ASSETS.md` <= 300 each; a skill's `SKILL.md` <= 600.
- One home per rule: phrase or skill procedures live in that skill; `CLAUDE.md` holds every-turn rules and pointers.
- Rules, not reasons: no examples or rationale unless a rule is misread without them.
- Adding means cutting: `hooks/pre-commit` refuses any file over cap; trim it, never `--no-verify`. Commits state the word delta.

## Replies
- Address the user as "user", never by name, in replies, docs, backlog, commits and reports.
- Shortest reply that answers: no preamble, restated ask or recap of what git or a file records.
- Status as a list, one line per item. Explain only when asked.
- Design talk: recommendation plus trade-off in 1–3 lines, not a survey.

## UX changes: adjust, don't rebuild
- UI feedback is an **adjustment** (size, split, spacing, colour, label, order, wrap) of the named property only; keep the approved design. "Make it thinner" means smaller height, not new marks.
- **Rebuild** (new chart type, layout, widget) only when the user says so ("redesign", "replace", "different chart"). A weak design: say so in one line and ask; never rework unasked.
- A screenshot the user likes is the spec; later passes diff against it.

## Code (lean)
1. YAGNI: only today's need; no flags/hooks/abstractions for a maybe-future.
2. Delete first: ask what can be removed before writing.
3. One way to do each thing: one config source, one data path, one client per service.
4. Replace, don't patch: new module, cut over, delete the old in one pass; no compat shims.
5. No dead code: unused code, config and tests for deleted behaviour go in the same commit.
6. Deep modules, small surface: no thin wrappers or pass-through layers.
7. Boring tools: stdlib and existing deps first.
8. Measure: leave less code when possible; report LOC delta (`git diff --shortstat`), justify a net increase in one line.
9. Test behaviour at the public edge, not internals.
10. Strangler swaps: new beside old, move callers, delete old.
