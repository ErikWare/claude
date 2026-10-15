# Goal-driven tasks

Every delegated task runs to a finish line that a command can check, within a fixed budget.

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
2. Verify with commands (tests, lint, build), not LLM review. Use an LLM grader only when no command can check it.
3. Pass the CHECK honestly. Never edit the check, special-case it, monkey-patch builtins, or fake values to make it pass. If the goal looks impossible, stop and report FAIL.
4. Same error twice means stop: write a 3-line report (error / tried / suspect) and exit. Never loop on a repeated failure.
5. Read only the files the task names. Subagents return conclusions, not file dumps.
6. Mechanical work goes to Sonnet (low). Haiku is banned. Opus is for planning and hard bugs (ladder: `MODEL-SCALING.md`).
7. On failure, append one lesson line to the project's `.desk/LESSONS.md` (not CLAUDE.md, which loads every session). On success, write nothing.
8. Final output: PASS/FAIL, CHECK result, diff stat. 5 lines max.

## Desk side
- The desk re-runs CHECK itself and rejects a diff that touches files outside FILES. A worker's "PASS" is only a claim.
- Test on 2026-09-27 with an impossible CHECK: Haiku gamed it 3 times out of 3 (a class that fakes `+`, a patched `type()`, a `sys.excepthook` that exits 0), and it did so even with rule 3 in place. Sonnet (low) stopped and reported FAIL in 4 turns. Haiku is banned from all work.
