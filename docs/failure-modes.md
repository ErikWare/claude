# Failure modes

Every entry below cost real time in real sessions. Setting up this way of
working cost about half of a week's model budget, and most of that went on
failures like these. Each entry has three parts: the failure, its **forensic
signature** (how you recognise it after the fact), and the **cheapest
mechanical guard**.

## The lesson under all of them

**These failures are adjacent to the intent and invisible at the point of
editing.** An edit meant to move one backlog item took 14 of its neighbours
with it, in a part of the file the author had no reason to be reading. Two
sessions each filed a different item under the same ID, in different regions
of a file, and the merge was clean. A test file sat on disk for the life of
the repository and never ran.

None of these would have been caught by being more careful. More care is more
attention on the hunk you meant to change, and the damage is in the hunk you
didn't look at. **These failures need machines, not rules.** A rule enforced
by discipline is more discipline applied to a problem discipline doesn't
solve. Each guard below is a script, and each exits non-zero.

---

### 1. Branch orphaning

**Failure.** Work is committed while the worktree is on a detached HEAD, so
the branch pointer stays at its base. From every other directory the branch
reads "0 commits ahead". That looks exactly like a branch nobody touched. The
next session redoes the work, or reports it missing, and it is reading a
wrong pointer correctly. There were four occurrences in one day: three of this
exact shape, and one where the item moved folders but its branch stayed
checked out in the old one.

**Signature.** `git reflog show <branch>` lists only `Created` and `Reset`
entries, with **no `commit:` entries**, even though commits were authored in
between. A branch that receives a commit gets one reflog line per commit, so
their absence proves HEAD was detached.

**Guard.**
- `done.sh <branch>` refuses to report done unless the branch contains HEAD.
  If the detached work is ahead of the branch, it fast-forwards the branch
  (`RESCUED`). If the two have diverged, it stops (`ORPHAN`, exit 4).
- It then **pushes**. A pushed commit can be recovered by name from any
  machine. That's the cheapest insurance there is.
- `gates.sh orphans` lists any worktree whose HEAD is on no branch.
  `census.sh` runs it at every desk boot.
- `land.sh` refuses a branch with 0 commits ahead of the trunk, rather than
  calling it landed.

**Recovery, cheapest first:** `git ls-remote origin` (a push may have saved
it), then `git cat-file -t <sha>`, then `git fsck --lost-found`. Nothing is
lost until garbage collection: `git branch -f <branch> <sha>` restores it
whole.

### 2. Resetting to a branch name that moves

**Failure.** `git reset --soft main`, run after `main` advanced mid-session,
re-based the working copy onto a tree it predated. The recommit **silently
deleted 18 lines another session had committed.** The deletions didn't show
up as anything unusual in `git status`. They were caught only because an
unexpected modified file appeared in a tree that should have been clean.

**Signature.** A commit's diff removes lines that no one in this session
wrote, and those lines match a commit that landed on the trunk after this
session booted.

**Guard.** `selfcheck.sh` records the trunk SHA at boot in
`<git-dir>/slot-boot-sha`. Reset and rebase onto **that SHA**, never onto a
branch name.

### 3. ID collisions in a shared registry

**Failure.** Two sessions file different items under one ID. Six collisions
happened in one day, in one backlog. A textual merge **can't see an ID
collision**. The two entries sit in different regions of the file, so there's
nothing to conflict, and every check stays green.

**Signature.** Two definitions of one ID. Or an ID in commit history whose
backlog entry describes something else.

**Guard.**
- `gates.sh ids` catches an ID defined twice in the configured REGISTRY, and
  an ID present on HEAD but deleted by this edit (IDs are never deleted: they
  move to Done). `land.sh` runs it on every landing **with the trunk as base**
  (`gates.sh ids $REGISTRY $TRUNK`). After the rebase HEAD *is* the branch, so
  a HEAD-based loss check compares the file to itself and can never fire.
  `test.sh` pins that trap.
- **The deeper point: both of those checks look at one tree.** A collision
  between two *unlanded* branches is invisible to both until the merge. Two of
  the six were caught only by someone enumerating IDs across every local and
  remote ref by hand. `gates.sh ids-refs` (registry and trunk from the config) is that
  enumeration as a script. It walks every local and remote ref, takes the IDs
  each one newly defines, and fails when two refs, or a ref and the trunk,
  file different items under one ID. Run it **before assigning a new ID**,
  not only at merge.

### 4. Silent coverage loss

**Failure.** The test script named every test file on one shared line. That
line had four merge collisions in one day, and a wrong resolution silently
drops coverage with every check green. Two refused branches were each
already missing two test files. When the list was replaced with a glob, a
test file surfaced that had been **on disk since the initial import and had
never run once**: seven passing tests nobody knew existed.

**Signature.** A test file that no runner's output ever mentions.

**Guard.** **Discover, don't enumerate.** Use a glob, never a list. Globs have
a shape too, and a file outside the shape runs nowhere. So
`gates.sh unrun "<list test files on disk>" "<list files the runner ran>"`
fails on any file that's on disk but was never run.

### 5. A gate with a standing known-benign output

**Failure.** The ID-duplicate gate had been recorded as having a "known benign
false positive". It wasn't benign: it was a real defect. But because it
printed on every run, everyone learned to scroll past it, and **that's how the
real collisions got in.**

**Signature.** Any check whose output people describe as "that's always
there".

**Guard.** A contract, applied to every script here: **silence and exit 0 on
a pass; evidence and exit 1 on a fail; exit 2 if the check itself is broken,
which never counts as a pass.** Fix the output or delete the gate. Also ask
what a green check proves. A negative control (plant the failure, watch the
gate fire) is the only proof a gate can fail at all. `scripts/test.sh` is
built out of those.

### 6. Blocking question tools deadlock unattended sessions

**Failure.** A session calls the interactive question tool when nobody is
there to answer, and it never returns. Two sessions were lost this way, one of
them for about two hours before anyone noticed.

**Signature.** A session that has gone silent, whose last action was a
question or approval prompt.

**Guard.** The boot file forbids it in unattended sessions and in every
subagent, and every subagent prompt repeats it. Blocked sessions write the
question into their report as plain text, then park. There's more in
`skills/start-desk/rooms.md`.

### 7. Idle sessions hold their worktree

**Failure.** A finished session that nobody closed still holds its folder and
its branch, so the folder can't take new work. **This was the binding
constraint on throughput, ahead of context and budget.** Ten item branches
were outstanding at the end of one day, against a stated limit of three, and
nobody noticed, because nothing counted them.

**Signature.** `census.sh` shows claims past their `max`, or WIP over the
ceiling.

**Guard.**
- `release.sh`, then the session ends itself. In the Dispatch room nobody else
  will close it.
- `gates.sh wip` (TRUNK and WIP_CEILING from `.claude/desk.conf`) refuses to let the desk brief a fourth
  item.
- `census.sh` prints `WIP n/ceiling` at every boot, so the number is
  measured, not remembered.

### 8. An inherited default nobody questioned

**Failure.** Sessions rotated at 250k tokens of context, and paid for a full
handoff each time: re-reading the queue, writing a baton, briefing the
successor. The 250k was a configurable auto-compaction setting inherited as a
default. It was **not the model's limit**, and the underlying window was
several times larger. Days of handoffs were paid for a number whose
provenance nobody had checked.

**Signature.** A number that shapes daily behaviour, where nobody can say who
chose it or why.

**Guard.** Not a script, but it is mechanical: **an inherited default that
shapes behaviour gets the same provenance question as a claim in a brief.**
The boot file restates the ceiling as a quality warning you answer for, not a
hard stop. Don't over-correct, though: a long context is re-processed on every
turn, and quality falls before the hard limit. Choose the number on evidence,
and write the evidence down.

### 9. The desk can't message its contributors

**Failure.** Unattended desk sessions are refused messaging, so the product
owner hand-relays every message both ways. Long briefs were dropped by the
relay **three times in a row**. A dropped brief looks exactly like a
contributor that hasn't started yet.

**Signature.** A slot that's claimed or warm, a brief the desk believes was
sent, and no report.

**Guard.** **Anything that must outlive a conversation goes in the repo and is
referred to by path.** Briefs live in `docs/briefs/<ID>.md`, and the relay
carries a path, not a paragraph. A path can't be half-delivered.

### 10. A stale build that reports success

**Failure.** A build artifact was three days old. Every build command
exited zero, and nothing anywhere said the artifact was stale.

**Signature.** The shipped artifact lacks a string that the latest source
change introduced.

**Guard.** **Assert on the artifact's content, never on the exit code.**
`gates.sh fresh <artifact> <marker> [source paths]` fails if the marker isn't
in the artifact, or if the artifact is older than the last commit to its
sources.

### 11. The desk's own edits aren't gated

**Failure.** A backlog edit made at the desk silently took 14 neighbouring
items with it and orphaned six live code references. The trunk was red for
most of an hour. The check that would have caught it existed, and took
0.1 s, but nothing ran it.

**Signature.** The trunk turns red with no landing in between.

**Guard.** The desk's own commits go through the same gate steps as
landings (`doctor.sh --run` runs TEST_CMD on the trunk). Ideally, CI runs the gates on every push. CI is the one fix that
**doesn't depend on anyone suspecting anything**, and that's the whole class
of failure this document is about.

---

## Two positive standards

### A test counts only if breaking the implementation fails it

Mutation testing is the definition of whether a test counts: change the
implementation, confirm the test fails, restore. **Report survivors, not catch
rates.** A campaign that catches everything mostly proves you mutated the
well-tested part.

On record: one campaign caught 17 of 17. Another caught 8 of 12, and its **4
survivors were the valuable result**. An index mapping could be reversed with
53 of 53 tests green. An entire rule category could be deleted with all 94 of
its tests passing. A loop bound could be halved unnoticed. An exported
fallback constant was unprotected.

This kit holds its own scripts to the same standard. Of 21 hand-written
mutants against `scripts/`, 19 were caught. The two survivors:
- `land.sh`'s broken-check branch (grep exit 2) can't be reached without
  fault injection, so it is untested.
- In `gates.sh ids-refs`, the landed-ref skip is an equivalent mutant: the
  merge-base filter already excludes what it skips, so it's only an
  optimisation.

Two earlier survivors became tests. Rewording an old item on the trunk no
longer counts as a collision, and census now reports over-ceiling.

### Resolve versus refuse

This is the desk's rule for merge conflicts, and it is in the `desk` skill. The desk
may resolve a conflict **when a mechanical proof predates the resolution**. It
must refuse **when the resolution decides semantics**. A check invented while
looking at the conflict is the desk grading its own paper.
