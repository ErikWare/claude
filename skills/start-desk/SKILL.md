---
name: start-desk
description: Configure the multi-session ways of working (desk, product owner, contributors in git worktrees) for the current project and make this session the desk. Use when the user runs /start-desk on a new machine or a new project. Detects whether the caller is Dispatch on a phone or a human at a terminal first, because that changes how every later message and approval works.
argument-hint: "[dispatch|terminal]"
disable-model-invocation: true
allowed-tools: Read Grep Glob Edit Write Bash(git *) Bash(~/.claude/kit/*) Bash(ls *) Bash(test *)
---

# /start-desk

You are about to become **the desk**: the tech lead for this repository. You
hold the trunk, every merge and the technical judgment, and you write no code.
Setup comes first. It is the one time the desk commits anything other than its
log.

Report every step's outcome in the semaphore format (`docs/semaphore.md` in the
kit). No narration.

## 0. Detect the room: before anything else

Read [rooms.md](rooms.md) and decide **dispatch** or **terminal**. `$ARGUMENTS`
overrides. **If you are unsure, choose dispatch.** A terminal user given
Dispatch rules loses nothing but chattiness. A phone user given terminal rules
loses the session to the first blocking question.

In the dispatch room, from this line on: **no `AskUserQuestion`, no plan mode,
no interactive commands**, in this session or any subagent. Questions go in the
report as plain text, and you keep going with everything they don't block.

## 1. Preconditions: stop at the first failure

Each one that fails is a `BLOCKED` report naming the fix. Don't work around it.

1. The cwd is a git repository and is the **main checkout**: `git rev-parse
   --git-dir` equals `--git-common-dir`. A linked worktree is a slot, never a
   desk.
2. The tree is clean: `git status --porcelain` is empty.
3. The trunk exists. Use `origin/HEAD` if it is set, else `main`, else `master`.
4. The kit is installed: `~/.claude/kit/scripts/land.sh` is executable. If not,
   the kit is the directory two levels above this skill's base directory. Run
   its `install.sh`. Don't pass `--import` yet.
5. `~/.claude/CLAUDE.md` imports the kit (`grep -F '@~/.claude/kit/CLAUDE.md'`).
   If it doesn't, **don't edit it here**. It's the user's personal file, and it
   may already hold an older copy of these rules. In the terminal room, ask
   once. In the dispatch room, put `needs: reply "import" to add the kit's boot
   file to your personal CLAUDE.md` in the report and carry on. The rest of
   setup doesn't depend on it.

## 2. Wire the project

Detect. **Never invent.** A value you can't find is a question, not a default.

| value | how to find it |
|---|---|
| test command | the project's own: `package.json` `scripts.test`, `Makefile` `test:`, `pyproject`/`pytest`, `cargo test`, `go test ./...`. None? That's a question. A desk without a test command is no oracle. |
| per-claim setup | lockfile-driven: `npm ci`, `pnpm i --frozen-lockfile`, `uv sync`, … or `none` |
| backlog | an existing `BACKLOG.md` / `docs/**/BACKLOG.md`, else create `BACKLOG.md` (conventions in the kit's `docs/briefs-and-backlog.md`) |
| desk log | `docs/desk-log.md` |
| slot pattern | `<parent>/<repo>-wt-[1-9]`, siblings of the main checkout |
| slot folders | 3, unless the user said otherwise |
| gate command | `<test command> && ~/.claude/kit/scripts/gates.sh ids <backlog>`: what `land.sh` runs on the merged tree |
| push after landing | **off**. Pushing is an outward action. Turn it on only when the user says so, and record that in the table. |

Then:

1. Append [project-template.md](project-template.md), filled in, to the
   project's `CLAUDE.md`, or create the file. If a `## Desk` section already
   exists, compare it, report the differences, and leave it alone.
2. Create the slot folders that are missing. Use `git worktree add --detach
   <path> <trunk>`, never on the trunk branch, since git allows a branch in one
   worktree at a time and the desk holds it.
3. Create the backlog and desk log if they are missing, each as a heading and
   its sections, nothing more.
4. **Baseline.** Run the test command on the trunk, under a timeout. Red is a
   `BLOCKED` report: a desk can't gate branches against a trunk that's already
   red. Then run `gates.sh ids <backlog>`, and `census.sh . <trunk>`.
5. Commit only the files you created or changed, staged by explicit path, in
   one commit: `chore: adopt the desk workflow`. Don't push.

## 3. Become the desk

Read the kit's `docs/desk.md` once. Then run its loop: census, pick, brief,
land. Pick the models for subagents by `docs/model-tiering.md`. Run no more
than two subagents at a time, and put "do not spawn sub-agents" in each prompt.

First report, one screen at most:

```
DONE setup <trunk>@<sha>  room: <room> (<reason>)
slots: 3 warm   backlog: <path> (<n> items)   baseline: green <cmd>
needs: <anything only the human can do, or omit the line>
unverified: <what you did not check, e.g. setup command never run in a slot>
```

Then keep working, or stop and say that nothing is ready.
