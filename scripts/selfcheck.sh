#!/bin/sh
# selfcheck.sh <slot-pattern> <trunk> [expected-ID] [expected-branch]
#
# The contributor's boot check. Run in the slot, after claiming, before any edit.
#
#   <slot-pattern>     shell glob the worktree top must match, e.g. "$HOME/myapp-wt-[1-9]"
#   <trunk>            main | master
#   [expected-ID]      the backlog ID this session was briefed with
#   [expected-branch]  the branch the brief names
#
# On success it records the trunk SHA as of boot in `<git-dir>/slot-boot-sha`.
# Use that SHA — never a branch name — for any reset or rebase base: a branch
# can move under you, a SHA cannot. (`git reset --soft main` after the trunk
# advanced once silently reverted 18 lines another session had committed.)
#
# Exit status:
#   0  OK       safe to work (or warm and unbriefed, when no expected-ID given)
#   1  FAIL     not a slot / main checkout / wrong branch / briefed but unclaimed
#   2  DIRTY    uncommitted or untracked files: stop, do not edit
#   3  FOREIGN  claimed by another ID: park and report that ID, never clear it

set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)

usage() {
	echo "usage: selfcheck.sh <slot-pattern> <trunk> [expected-ID] [expected-branch]" >&2
	exit 1
}

[ $# -ge 2 ] || usage

PATTERN=$1
TRUNK=$2
WANT_ID=${3-}
WANT_BRANCH=${4-}

top=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$top" ]; then
	echo "FAIL: cwd is not a git worktree"
	exit 1
fi
top=$(cd "$top" && pwd -P)

gitdir=$(git rev-parse --path-format=absolute --git-dir 2>/dev/null)
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
if [ "$gitdir" = "$common" ]; then
	echo "FAIL: this is the main checkout, not a slot"
	exit 1
fi

# The pattern is a glob on purpose. Compare against both the logical and the
# physical path, so a symlinked home (/tmp vs /private/tmp) still matches.
match=0
for p in "$top" "$(git rev-parse --show-toplevel)"; do
	# shellcheck disable=SC2254
	case "$p" in $PATTERN) match=1 ;; esac
done
if [ $match -ne 1 ]; then
	echo "FAIL: $top does not match the slot pattern $PATTERN"
	exit 1
fi
echo "slot: $top"

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
	echo "DIRTY: uncommitted or untracked files — stop, do not edit"
	git status --porcelain | head -20
	exit 2
fi

branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)
head_sha=$(git rev-parse HEAD 2>/dev/null)
trunk_sha=$(git rev-parse --verify --quiet "$TRUNK^{commit}" 2>/dev/null)
if [ -z "$trunk_sha" ]; then
	echo "FAIL: no such trunk: $TRUNK"
	exit 1
fi
echo "head: ${branch:-detached} @ $(git rev-parse --short HEAD)"

claim=$("$HERE/claim.sh" show "$top" 2>&1)
crc=$?
case $crc in
0) ;;
1)
	# show exits 1 silently when unclaimed; any text means the ledger failed.
	if [ -n "$claim" ]; then
		echo "FAIL: claims ledger error — claim state unknown, do not edit"
		printf '%s\n' "$claim" | head -3
		exit 1
	fi
	claim=""
	;;
*)
	echo "FAIL: claims ledger error (exit $crc) — do not edit"
	exit 1
	;;
esac

if [ -z "$claim" ]; then
	if [ -n "$WANT_ID" ]; then
		echo "FAIL: briefed with $WANT_ID but the slot holds no claim — run claim.sh first"
		exit 1
	fi
	if [ -z "$branch" ]; then
		echo "OK: warm and unbriefed"
		exit 0
	fi
	echo "FAIL: unclaimed but on branch $branch (a warm slot is detached)"
	exit 1
fi

have_id=$(printf '%s\n' "$claim" | awk -F '\t' 'NR==1 { print $1 }')
if [ "$have_id" != "$WANT_ID" ]; then
	echo "FOREIGN CLAIM: slot is claimed by $have_id, not ${WANT_ID:-this unbriefed session} — park and report $have_id"
	exit 3
fi

if [ -n "$WANT_BRANCH" ] && [ "$branch" != "$WANT_BRANCH" ]; then
	echo "FAIL: briefed for $WANT_BRANCH but HEAD is ${branch:-detached}"
	echo "      new item:     git switch -c $WANT_BRANCH $TRUNK"
	echo "      resumed item: git switch $WANT_BRANCH     (never -C: it resets the branch)"
	exit 1
fi

printf '%s\n' "$trunk_sha" >"$gitdir/slot-boot-sha"
echo "boot trunk: $TRUNK @ $(git rev-parse --short "$trunk_sha") (saved to slot-boot-sha — reset to this SHA, never to a branch name)"
echo "OK: $have_id on ${branch:-detached}, safe to work"
exit 0
