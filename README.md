# kit

An automated, non-blocking Claude Code workflow. One item, one worktree, one
`claude -p` run that exits when it is done. Nothing holds a directory, nothing
waits for a human.

## Where the ways of working come from

This repo holds no methodology of its own. Anthropic's documentation is the
source of truth, and it changes — read it rather than this file.

- **Doc index, fetch this first:** <https://code.claude.com/docs/llms.txt>
- Run Claude programmatically: <https://code.claude.com/docs/en/headless>
- CLI flags: <https://code.claude.com/docs/en/cli-reference>
- Permission modes: <https://code.claude.com/docs/en/permission-modes>
- Subagents: <https://code.claude.com/docs/en/sub-agents>
- Hooks: <https://code.claude.com/docs/en/hooks>
- Agent SDK: <https://code.claude.com/docs/en/agent-sdk/overview>
- When to use multi-agent, and when not to:
  <https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them>
- Harnesses for long-running agents:
  <https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents>

If anything here disagrees with those pages, those pages win.

## New machine

```
git clone git@github.com:ErikWare/claude.git ~/code/claude-public
~/code/claude-public/install.sh   # links home/*.md into ~/.claude
```

Then open the project and say "pick up": the project's `CLAUDE.md` and backlog carry the rest.

## The workflow

One agent owns an item end to end, including its tests. Split work by context,
not by role: no planner, no reviewer, no desk.

```
./run-item.sh <ID> "<what to do>"
```

That is the whole interface. It creates a worktree, runs one non-interactive
agent in it, and merges to the trunk if the project's test command passes.

## Why it does not block

`run-item.sh` runs `claude -p --bare --permission-mode auto
--permission-prompts none`, all documented above:

- `-p` runs non-interactively; the process exits when the run finishes.
- `--permission-prompts none` denies anything that would prompt, tells Claude
  nobody can approve it and not to retry, and removes the tools that need a
  person, instead of waiting for an answer nobody will give.
- `--bare` skips auto-discovery so a run behaves the same on every machine.
  It also never reads your subscription login, so `ANTHROPIC_API_KEY` must be
  set — the script refuses without it.

Every run is capped by `ITEM_TIMEOUT` and `TEST_TIMEOUT` (1800s each).

Our own reason for this shape, not Anthropic's: an interactive session ties up
its directory for as long as it is open, and that is what stalled the previous
kit. This starts none.

## Configuration

`.claude/kit.conf`, read by `run-item.sh`:

```sh
TRUNK=main
TEST_CMD="npm test"
PROTECTED="test\.sh|Makefile"   # optional; .claude/ is always protected
```

A branch that changes the gate — `.claude/` or anything in `PROTECTED` — is
refused, because a landing that disables its own tests cannot be caught by
running those tests.

## Backlog

`backlog/` in each project, one file per day named by date. Single source of
truth; nothing else holds a work list. `CLAUDE.md` has the rules.

The reason it is one place: across 30 days one project accumulated 21 separate
work lists, 14 of which disagreed with each other, and finished work sat marked
`todo` while asks that were never started looked filed. A list nobody reconciles
is worse than no list.

## Keeping `~/.claude` lean

`~/.claude` accrues per-session scratch that nothing prunes. `./clean-claude.sh`
prints what it would remove; `--apply` removes it.

```
./clean-claude.sh           # dry run
./clean-claude.sh --apply
```

It touches only regenerable state: `.DS_Store`, stray `settings.json.bak*`,
`cache/changelog.md`, all but the newest `.claude.json` backup, and age-gated
entries under `session-env/`, `shell-snapshots/` and `file-history/`. Tune with
`ENV_AGE`, `HISTORY_AGE`, `KEEP_BACKUPS`.

It never touches config, credentials, transcripts, or anything you authored —
`settings.json`, `.credentials.json`, `CLAUDE.md`, `projects/`, `sessions/`,
`plugins/`, `skills/`, `uploads/`. Those are yours; delete them by hand or not
at all. The same split is in `.gitignore`: machine state lives in `~/.claude`
and never here.

## Reading the result

`run-item.sh` writes `items/<ID>.md` — the plan, then the outcome — and exits
non-zero if the item did not land. State lives in git, so a run that dies
loses nothing.
