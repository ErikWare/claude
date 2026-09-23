# Briefs and the backlog

## The brief

A brief is the only thing that bounds a contributor running in auto mode, so
it's written to be checked, not interpreted. It lives at `docs/briefs/<ID>.md`,
is committed on the trunk, and is dispatched **by path**. Relays drop long
messages, and a path can't be half-delivered. The desk deletes the file when
the branch lands.

```markdown
# APP-12: retry with backoff in the sync client

- **ID:** APP-12
- **Goal:** failed batch pushes retry with capped exponential backoff.   ← one goal, never a list
- **Owned files:** src/sync/client.ts, src/sync/client.test.ts           ← exact repo-relative paths
- **Branch:** wt/app-12-retry                                            ← exact; on a resume, the existing one
- **Done-check:** `npm test` green, and `grep -c withRetry src/sync/client.ts` ≥ 1
- **max:** 90 min
- **Boot:** `claim.sh claim "$PWD" APP-12 90 retry with backoff`

**Provenance of every claim below.** Desk read of `client.ts` @ 3c1a9e0 on
2026-09-21. Verify before acting.
- `pushBatch()` makes one fetch and throws on non-2xx. (desk read the code)
- The server returns 429 under load. (product owner's recollection: unverified, treat it as a question)

**Expected of you.** Check this brief's premises and refuse them if they're
wrong. A correction is a successful outcome, not a deviation. The owned files
bound *which* files change, never *how*.

**Report** in the semaphore format (`docs/semaphore.md` in the kit).
```

The five fields are required, and a contributor missing any of them asks
before editing. Everything else is optional, but two extras earned their place.

- **Provenance on every claim.** Write "Source S says X, verify it", or
  "unverified: X". "X is true" costs an afternoon when it isn't. The failure
  on record: a research step asserted something, the product owner passed it
  on, and the desk repeated it *in the desk's own voice*. At that point it
  stopped being a claim and became an instruction. A contributor overturned it
  anyway, one layer later than it should have been caught. Recollection is
  never evidence, whoever it belongs to.
- **The expectation to measure.** At least four briefs in one day were wrong
  on their premise, and every one was caught by a contributor running
  something instead of complying. Say that you expect it, so a good
  contributor doesn't have to feel it's being insubordinate.

**Done-checks must be able to fail.** "Tests pass" on a branch that adds no
test can't fail. Prefer a check that names the change (a grep, a specific
test, a string in the built artifact via `gates.sh fresh`) as well as the
suite.

**A send-back is a brief too.** It uses the same five fields, plus **why it
was refused**, stated as evidence (the command and its output), and any
premise the refusal corrected.

## The backlog

One file, `BACKLOG.md`, owned by the product owner. Everyone else appends to
it: a contributor files findings, and the desk files refusals. Nobody
rewrites it.

**IDs.** An area prefix, a hyphen, and a number: `APP-12`, `TOOL-3`, matching
`[A-Z]{2,}-[0-9]+`. Register prefixes at the top of the file. The item that
introduces a prefix registers it.

- **Never reuse or renumber an ID that has landed.** A burned number stays
  burned: commit history, code anchors and reports all refer to it.
- **New items take the next free number in their prefix**, but "free" means
  free across *every ref*, not just this tree. Run
  `gates.sh ids-refs BACKLOG.md <trunk>` before assigning one.
- **On a collision at merge, the first to land keeps the number.** The later
  one is renumbered, which is a mechanical fix the desk may make (see
  resolve-vs-refuse in `desk.md`).
- **An item is defined by a line of the form** `- **APP-12** title`. That's
  the shape `gates.sh ids` looks for. Override `DEF_RE` if yours differs.

**Code anchors.** `// TODO(APP-12): short what`. A test that fails when an
anchor names an ID the backlog doesn't have is cheap, and it catches the case
where a backlog edit takes a neighbouring item with it.

**Tiers**, top to bottom:

| Section | Holds |
|---|---|
| **Next** | ready, agreed scope, in priority order. The desk picks from here only. |
| **Blocks release** | gaps that stop the next release |
| **Should have** | wanted for the next release, not blocking it |
| **Post-release** | enhancements. "Not in this release" is *not* the same as "blocks the next one". Keep the two apart, or deferral quietly becomes a blocker. |
| **Findings (dated)** | filed by contributors and the desk, untriaged until the product owner tiers them |
| **Waiting on a decision** | never launched until the human decides |
| **Done** | moved here with the landing commit's SHA. Never deleted: that keeps `gates.sh ids` able to detect loss. |

When the product owner sets a tier because the source didn't, mark it
`(tier: owner's call)` so it can be told apart from a tier the human chose.
