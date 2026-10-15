---
name: backlog
description: Version and backlog management for the desk. Use when Erik says "check the version", "status", "status of the backlog", "list the backlog", "increment the version", "bump to vX", "open vX", "close vX", "is X obsolete", or "have Fable build a vX backlog".
---

# Backlog and version

One skill for "what version are we on", "where does the work stand" and "move to the next version". The project's `CLAUDE.md` names its files; this skill sets the method. If the project file has no `Version:` line, ask Erik once, then write that line.

## Where things live (project `CLAUDE.md` declares them)
- **Version sources**: every place a version number lives (package.json, Xcode `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`, `VERSION`, tags).
- **Intake**: where new finds land (`BACKLOG.md` or `backlog/<date>.md`).
- **Release file**: one per version, `v<X.Y>.md`, the only work list while that version is open: header, Lanes, Decisions, then items in the GOAL-DRIVEN brief with `WHY:` and `STATUS:`.

## Status values
`open` · `doing` · `code-done <date> (soak until <t>)` · `blocked <date> (<what Erik must give>)` · `done <date> (<commit>: <proof>)` · `obsolete <date> (<superseding ID or commit>: <why>)` · `moved <date> -> v<X.Y> <ID>`.
Only `done` and `obsolete` close an item. Never delete an item; change its STATUS.

## "check the version"
Read every version source and git (`git describe --tags --always`, release branches). Reply in ≤6 lines:
```
shipped: <store/prod version (build)>   source: <file>
trunk:   <version in code> @ <short hash>
open release file: v<X.Y> (<n open> / <n total>)   or: none
drift: <any sources that disagree, or "none">
```

## "status" / "status of the backlog"
From the open release file (or the intake if none is open), one line per item in lane or tier order:
`- **ID** — short what (≤15 words) · <status>` plus `[ERIK]` when it waits on him.
Open items first, then `blocked`, then a one-line count of done/obsolete/moved ("+ 23 done, 4 obsolete"). List the done ones only when asked ("status with done"). Never paraphrase a status into "basically done": verify `done` against the commit if in doubt.

## "increment the version" / "open vX.Y"
1. Close the old file: every item keeps its status; nothing is rewritten.
2. Carry: each item not `done`/`obsolete` goes to the new release file, and the old line gets `moved <date> -> vX.Y <new ID or same ID>`.
3. **Obsolescence pass** (Fable · low, outcome brief): for each carried item, check the code and the new version's scope. Mark `obsolete` when new work supersedes it, the code site is gone, or the premise no longer holds. Cite the superseding ID or commit. When unsure, keep it open; never mark obsolete without a citation.
4. Fold in the intake since the last version (dedupe: same gap → keep the existing ID).
5. Write Lanes and Decisions, then red-team the file (specifics kept, CHECKs runnable) before any worker starts.
6. Bump the version sources only when Erik says ship. Opening a release file is planning; it doesn't change the version.
Report: `vX.Y opened: <carried> carried, <obsolete> obsolete, <new> new, <lanes> lanes` plus the file path.

## Rules
- IDs are permanent: never reuse or renumber. An item lives in exactly one open release file.
- Code anchors (`TODO(ID)`) leave in the commit that closes the item.
- The desk verifies `done` with the item's CHECK before stamping it; a worker's claim is not proof.
