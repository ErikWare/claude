# Goal-driven tasks

## Brief template
```
TASK: <what>
DONE WHEN: <checkable: tests pass / build ok / script exits 0>
CHECK: <exact command>
BUDGET: 3 fix attempts, then stop and report
FILES: <the only files to read>
MODEL: <id> · <effort>
```

## Rules
1. No task starts without DONE WHEN and CHECK.
2. Verify with commands (tests, lint, build); an LLM grader only when no command can.
3. Pass the CHECK honestly: never edit or special-case it, monkey-patch builtins or fake values. Impossible goal: stop, report FAIL.
4. Same error twice: stop, write a 3-line report (error / tried / suspect), exit.
5. Read only the task's files. Subagents return conclusions, not file dumps.
6. Model per `MODEL-SCALING.md`; Haiku is banned.
7. On failure, append one lesson line to the project's `.desk/LESSONS.md` (not CLAUDE.md); on success write nothing.
8. Final output: PASS/FAIL, CHECK result, diff stat; 5 lines max.
9. The desk re-runs CHECK before stamping `done` (a worker's PASS is a claim) and rejects a diff outside FILES.

## Version goals
A release file opens with 3–6 observable outcomes ("when vX.Y.Z ships, the app does …"), each with **Validate:** (its items' CHECKs plus one end-to-end proof), runnable at close (no "after 24 h"). The user signs them off before workers start. Every item names its goal, or is deferred. Human-only proof (device run) is stakeholder evidence, never blocks the tag.

## Item status
`open` · `doing` · `blocked <date> (<what the user must give>)` · `done <date> (<commit>: <proof>)` · `obsolete <date> (<superseding ID or commit>: <why>)` · `moved <date> -> v<X.Y> <ID>`. Only `done`/`obsolete` close; no soak status (time proof is a watch). Never delete an item. IDs are permanent, never reused or renumbered. `TODO(ID)` anchors leave in the closing commit.
