#!/bin/sh
# release.sh <trunk> <slot> <ID> <branch>
#
# Warm release, once the desk says the item landed (or after a park): put the
# slot back detached at the trunk tip, delete the branch if it is merged, and
# give the claim back. Run it IN the slot, then end the session — an idle
# session that stays open holds its folder, and held folders were the binding
# constraint on throughput, more than context or budget.
#
# The detach gates the release. Releasing a claim while the slot still has the
# branch checked out deadlocks the desk: the next `git switch` anywhere else is
# refused with "already used by worktree".
#
# Exit status:
#   0  released; the slot is warm
#   1  usage / wrong cwd / detach failed / claim not released
#   2  dirty: commit or park first
#   3  the claim belongs to another ID

set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)

usage() {
	echo "usage: release.sh <trunk> <slot> <ID> <branch>" >&2
	exit 1
}

[ $# -eq 4 ] || usage

TRUNK=$1 SLOT=$2 ID=$3 BRANCH=$4

# Every git command below runs in the cwd, but the claim released is <slot>'s.
# If they differ we would detach someone else and free a slot that still holds
# the branch.
top=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$top" ]; then
	echo "FAIL: cwd is not a git worktree — claim kept"
	exit 1
fi
if [ "$(cd "$top" && pwd -P)" != "$(cd "$SLOT" 2>/dev/null && pwd -P)" ]; then
	echo "FAIL: cwd is $top, not the slot $SLOT — claim kept; run this in the slot"
	exit 1
fi

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
	echo "STOP: commit or park these first"
	git status --porcelain | head -20
	exit 2
fi

git switch --quiet --detach "$TRUNK" || {
	echo "FAIL: could not detach at $TRUNK — claim kept on purpose; tell the desk"
	exit 1
}
echo "detached at $TRUNK tip ($(git rev-parse --short HEAD))"

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
	# Not `branch -d`: once done.sh has pushed, -d measures "merged" against the
	# upstream, which always contains the branch — it would delete parked work.
	if ! git merge-base --is-ancestor "$BRANCH" HEAD 2>/dev/null; then
		echo "branch kept: not in $TRUNK (parked)"
	elif git branch -D "$BRANCH" >/dev/null 2>&1; then
		echo "branch deleted: $BRANCH (landed)"
	else
		echo "branch kept: landed but not deletable here (held by another worktree?)"
	fi
else
	echo "branch $BRANCH already gone"
fi

"$HERE/claim.sh" release "$SLOT" "$ID"
rc=$?
[ $rc -eq 0 ] || { echo "FAIL: claim not released"; exit $rc; }

echo "RELEASED: $SLOT is warm — now end this session"
exit 0
