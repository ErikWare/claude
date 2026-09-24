# The semaphore protocol: how agents write to each other

A finished subagent usually restates its brief, narrates each step, lists the
files it changed, and only then says it's done. The receiver needed one line
of that. Everything else lands in the receiver's context, and it gets
re-processed on **every later turn** of that session, not just once. A desk
that takes forty reports in a day carries all of that correspondence to the
end.

The protocol keeps what the receiver can act on and verify, and drops the
rest. Then it names the three things that must never be compressed away.

## The format

```
STATUS ID branch sha [pushed|local]
field: value
```

The first line is fixed and machine-readable. It fits on a phone notification.
Then come only the fields that apply, one line each, in this order:
`premise`, `finding`, `left`, `needs`, `why`, `unverified`, `ctx`.

### Status codes

| Status | Means | Required fields |
|---|---|---|
| `DONE` | The goal is met, the done-check passes, and the branch holds the work | `unverified` |
| `PARTIAL` | Some of the goal is committed and some isn't. It is still worth landing. | `left`, `unverified` |
| `BLOCKED` | Can't proceed without something from someone else. The work so far is committed and the slot is parked. | `needs`, `unverified` |
| `REFUSED` | Won't do it as briefed, because the goal is wrong, unsafe or out of scope. This is a judgment, not an obstacle. | `why`, `unverified` |

**Why these four, and not "corrected" as a fifth.** A brief whose premise was
wrong, fixed by the contributor measuring instead of complying, is a
*successful* outcome. That makes it `DONE` with a `premise:` line. It is not a
separate state. Giving it its own status would make correction look like
deviation, and correcting the brief is the behaviour we most want to see.
`BLOCKED` and `REFUSED` stay apart because they route differently. A block
goes to whoever can supply the missing thing. A refusal goes back to whoever
wrote the brief, because the brief itself is what's wrong.

### The payload, and why it's enough

`ID`, `branch` and `sha` are what the receiver needs to **verify without
trusting**: `git cat-file -t <sha>` shows the commit exists,
`git merge-base --is-ancestor <sha> <branch>` shows the branch holds it, and
`git ls-remote origin <branch>` shows it was pushed. A report the receiver can
check mechanically doesn't need prose to be believed. A prose report still
has to be checked mechanically, because prose is exactly how a branch reports
"0 deleted" after deleting seven files.

## When prose is warranted: three fields, never compressed away

The protocol isn't "be terse". It removes *narration* so that the three kinds
of prose that carry information stand out. Each has its own field, so the
receiver can grep for them and never has to find them inside a story.

**`premise:` a claim in the brief was false.** Say what the brief said, what
you measured, and the command that showed it. In one day of real work, briefs
were wrong on their premise at least four times: a reference implementation
whose own README ruled out the approach, a named line that was already
correct, a test file slated for deletion whose cases mostly passed, and a
remembered number that was off by a factor of seven. Every time, the
contributor caught it by measuring rather than complying. This is the single
most valuable thing a contributor does, so it gets a field. It never gets
summarised as "made some adjustments".

**`finding:` something the brief didn't anticipate.** Give it a severity, so
the product owner can file it without asking.

**`unverified:` what you didn't check. This field is required.** A report
that names its gaps is the only kind that can be trusted. A report with no
gaps is either exhaustive or unexamined, and from the outside you can't tell
which. The reports that held up were the ones that volunteered things like
"analysis of generated output, nobody has inspected it by hand", "not run on a
device", or "the plugin wiring isn't under test". Each became a filed item
instead of a surprise a week later. `unverified: none` is allowed only with
the check that makes it true: `unverified: none — full suite on the rebased
tree, plus a manual run of the migration`.

## Forbidden

| Don't | Because |
|---|---|
| Restate the brief | The receiver wrote it, or holds it by path |
| Narrate steps ("First I read…, then I…") | Process isn't the result. The commit is the record. |
| List changed files or line counts | `git show --stat <sha>` gives them when needed |
| Paste logs or test output | Give the command. The receiver can run it if it cares. |
| Victory laps ("robust", "all working as expected", "let me know!") | They carry no information, and they cost trust: confidence words are what a report with gaps uses to hide them |
| Report a subagent's claim as your own check | "The subagent said green" is provenance. Put it in `unverified:` unless you ran it. |

## Worked examples

Sizes are measured with `wc` on the text shown. Token counts are
**estimates** (characters ÷ 4, the usual heuristic for English prose), not
tokenizer output. The "before" texts are **illustrative**: reconstructed from
the pattern, not quoted from a transcript.

### 1. A clean success

**Before** (239 words, 1,426 chars, **~356 tokens est.**):

> I've completed APP-12. To recap the brief: the goal was to add retry with
> exponential backoff to the sync client, the owned files were … Here's what I
> did: 1. First, I read through src/sync/client.ts to understand … 7. I ran
> done.sh, which pushed the branch and detached the worktree. Files changed:
> … Everything is working as expected and the implementation is robust. The
> branch is ready for the desk to land. Let me know if you'd like any changes!

**After** (16 words, 112 chars, **~28 tokens est.**):

```
DONE APP-12 wt/app-12-retry 4e1f0a2 pushed
unverified: retry under real network loss; tests use a stubbed fetch
```

That's about 92% smaller. **And the after is more useful than the before.**
The before never said what wasn't tested. It said "robust".

### 2. A wrong premise and an unexpected finding

This is the case where compression would be dangerous, and the protocol keeps
every fact that matters.

**Before** (232 words, 1,270 chars, **~317 tokens est.**): the report walks
through the brief, then mentions that deleting the files would have discarded
94 working tests. It reaches the fragile clock helper in paragraph four, and
closes by offering to delete the files anyway.

**After** (59 words, 383 chars, **~95 tokens est.**):

```
DONE APP-19 wt/app-19-legacy-tests 9b3c7d1 pushed
premise: brief said delete 5 files; 94/110 cases pass and test live code (11 import sites, `grep -rn legacy/ src`). Removed the 16 failing cases only.
finding: 2 kept files pass only because a removed clock helper is shadowed by a global. Severity: medium, fragile not broken.
unverified: whether the shadowing global is intentional
```

That's about 70% smaller. The saving is lower because the load-bearing prose
stayed. That's the design working: **the protocol compresses narration, not
information.**

### What it adds up to (estimate)

Take a receiver that holds reports for the rest of its session. Say a desk
gets 30 reports in a day, each ~300 tokens shorter, each arriving with about
40 more turns to go. It stops carrying about **30 × 300 × 40 ≈ 360k tokens**
of re-processed input. Most of that would be cache reads, which cost less than
fresh input but are not free. All of those numbers are illustrative.
Substitute your own counts, and measure them with your client's usage
reporting, not by eye.

## For the receiver

1. Read the first line. Check the SHA mechanically (see above) before acting
   on `DONE`.
2. `grep -E '^(premise|finding|needs|why):'`. Those lines are the only ones
   that ask you to think.
3. Treat `unverified:` as the list of things the desk's gate or a follow-up
   item must cover. It is not a formality.

## The same format, upward

The desk reports to the product owner in the same format, and the product
owner reports to the human the same way. A batch of landings is one line each:

```
DONE APP-12 main@7c1d9e0 landed
REFUSED APP-14 wt/app-14-cache 2b8e441 local
why: out of scope — touched src/db/schema.ts (not in owned files); sent back
unverified: APP-14's own tests not run; refused before the suite
```

## Outbound: the dispatch prompt, and messages to people

Everything above governs what comes *back*. The same arithmetic governs what
goes *out*, and it is worse there, because the sender writes the same waste
repeatedly while the receiver pays for it for the rest of its session.

One real day of dispatch, as reported by the product owner who did it (their
count, not a measurement of the transcript):

| What happened | Cost |
|---|---|
| 400–600 words of standing context — room, roles, project history — pasted into each of 4 dispatch prompts | ~700 tokens est. each, ~2.9k total, none of it new to the receiver |
| A running session polled ~10 times during a 320s suite, each poll returning the same stale preamble | 10 calls where 1 wait would have done |
| Multi-paragraph updates to a human reading them on a phone | The first line was the message; the rest was scrolled past |

None of it was forbidden. That was the gap, and the boot file now closes it in
three lines. The reasoning is the part worth keeping:

**Standing context is a file, not a paragraph.** Anything true for longer than
one message — the room, the role, how this project works — belongs at a path,
and the prompt cites the path. Pasting it is not "making sure": the receiver's
boot file already loaded the rules, and a second copy that has drifted from the
first is worse than no copy, because now the receiver has to decide which one
governs. A dispatch prompt is the brief's path, the role, and any delta that
isn't in the repo yet. Three lines is a normal length.

**A running session is not a status API.** Polling costs a call and returns
the preamble you already hold. Worse, a short wait teaches you nothing a long
wait wouldn't: a 320s suite is not 32s of information ten times. Wait for the
report, which arrives as one line you can verify.

**A person reading on a phone is the strictest receiver you have.** They can't
grep, they can't scroll back to a brief, and they are the one receiver whose
attention you can't measure. Lead with the outcome or the ask. The `premise:`
and `finding:` fields still apply — those are the lines a human most needs —
but "just to confirm my understanding of what you asked" is not a line.

### Worked: a dispatch prompt

**Before** (illustrative, reconstructed from the pattern; the ellipses stand in
for a 400–600 word original, so the measured text here understates it — 66
words, 344 chars, **~86 tokens est.**):

> Hi! Quick context before the task: you're a contributor working in a slot,
> which means you own one briefed item on one branch. Remember the desk holds
> the trunk and you never merge or push to it… The project is the proposal
> pipeline, which has a backend, a dashboard and an iOS capture app… For this
> item we want you to look at the retry logic…

**After** (17 words, 116 chars, **~29 tokens est.**):

```
Contributor. Brief: docs/briefs/APP-12.md
delta: the suite now takes 320s — budget for it, don't shorten the timeout
```

About 66% smaller on the shown text, and far more than that on the real one:
600 words of preamble is ~870 tokens est. against 29. The after is also the
more reliable of the two, because the brief at that path is the version the
desk wrote, and it can't drift in transit.
