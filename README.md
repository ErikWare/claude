# claude: a portable way of working for Claude Code

Clone this onto any machine, and one command gives Claude Code a working
multi-session setup. A **desk** (tech lead) holds the trunk and gates every
merge. A **product owner** holds the backlog. **Contributors** each work one
briefed item in their own git worktree. The whole thing is built to spend as
few tokens as possible without shipping wrong code.

## Quickstart

```sh
git clone git@github.com:ErikWare/claude.git ~/claude-kit
~/claude-kit/install.sh            # safe to re-run; changes nothing it didn't create
cd ~/your-project && claude        # open Claude Code in the project's main checkout
/start-desk                        # detect the room, wire the project, become the desk
```

That's it. `/start-desk` also works from inside the clone before you install
anything, because the repo carries its own `.claude/skills/` link.

Check the scripts on your machine with `scripts/test.sh`. It runs 67
assertions in a throwaway repo, with no network access.

## What you get

| Path | What it is |
|---|---|
| `CLAUDE.md` | The boot file every session loads. It covers role detection, the report format, and the rules each role follows. ~150 lines. |
| `skills/start-desk/` | `/start-desk`. Its first job is working out whether you're on a phone through Dispatch or at a terminal ([rooms.md](skills/start-desk/rooms.md)). |
| `scripts/` | The gates, as POSIX sh plus git. `land.sh` (the merge gate), `done.sh` / `release.sh` / `selfcheck.sh` / `claim.sh` (the contributor lifecycle), `census.sh`, and `gates.sh` (ID collisions, WIP, orphans, stale builds, unrun tests). |
| [`docs/semaphore.md`](docs/semaphore.md) | **The report protocol.** A status line, a SHA, and what wasn't verified, with no narration. The biggest single saving. |
| [`docs/failure-catalogue.md`](docs/failure-catalogue.md) | Eleven failures that cost real budget. Each has its forensic signature and the script that guards against it. |
| [`docs/model-tiering.md`](docs/model-tiering.md) | Which model does which job. Tier by the cost of an undetected error, and run at most two at a time. |
| [`docs/desk.md`](docs/desk.md) | The tech lead's loop, what `land.sh` guarantees, and resolve-vs-refuse. |
| [`docs/briefs-and-backlog.md`](docs/briefs-and-backlog.md) | The five-field brief, ID discipline, and the backlog tiers. |

## How it installs, and why that way

- **By symlink, not copy.** `~/.claude/kit` points at this clone, and each
  skill is linked as `~/.claude/skills/<name>`. The clone stays the single
  source of truth, so `git pull` updates your ways of working on every
  machine at once. A copied install goes out of date as soon as there are two
  machines. Symlinked skill folders are documented as supported, and Claude
  Code watches them for changes. [skills]
- **The boot file is an `@import`, not a symlink.** `~/.claude/CLAUDE.md` is a
  real file containing `@~/.claude/kit/CLAUDE.md`. The docs say a symlinked
  `~/.claude/CLAUDE.md` is skipped in some desktop sessions, and an import
  also sits alongside a personal file you already have. **If that file
  already exists, `install.sh` doesn't touch it** unless you pass `--import`.
  [memory]
- **This repo is not `~/.claude` itself.** That directory is written to by
  tooling you don't control: sessions, caches, plugins, `settings.json`.
  Publishing it would bet your secrets on a `.gitignore` keeping ahead of
  every future version of that tooling. This repo is the portable method,
  `~/.claude` is the machine's config, and `install.sh` links the two.
- **Why not a plugin?** The docs recommend plugins for sharing skills, and
  this kit may become one. But plugin skills are namespaced
  (`/plugin:start-desk`), installed as copies that update through the
  marketplace, and, as far as the plugin docs we read show, don't install a user-level `CLAUDE.md`. For one person's
  machines, a clone plus links is simpler and updates instantly. [plugins]

`install.sh --dry-run` shows every change first, and `install.sh --uninstall`
removes only what points into the kit. Requirements: git ≥ 2.23 and a POSIX
shell, on macOS or Linux.

## The three ideas that matter most

1. **Semaphore reports.** A subagent that's finished says
   `DONE APP-12 wt/app-12-retry 4e1f0a2 pushed` and names what it didn't
   verify. Prose is allowed in exactly three places: a wrong premise, an
   unanticipated finding, and the unverified list. On the examples in the
   doc, reports shrink by about 70–92% (estimated), and the shorter version
   carries *more* usable information.
2. **Machines, not rules.** The failures that cost the most were adjacent to
   the intent and invisible at the point of editing, so more care doesn't
   catch them. Every guard here is a script that exits non-zero, and each
   script is mutation-tested. Those tests report their survivors, not a catch
   rate.
3. **Two rooms.** The same orchestration behaves differently depending on
   whether the human is on a phone (where you never block, pre-grant
   approvals, and send glanceable messages) or at a terminal (where questions
   are cheap and the human can close tabs). When unsure, assume the phone.

## Conformance with the Claude Code docs

Followed: skill layout and frontmatter (`name`, `description`,
`argument-hint`, `disable-model-invocation`, `allowed-tools`), `SKILL.md`
under 500 lines with supporting files linked from it, `CLAUDE.md` under 200
lines, `@path` imports, subagent `model` values
(`haiku`/`sonnet`/`opus`/`fable`/`inherit`), and permission rules in
`settings.json`.

Where this kit's practice differs from the docs, and why:
- **Symlinks instead of a plugin**: see above.
- **Claims live in a ledger file, not in `git worktree lock`.** Keeping them
  out of git means `git worktree list` stays a census of folders.
- **The kit never edits `settings.json`.** Permission allowlists and auto mode
  are the human's decision. `/start-desk` names what's missing instead.

Sources: [skills] https://code.claude.com/docs/en/skills ·
[memory] https://code.claude.com/docs/en/memory ·
[sub-agents] https://code.claude.com/docs/en/sub-agents ·
[plugins] https://code.claude.com/docs/en/plugins ·
[settings] https://code.claude.com/docs/en/settings

## Keeping this repo clean

It's public. `install.sh` enables a pre-commit hook (`scripts/check-secrets.sh`)
that refuses home-directory paths, private keys and common token formats. Add
private words (client names, hostnames) to a gitignored `.secrets-denylist`,
one per line. Then they're blocked without ever being committed.
