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

## 2. Doctor, then scaffold only the mechanical pieces

Run `~/.claude/kit/scripts/doctor.sh` and put its lines in the report as they
are. It never creates anything; it tells you what is missing.

Then scaffold what is mechanical, and nothing else:

1. `.claude/desk.conf`: copy the kit's `templates/desk.conf` and fill in only
   the values you **detected**. TRUNK is `origin/HEAD` if set, else `main`,
   else `master`. SLOT_PATTERN stays empty (the default is
   `<parent>/<repo>-wt-[1-9]`, siblings of the main checkout). An existing
   file is compared and reported, never overwritten.
2. **TEST_CMD: never invent it.** Take it only from the project's own
   manifest: `package.json` `scripts.test`, a `Makefile` `test:` target,
   `pyproject.toml` with pytest configured, `Cargo.toml` (`cargo test`),
   `go.mod` (`go test ./...`). Nothing there means TEST_CMD stays empty and
   the report says `BLOCKED ... needs: the command that proves this project
   works`. TYPECHECK_CMD and BUILD_CMD follow the same rule, and empty is
   fine for them.
3. A registry stub if REGISTRY names a file that doesn't exist: a `# Backlog`
   heading, in the default convention (`- **APP-12** title`, one bullet per
   item; see the kit's `docs/briefs-and-backlog.md`). An existing registry in
   another format gets its DEF_RE set in desk.conf, not rewritten.
4. `docs/briefs/.gitkeep`, and a desk log stub at `docs/desk-log.md` holding
   the section headings from the `desk` skill and nothing more.
5. The slot folders, 3 unless the user said otherwise: `git worktree add
   --detach <path> <trunk>`, never on the trunk branch, since git allows a
   branch in one worktree at a time and the desk holds it.
6. The project's `CLAUDE.md` gets at most a three-line pointer, and nothing
   more. The values live in the config, not in prose:
   ```
   ## Desk
   Trunk, slot pattern, commands and registry: `.claude/desk.conf`.
   Per-claim setup: `<npm ci | uv sync | none>`.
   ```
7. **Re-run** `doctor.sh --run` (the baseline: TEST_CMD on the trunk, under
   a timeout). Every remaining MISSING line goes in the report. A red
   baseline is `BLOCKED`: a desk can't gate branches against a trunk that's
   already red.
8. Commit only the files you created or changed, staged by explicit path, in
   one commit: `chore: adopt the desk workflow`. Don't push. PUSH_AFTER_LAND
   stays 0 until the user says otherwise: pushing is an outward action.

**A bare repository is not ready until `doctor.sh` exits 0.** Say so plainly.
Scaffolding makes the folders; it cannot supply the one thing that makes the
desk an oracle, which is a test command that proves the project works.

## 3. Become the desk

Only once `doctor.sh` exits 0: invoke the `desk` skill, once. Then run its
loop: census, pick, brief, land. Pick the models for subagents by
`docs/model-tiering.md`. Run no more than two subagents at a time, and put "do
not spawn sub-agents" in each prompt.

First report, one screen at most:

```
DONE setup <trunk>@<sha>  room: <room> (<reason>)
doctor: exit <0|1>   slots: <n> warm   registry: <path> (<n> items)   baseline: <green|red|not run> <TEST_CMD>
needs: <anything only the human can do, e.g. the command that proves this project works; or omit the line>
unverified: <what you did not check, e.g. setup command never run in a slot>
```

A doctor that did not exit 0 makes the first word `BLOCKED`, not `DONE`.
Then keep working, or stop and say that nothing is ready.
