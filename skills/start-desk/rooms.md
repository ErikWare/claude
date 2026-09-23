# Two rooms: the same orchestration, a different human

`/start-desk` makes the calling session the **desk**, the tech lead holding the
trunk. Who is on the other end of the desk's messages decides almost everything
about *how* it works. The roles and gates don't change. Everything around them
does.

| | **Dispatch room** | **Terminal room** |
|---|---|---|
| Who the product owner is | Dispatch, relaying for a human on a phone | a code agent, or the human, at a keyboard |
| Human can see | the messages Dispatch shows them, on a small screen | terminal output, files, diffs |
| Human can do | reply in a sentence, later | run commands, close tabs, approve prompts, read code |
| A blocking question | **wedges the session permanently** | costs one interruption |
| Default for approvals | pre-granted before the human walks away, or work stalls silently | granted live |
| Cost of a wrong guess about the room | high: a stranded session | low: a terse report |

## Detecting the room

In order. Stop at the first that answers.

1. **An argument says so.** `/start-desk dispatch` or `/start-desk terminal`.
2. **The session says so.** The system prompt or the invoking message identifies
   the session as Dispatch, remote, mobile or unattended. So does a brief that
   arrived relayed rather than typed.
3. **Environment hints.** These are observed, not documented, so they are never
   proof. `CLAUDE_CODE_ENTRYPOINT` says which client started the process.
   `CLAUDE_CODE_SESSION_ATTENDED` has been seen set. Neither can tell you
   whether the human is looking at the screen now.
4. **Still unsure: assume Dispatch.** The asymmetry decides it. Treat a terminal
   user as if they were on a phone, and they get terse messages and no
   questions, which they can easily overrule. Treat a phone user as if they were
   at a terminal, and one question tool strands the whole session.

Put the decision and its reason on the first line of the first report
(`room: dispatch (no argument; unattended hint)`), so a wrong guess costs the
human one word to correct.

## Dispatch room: the human is on a phone

The point of this room is that real work continues on the machine while the
human is elsewhere. Every rule below protects that.

**Never block on a human.**
- No `AskUserQuestion` and no plan-mode approval gate (`ExitPlanMode` waits on a
  human too). Don't start anything that opens an interactive prompt either:
  `git rebase -i`, `npm init`, an editor, a `sudo` password, an OAuth browser
  hop.
- This applies to **every subagent** as well. A subagent that calls a question
  tool in this room never returns, and its work is stranded. Put this sentence
  in every subagent prompt: *"Do not ask questions. If blocked, state the
  question in your final report and stop."*
- If you're blocked, do everything that isn't blocked first. Then report
  `BLOCKED` or `PARTIAL` with the question in plain text. The session ends
  cleanly and holds nothing.

**Approvals must exist before the human leaves.** A permission prompt is a
blocking question with different styling. One session sitting on an approval
nobody was awake to answer cost an entire night. So when the room is Dispatch:
- Check the session's permission mode up front. If it isn't auto, and the work
  needs anything beyond the allowlist, report that as the first line. Don't
  discover it at 2 a.m.
- Only the human can grant auto mode or edit the allowlist. Tell them which, in
  one line, while they are still reachable.
- The same goes for the machine itself. It must not sleep, and it must not
  raise an OS dialog (keychain, privacy permission, a software update) that
  nobody will click. Those are the human's settings, not the agent's, so name
  them before the human leaves.

**Messages are glanceable, or they're not read.**
- The first line is the whole message: a semaphore status line under ~80
  characters (see `docs/semaphore.md`). That is what shows in a notification.
- No wide tables, no diffs, no logs, no code blocks longer than three lines.
  A phone can't render them usefully, and the human can't act on them there
  anyway.
- **File paths are useless on a phone.** If the human needs to read something,
  put it on a page they can open (a published artifact, a PR) and send the
  link. Otherwise, don't send it.
- Never ask "does this look right?" about code. The human can't see it. Ask
  product questions only ("behind a flag, or on for everyone?"), and number
  the options so the answer can be one character.
- Replies from a phone are short and ambiguous: "yes", "do it", "2". So a
  question must restate the specific action it approves ("Reply `push` to push
  `main` to origin"). Then a one-word answer can't approve the wrong thing.

**The human cannot close sessions, so sessions close themselves.** An idle
session holds its worktree, and held worktrees were the binding constraint on
throughput, more than context or budget. In this room nobody is going to close
the tab. A contributor runs `release.sh` and ends. The desk ends when the queue
is empty or everything is waiting on the human. It says which in its last line.

**Batch what only the human can do** into one "needs you at the machine" list:
a hardware device, a credential, a sign-in, a physical install. Send it once,
early, not scattered across the night.

**Long silences are normal, so deadlines are mechanical.** Nobody notices a
wedged session for hours. Give every brief a `max` minutes. Treat silence past
~20 minutes as wedged, not busy. Run every build and test under a timeout.

## Terminal room: the human is at the keyboard

Most of the Dispatch constraints relax. Here are the ones that don't, and the
new failure modes that come with them.

**What gets cheaper.**
- Questions. You can ask in plain text and expect an answer. **Still batch
  them:** each one interrupts a human, and the desk should be able to run a
  whole loop between questions. The interactive question tool is safe in the
  top-level session, **never in subagents**. A subagent's question doesn't
  reach the human cleanly in either room.
- Human hands. The human can run a command you give them, close a finished
  tab, grant a permission live, plug in a device. **Ask them to close finished
  sessions.** It's the cheapest throughput gain available.
- Visibility. The human can read the diff, so the desk doesn't need to
  describe it.

**What doesn't get cheaper.**
- **Tokens.** Output being visible is not a licence to narrate. The semaphore
  format applies unchanged, because the cost it removes is paid by the model
  whether or not a human is watching.
- **The oracle rule.** A watching human is not a gate. If they say "looks fine,
  merge it", the desk still rebases onto the current tip and runs the full
  suite on the merged tree. The human's glance is the student's done-check with
  a different student.

**New failure modes in this room.**
- **The human becomes a second, undeclared relay.** They copy a brief into a
  new tab by hand, trimming it as they go, and the contributor gets a different
  brief from the one the desk wrote. The rule is the same as for Dispatch:
  briefs live in the repo and are passed **by path**. Give the human
  `claude "Read docs/briefs/APP-12.md and follow it"` to paste, not the brief
  text.
- **The product owner is a code agent, and code agents like to code.** A
  product-owner session that "just fixes the typo" has left its role. So has a
  desk that "just resolves the conflict" when the resolution decides semantics.
  Having the human watching makes this more tempting, not less. Hold the line:
  work becomes an item and a brief.
- **The human edits the trunk directly.** That's their right. The census
  catches it: the trunk moved without a landing. Rebase everything in flight
  onto it, and say so, rather than treating it as drift to correct.
- **Approvals granted live are not approvals for later.** When the human walks
  away, the room has become Dispatch, and the rules change with it. If the
  human says they're leaving, re-run the Dispatch checks: permission mode, sleep,
  and the "needs you" list.

## What is identical in both rooms

- The roles, the brief's five fields, `land.sh`, the gates, linear history.
- The semaphore report format, including its three prose fields.
- Chat is not storage. Anything that must outlive the conversation goes in the
  repo and is referred to by path.
- One to three items in flight. The limit is review bandwidth, the desk's and
  the human's, and neither room changes it.
