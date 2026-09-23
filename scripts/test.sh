#!/bin/sh
# test.sh — exercise every script against a throwaway repository with a bare
# remote and two slots. No network, nothing outside a temp dir.
#
# Each case asserts an exit code AND, where it matters, a string in the output:
# a gate proven only by "it exited 0" is the stale-build failure again.
# Exit status: 0 all passed, 1 at least one failed.

set -u

K=$(cd "$(dirname "$0")" && pwd -P)
T=$(mktemp -d "${TMPDIR:-/tmp}/kit-test.XXXXXX")
T=$(cd "$T" && pwd -P)
trap 'rm -rf "$T"' EXIT
pass=0 fail=0

# expect <code> <needle|-> <cmd...>
expect() {
	want=$1 needle=$2
	shift 2
	out=$("$@" 2>&1)
	got=$?
	if [ "$got" = "$want" ] && { [ "$needle" = - ] || printf '%s' "$out" | grep -qF -- "$needle"; }; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		echo "FAIL [$CASE]: want exit $want${needle:+ with \"$needle\"}, got $got: $*"
		printf '%s\n' "$out" | sed 's/^/    | /' | head -8
	fi
}

g() { git -c user.email=t@example.invalid -c user.name=test "$@"; }
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

git init -q --bare "$T/origin.git"
git init -q -b main "$T/app"
cd "$T/app" || exit 1
git remote add origin "$T/origin.git"
printf '# Backlog\n\n- **APP-1** first item\n- **APP-2** second item\n' >BACKLOG.md
printf 'echo ok\n' >run-tests.sh
g add BACKLOG.md run-tests.sh && g commit -qm init && git push -q origin main
git worktree add -q --detach "$T/app-wt-1" main
git worktree add -q --detach "$T/app-wt-2" main
S1=$T/app-wt-1 S2=$T/app-wt-2 PAT="$T/app-wt-[1-9]"

CASE=claim
expect 1 - "$K/claim.sh" show "$S1"
expect 0 CLAIMED "$K/claim.sh" claim "$S1" APP-3 60 add a thing
expect 0 APP-3 "$K/claim.sh" show "$S1"
expect 3 FOREIGN "$K/claim.sh" claim "$S1" APP-9 60 other
expect 3 FOREIGN "$K/claim.sh" release "$S1" APP-9
expect 0 APP-3 "$K/claim.sh" list "$T/app"

CASE=selfcheck
cd "$S2" || exit 1
expect 0 "warm and unbriefed" "$K/selfcheck.sh" "$PAT" main
expect 1 "no claim" "$K/selfcheck.sh" "$PAT" main APP-4
cd "$T/app" || exit 1
expect 1 "main checkout" "$K/selfcheck.sh" "$PAT" main
cd "$S1" || exit 1
expect 3 "FOREIGN" "$K/selfcheck.sh" "$PAT" main APP-7
git switch -q -c wt/app-3 main
expect 1 "briefed for wt/other" "$K/selfcheck.sh" "$PAT" main APP-3 wt/other
touch stray
expect 2 DIRTY "$K/selfcheck.sh" "$PAT" main APP-3 wt/app-3
rm stray
expect 0 "safe to work" "$K/selfcheck.sh" "$PAT" main APP-3 wt/app-3
expect 0 - test -s "$(git rev-parse --git-dir)/slot-boot-sha"

CASE=done
echo a >a.txt && g add a.txt && g commit -qm "APP-3: a"
touch dirt
expect 2 STOP "$K/done.sh" wt/app-3
rm dirt
expect 1 "no such branch" "$K/done.sh" wt/nope
expect 0 "pushed" "$K/done.sh" wt/app-3
expect 0 - test -z "$(git symbolic-ref -q HEAD)"
expect 0 - git -C "$T/origin.git" rev-parse --verify -q refs/heads/wt/app-3

CASE=orphan
# The day's most expensive failure: commit on a detached HEAD, branch left behind.
echo b >b.txt && g add b.txt && g commit -qm "APP-3: b (detached!)"
expect 1 ORPHAN "$K/gates.sh" orphans main
expect 0 RESCUED "$K/done.sh" wt/app-3
expect 0 - test "$(git rev-parse wt/app-3)" = "$(git rev-parse HEAD)"
expect 0 - "$K/gates.sh" orphans main
# Diverged: never guess which side holds the work.
git switch -q --detach wt/app-3~1
echo c >c.txt && g add c.txt && g commit -qm "diverged"
expect 4 ORPHAN "$K/done.sh" wt/app-3
git switch -q --detach wt/app-3

CASE=land
cd "$T/app" || exit 1
expect 2 "out of scope" "$K/land.sh" main wt/app-3 "sh run-tests.sh" a.txt
expect 0 - test "$(git symbolic-ref --short HEAD)" = main
expect 2 "red on the merged tree" "$K/land.sh" main wt/app-3 "false" a.txt b.txt
expect 1 "no owned-files" "$K/land.sh" main wt/app-3 "true"
(cd "$S1" && git switch -q wt/app-3)
expect 2 "still checked out" "$K/land.sh" main wt/app-3 "true" a.txt b.txt
(cd "$S1" && git switch -q --detach)
expect 0 LANDED "$K/land.sh" main wt/app-3 "sh run-tests.sh" a.txt b.txt
expect 0 - test -z "$(git status --porcelain)"
expect 2 "0 commits ahead" "$K/land.sh" main wt/app-3 "true" a.txt

CASE=release
cd "$S1" || exit 1
expect 1 "not the slot" "$K/release.sh" main "$S2" APP-3 wt/app-3
expect 0 "branch deleted" "$K/release.sh" main "$S1" APP-3 wt/app-3
expect 1 - "$K/claim.sh" show "$S1"
# A parked branch that was pushed must survive release (branch -d would delete it).
"$K/claim.sh" claim "$S1" APP-5 60 park me >/dev/null
git switch -q -c wt/app-5 main
echo p >p.txt && g add p.txt && g commit -qm "APP-5: wip"
"$K/done.sh" wt/app-5 >/dev/null
expect 0 "parked" "$K/release.sh" main "$S1" APP-5 wt/app-5
expect 0 - git rev-parse --verify -q refs/heads/wt/app-5

CASE=ids
cd "$T/app" || exit 1
expect 0 - "$K/gates.sh" ids BACKLOG.md
printf -- '- **APP-2** a different item\n' >>BACKLOG.md
expect 1 "ID-DUPLICATE" "$K/gates.sh" ids BACKLOG.md
printf '# Backlog\n\n- **APP-2** second item\n' >BACKLOG.md
expect 1 "APP-1" "$K/gates.sh" ids BACKLOG.md
git checkout -q BACKLOG.md
expect 2 BROKEN "$K/gates.sh" ids nope.md
expect 2 "no such base" "$K/gates.sh" ids BACKLOG.md nope
# At landing HEAD is the rebased tip, so loss must be measured against the trunk.
git switch -q -c wt/drop main && printf '# Backlog\n\n- **APP-2** second item\n' >BACKLOG.md && g commit -qam "drop APP-1"
expect 0 - "$K/gates.sh" ids BACKLOG.md
expect 1 "ID-LOSS: on main" "$K/gates.sh" ids BACKLOG.md main
git switch -q main
expect 2 "red on the merged tree" "$K/land.sh" main wt/drop "$K/gates.sh ids BACKLOG.md main" BACKLOG.md
git branch -q -D wt/drop

CASE=ids-refs
# Two unlanded branches file DIFFERENT items under one new ID. Each tree is
# clean on its own; only a walk across refs sees it.
for s in x y; do
	git switch -q -c "wt/$s" main
	printf -- '- **APP-6** item from %s\n' "$s" >>BACKLOG.md
	g commit -qam "file APP-6 ($s)"
	git switch -q main
done
git switch -q wt/x && expect 0 - "$K/gates.sh" ids BACKLOG.md && git switch -q main
expect 1 "ID-COLLISION APP-6" "$K/gates.sh" ids-refs BACKLOG.md main
git branch -q -D wt/y
git push -q origin wt/x
expect 0 - "$K/gates.sh" ids-refs BACKLOG.md main # a branch and its pushed copy agree
# Editing an OLD item on the trunk is not a collision, however stale a branch is.
sed -i.bak "s/first item/first item, reworded/" BACKLOG.md && rm BACKLOG.md.bak && g commit -qam "reword APP-1"
expect 0 - "$K/gates.sh" ids-refs BACKLOG.md main
printf -- '- **APP-6** filed on trunk meanwhile\n' >>BACKLOG.md && g commit -qam "trunk APP-6"
expect 1 "vs main" "$K/gates.sh" ids-refs BACKLOG.md main

CASE=wip
expect 0 - "$K/gates.sh" wip main 3
expect 1 "WIP 2/1" "$K/gates.sh" wip main 1
expect 0 "WIP 2/3" "$K/census.sh" . main 3
expect 0 "OVER CEILING" "$K/census.sh" . main 1

CASE=fresh
echo "build 1" >app.bundle
expect 1 "does not contain" "$K/gates.sh" fresh app.bundle "build 2"
expect 0 - "$K/gates.sh" fresh app.bundle "build 1" BACKLOG.md
touch -t 200001010000 app.bundle
expect 1 "before the last commit" "$K/gates.sh" fresh app.bundle "build 1" BACKLOG.md
rm app.bundle

CASE=unrun
mkdir -p t && touch t/a.test t/b.test
expect 1 "t/b.test" "$K/gates.sh" unrun "ls t/*.test" "echo t/a.test"
expect 0 - "$K/gates.sh" unrun "ls t/*.test" "ls t/*.test"
expect 2 BROKEN "$K/gates.sh" unrun "true" "true"
rm -rf t

CASE=secrets
g add -A >/dev/null && g commit -qm tidy >/dev/null 2>&1
printf 'path: /Us%s/someone/x\n' ers >leak.md && g add leak.md
expect 1 "leak.md" "$K/check-secrets.sh" --staged
printf 'acme corp\n' >.secrets-denylist
printf 'we work for ACME Corp\n' >leak.md && g add leak.md
expect 1 "DENYLIST" "$K/check-secrets.sh" --staged

CASE=install
I=$T/home && mkdir -p "$I"
expect 0 "CREATED" env HOME="$I" CLAUDE_CONFIG_DIR= "$K/../install.sh"
expect 0 - test -f "$I/.claude/skills/start-desk/SKILL.md"
expect 0 "imports the kit" env HOME="$I" CLAUDE_CONFIG_DIR= "$K/../install.sh"
rm -rf "$I/.claude" && mkdir -p "$I/.claude" && echo mine >"$I/.claude/CLAUDE.md"
expect 1 "Left untouched" env HOME="$I" CLAUDE_CONFIG_DIR= "$K/../install.sh"
expect 0 - test "$(cat "$I/.claude/CLAUDE.md")" = mine

echo "test.sh: $pass passed, $fail failed"
[ $fail -eq 0 ]
