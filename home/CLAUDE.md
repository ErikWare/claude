# Global

Each project runs itself. The project's own `CLAUDE.md` decides roles, workflow, branching and state files; follow it. Nothing here overrides a project file.

This file and its siblings (`GOAL-DRIVEN.md`, `MODEL-SCALING.md`, `ASSETS.md`) are versioned in the `claude-public` repo under `home/`. `~/.claude/*.md` are symlinks into it. Edit there, commit, push. Missing on a new machine or cloud VM: `git clone git@github.com:ErikWare/claude.git ~/code/claude-public && ~/code/claude-public/install.sh`.

## Context
- Every token is re-read on every later turn. Pass paths, never bodies: write long output to a file and report the path.
- Grep or read with offset/limit. Pipe long command output through `| tail -50`. Run `git diff --stat` before any full diff. Don't re-read a file you just wrote.
- Soft limit 150k: save state to disk, then `/compact` or `/clear`. Hard limit 250k: write a handoff and stop.
- End every reply with a last line `~Nk`: an honest estimate of the tokens now in context. At the soft limit, add "save and clear?" to that line.

## Disk is memory
The conversation is disposable; the repo is not. Anything a fresh session on another machine would need goes to disk the moment it is decided: open work in the backlog, decisions in the release file, findings in `.desk/reports/`, lessons in `.desk/LESSONS.md`. A session that only "remembers" something has lost it.

## The desk
In a project, Erik talks to the **desk**: the session at the repo root. It plans, keeps the backlog, picks models, spawns workers, re-runs their CHECKs, merges and pushes. Workers build. Erik decides product, spend and anything outside the repo; everything technical the desk decides and writes down.

Version and backlog phrases ("check the version", "status", "increment the version", obsolete items) run the `backlog` skill (`~/.claude/skills/backlog`). Each project's `CLAUDE.md` carries a `Version:` line naming its version sources, intake, release files and stakeholder backlog.

**Versions are accountable.** Every release file opens with **Goals**: what the app does when that version ships, each with a Validate line. Erik signs them off at open. A version is done only when the desk has validated every goal and written `.desk/reports/<version>/goals.md`; then it tags. **Stakeholder backlog:** anything needing Erik goes to the project's stakeholder file with a desk default and never blocks technical work. This applies to every app.

What Erik's phrases mean (default unless the project file says otherwise):
- **"pick up" / "where are we"**: read the project `CLAUDE.md`, the open release file, then `grep -H "STATUS: open\|STATUS: doing\|STATUS: blocked"` over the backlog. Report the status list and keep going without waiting.
- **"list the backlog"**: one line per item, `- **ID** — short what (≤15 words)`, grouped by tier or lane in dispatch order, `[ERIK]` on items waiting on him. No prose, no evidence, no Done items unless asked.
- **"have Fable build a v2.N backlog"**: Fable (outcome brief, not steps) writes the release file `backlog/v2.N.md` (or the project's equivalent): consolidates open items, carries leftovers from v2.N-1 (audit file), merges duplicates (stamp the old item `moved <date> -> v2.N <ID>`), and runs a fresh gap analysis. The file has: a header (sources, rules path), a **Lanes** table `lane | items (order) | files (owner) | model`, **Goals** (see above), numbered **Decisions** (final for the release), then one `##` item per task in the GOAL-DRIVEN brief plus `WHY:` and `STATUS:`. Then a red-team pass (fidelity: specifics kept; plan: CHECKs runnable, lane order sound), fixes applied, before any worker starts.
- **"work on v2.N" / "kick it off"**: one background worker per lane, same message, each in its own worktree, items in lane order. Worker prompt: read the worker rules + the release file's Lanes row, Decisions and its items in full. The desk re-runs each CHECK itself before merging.
- **"also build v2.N+1"**: new finds during v2.N go to today's intake, never into the open release file; Fable consolidates v2.N+1 in parallel. An item lives in one release file only.
- **"simplify review"**: after a release, a pass whose only goal is less code, fewer rows/ports/tabs; findings become items in the next release.
- **"red team it"**: independent agents attack the plan or the build and write `.desk/reports/<release>/redteam-<topic>-<date>.md`; the desk applies or rejects each finding in one line.

## Workers
- **Features must be finished.** A task is worked until DONE WHEN is met. No partial work.
- Exits: `done <date> (<commit>: <one-line proof>)`; `code-done <date> (soak until <t>)` for things only time can verify; `blocked <date> (<exact thing needed from Erik>)` with no half-built code left behind (finish a self-contained piece or revert).
- Technical choices are the worker's: pick the sound option and write the reason in the commit. Never fake, special-case or loosen a CHECK.
- Touch only the brief's files. Commit own paths only (`git commit -- <paths>`); never `add -A`, stash, reset or rebase others' work. Never push; the desk pushes.
- Report: `.desk/reports/<release>/worker-<lane>.md`, one row per task (status, commit, CHECK line, live proof). Final reply ≤ 8 lines.

## Models
Pick model and effort per task from `~/.claude/MODEL-SCALING.md`.

## Tasks
Before you write a brief or delegate work, read `~/.claude/GOAL-DRIVEN.md` (every task gets a checkable DONE WHEN, a CHECK command and a budget).

## Assets
Before you touch deploy, a daemon, infra or anything outside the repo, read the project's `ASSETS.md` (convention: `~/.claude/ASSETS.md`).

## Subagents
- Do small lookups directly. Spawn a subagent only for broad, independent work.
- Always set its model (Sonnet unless the task needs more), prefer `Explore` over `general-purpose`, and have it write results to a file.

## Images
Visual assets (icons, glyphs, concept art, mockups) go to Grok via the `grok-cli` skill. Anything that must be true (data plots, physics output) is rendered from code, never generated.

## Worktree development
- Trunk stays in the main checkout. Each worker gets one slot (a worktree) and one branch, claims it, builds, commits, and releases it.
- Claim: create or reset the slot detached at trunk tip, branch `wt/<item>`, run the project's slot setup.
- Release: desk merges after its own CHECK; the slot returns to detached at trunk. The project file sets the slot pattern, ceiling and setup.

## Replies
- Shortest reply that answers. No preamble, no restating the ask, no recap of what git or a file already records.
- Status as a list, one line per item. Explain only when asked.
- Design talk: a recommendation plus the trade-off in 1–3 lines, not a survey.

## Code (lean)
1. YAGNI: only what today's need requires; no flags/hooks/abstractions for a maybe-future.
2. Delete first: ask what can be removed before writing.
3. One way to do each thing: one config source, one data path, one client per service.
4. Replace, don't patch: maintenance is legacy burn. Write the replacement as a new module, cut over, delete the old one in the same pass. No compat shims.
5. No dead code: unused code, config and tests for deleted behaviour go in the same commit. Git is the archive.
6. Deep modules, small surface: no thin wrappers or pass-through layers.
7. Boring tools: stdlib and existing deps before anything new.
8. Measure: each pass should leave less code when possible; report LOC delta (`git diff --shortstat`), justify a net increase in one line.
9. Test behaviour at the public edge, not internals.
10. Strangler swaps: new beside old, move callers, delete old.
