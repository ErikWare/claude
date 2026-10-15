# CLAUDE.md

Read by interactive sessions. Item agents never read it: `run-item.sh` passes
`--bare`, so guidance cannot drift into a run without someone changing the
script.

## How work happens

```
./run-item.sh <ID> "<what to do>"
```

One item, one worktree, one agent that owns the item including its tests, and
exits. It lands if the project's test command passes on the merged result.
Run several at once; they share nothing.

Do not open an interactive session to do an item. Our reason, not Anthropic's:
an interactive session ties up its directory for as long as it stays open, and
that is what stalled the previous kit.

## Backlog

One per project, at `backlog/`, one file per day named by date
(`backlog/2026-09-25.md`). New ideas, todos and state go in today's file. It is
the only work list: do not start a board, a phase folder, a gaps file or a
handoff document beside it.

Filing is not queueing — nothing reads `backlog/` and runs anything, so an item
recorded there still has to be handed to `run-item.sh` to happen. Say which you
did.

Verify state against the code before writing `done`. A status line is not
evidence, and neither is an empty branch: item agents commit on a detached HEAD,
so a `wt/*` ref still pointing at the trunk proves nothing.

## Ways of working

`home/` holds them: `CLAUDE.md` (the desk, its phrases, worker rules, lean
code), `GOAL-DRIVEN.md` (brief template), `MODEL-SCALING.md` (model ladder),
`ASSETS.md` (asset control). `install.sh` symlinks them into `~/.claude`, so a
fresh machine or cloud VM picks up the same way of working with one clone.
Edit them here, never in `~/.claude`.

They are the distilled takeaways from shipped projects, not a methodology for
its own sake. Before adding a rule, ask what it replaces; a rule that only adds
is how the last kit grew to 26 files and stopped working. Anthropic's docs
remain the reference for the tools themselves (README lists them).

## Context

Every token is re-read on every later turn. Anthropic's own multi-agent
write-up names the fix: an agent writes its output to the filesystem and
passes back a lightweight reference, "to minimize token overhead from copying
large outputs through conversation history"
(<https://www.anthropic.com/engineering/multi-agent-research-system>). See also
<https://code.claude.com/docs/en/how-claude-code-works#the-context-window>.

So: **pass paths, never bodies.** An item writes `items/<ID>.md` and reports
its first line plus that path. Whoever needs the detail reads the file. Do not
retype a report, a brief or a finding into a message — relaying it once costs
it again at every hop after.

Shortest response that answers the question. No preamble, no restating the
ask, no summary of what you just did where the file already says it, no
listing changed files — git has them. Give the command, not its output.

Report status as task lines, nothing else: `<ID> — done` / `not done` /
`blocked`. No explanation, no reasoning, no narrative. Reasons are given when
asked for and not before. A blocked line may name what it waits on, in a few
words. Findings go in the day file; the status line points at it.

Don't re-read what is already in context, don't read a file back after
editing it, and grep for the lines you need instead of reading whole files.

## Install

`chmod +x run-item.sh`, and copy `kit.conf.example` to `.claude/kit.conf` in
each project. There is nothing else to install.
