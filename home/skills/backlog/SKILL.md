---
name: backlog
description: Desk version, backlog, release, goal, red-team and watch phrases ("check the version", "status", "pick up", "open/close vX", "work on vX", "goal check").
---

# Backlog
The project `CLAUDE.md` `Version:` line names the files (missing: ask the user once, write it); project rules override. Goals, status: `GOAL-DRIVEN.md`.

## Files
- **Version sources**: files and tags holding it. **Intake**: `BACKLOG.md` or `backlog/<date>.md`. **Watch list**: `backlog/WATCH.md`.
- **Release file** `v<X.Y.Z>.md`, the only work list while open: header (sources, rules path), **Goals**, **Lanes** `lane | items (order) | files (owner) | model`, numbered final **Decisions**, then one `##` item per task: GOAL-DRIVEN brief plus `WHY:`, `STATUS:`. One release file per item.
- **Stakeholder** `STAKEHOLDER.md`: entries carry a desk **default**; release items go `moved <date> -> STAKEHOLDER`, never blocked.

## Watches
Time proof is a watch, not an item; shipped code with a green CHECK is `done`:
`- **W-<id>** — what is watched · CHECK: <cmd> · due <date time> · from <item>@<commit> · STATUS: watching | pass <date> | fail <date> -> <new story ID>`
Propose it (what it proves, why only time can, when due); add on the user's yes. Reminder at due time, or "pick up"/"status" runs due rows. Never holds a release; failure opens an intake story.

## Phrases
- **"pick up" / "where are we"**: read project `CLAUDE.md` and release file, run due watches, `grep -H "STATUS: open\|STATUS: doing\|STATUS: blocked"` over the backlog; report, keep going.
- **"status" / "list the backlog"**: release file (else intake), lane order: `- **ID** — short what (≤15 words) · <status>`, `[USER]` if user-blocked; open, blocked, then "+ 23 done, 4 obsolete"; no prose; done listed on ask; verify doubtful `done` by commit. "status" ends `watches: <n> watching, <n> due, <n> failed`.
- **"check the version"**: sources plus `git describe --tags --always`, release branches; ≤6 lines:
```
shipped: <store/prod version (build)>   source: <file>
trunk:   <version in code> @ <short hash>
open release file: v<X.Y> (<n open> / <n total>)   or: none
drift: <sources that disagree, or "none">
```
- **"build a vX backlog" / "open vX.Y"** (Fable, outcome brief): close the old file unchanged; carry open items (old line `moved <date> -> vX.Y <ID>`); obsolete pass (Fable · low: superseded, code site gone, premise false; cite; unsure → open); fold in intake, gap analysis, merge duplicates (other `moved`); red-team (specifics kept, CHECKs runnable and failing on trunk, lane order sound) before workers start. Bump versions only when the user says ship. Report `vX.Y opened: <carried> carried, <obsolete> obsolete, <new> new, <lanes> lanes` + path.
- **"work on vX" / "kick it off"**: one background worker per lane, one message, own worktrees; prompt: worker rules, Lanes row, Decisions, items.
- **"also build vX+1"**: new finds to today's intake, not the open file; Fable consolidates vX+1 in parallel.
- **"simplify review"**: post-release: less code, fewer rows/ports/tabs; findings to the next release.
- **"red team it"**: independent agents attack plan or build, writing `.desk/reports/<release>/redteam-<topic>-<date>.md`; desk applies or rejects each in a line.
- **"goal check"** (any time, trunk, not STATUS): run each Validate (PASS / FAIL / PENDING if gated or human; evidence); `done` commits on trunk (`git branch --contains`); goal-less items = drift; open items of a passing goal: obsolete or goal under-specified, say which. Overwrite `.desk/reports/vX.Y/goals.md` (dated): `goal | PASS/FAIL/PENDING | evidence | open items`, `drift:`, `gaps:`. Reply `G<n> PASS|FAIL|PENDING — why (≤12 words)` + path.
- **"close vX.Y.Z"**: items `done` or cited `obsolete`/`moved`; goal check. A FAIL: add a gap item, never move the goal. All PASS: tag `vX.Y.Z` on trunk, report `vX.Y.Z done: <n>/<n> goals PASS` + path.
