#!/bin/sh
# land.sh <trunk> <branch> <test-cmd> <owned-path>...
#
# The desk's merge gate. Run in the MAIN CHECKOUT.
#
#   <trunk>       main | master
#   <branch>      the wt/<topic> branch to land
#   <test-cmd>    one shell string, run with sh -c on the rebased tree
#   <owned-path>… exact repo-relative paths, as `git diff --name-only` prints
#                 them (the check is whole-line, so no globs, no trailing /)
#
# Invariant, held on EVERY exit path including success: the desk ends on
# <trunk> with a clean working tree. go_home() forces that. Forcing is safe
# HERE ONLY because the desk never holds work of its own — everything it can
# discard is a test/build artifact. A slot must never do this.
#
# Why rebase-then-test: after the rebase the branch tip IS the merged tree, so
# the test run is a test of the merge, and --ff-only guarantees that what lands
# is exactly what was tested. The contributor's own green run was on a tree it
# shaped, at a commit it chose; this one is not.
#
#   LAND_PUSH=1   push <trunk> to origin after landing. Off by default: pushing
#                 is the project's call. Turn it on in the project's CLAUDE.md.
#
# Exit status:
#   0  landed (fast-forward)
#   1  usage / no owned-files list / broken check
#   2  STOP: send it back (still checked out, empty, rebase conflict, red,
#      out of scope)
#   3  merge --ff-only refused (the trunk moved under the rebase), or the push
#      after a successful landing failed

set -u

usage() {
	echo "usage: land.sh <trunk> <branch> <test-cmd> <owned-path>..." >&2
	exit 1
}

[ $# -ge 3 ] || usage

TRUNK=$1
BRANCH=$2
TESTCMD=$3
shift 3

TMP=$(mktemp -d "${TMPDIR:-/tmp}/land.XXXXXX") || {
	echo "FAIL: no temp dir"
	exit 1
}
OWNED="$TMP/owned"
DIFF="$TMP/diff"
: >"$OWNED"

cleanup() { rm -rf "$TMP"; }

# Return to the trunk with a clean tree, whatever state the tree is in.
# -f discards modified tracked files; `clean -fd` removes untracked artifacts a
# test run dropped. No -x: ignored files (node_modules, DerivedData) are kept.
go_home() {
	git switch -f "$TRUNK" >/dev/null 2>&1
	if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
		# clean is cwd-relative: root it, or artifacts dropped outside the
		# cwd survive and the desk is left dirty.
		git clean -fdq -- "$(git rev-parse --show-toplevel)" >/dev/null 2>&1
	fi
	if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
		echo "WARNING: desk tree is still not clean:"
		git status --porcelain | head -20
		return 1
	fi
	here=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)
	if [ "$here" != "$TRUNK" ]; then
		echo "WARNING: desk is on '${here:-detached}', not $TRUNK"
		return 1
	fi
	return 0
}

for p in "$@"; do
	printf '%s\n' "$p" >>"$OWNED"
done

if [ ! -s "$OWNED" ]; then
	echo "STOP: no owned-files list — nothing can be checked"
	cleanup
	exit 1
fi

gitdir=$(git rev-parse --path-format=absolute --git-dir 2>/dev/null)
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
if [ -z "$gitdir" ]; then
	echo "FAIL: cwd is not a git repository"
	cleanup
	exit 1
fi
if [ "$gitdir" != "$common" ]; then
	echo "FAIL: land.sh runs in the main checkout, not a slot"
	cleanup
	exit 1
fi

# --- take the branch -------------------------------------------------------
# Check it exists first: otherwise a typo falls into the "desk's own mess"
# retry below, which force-cleans the desk for nothing.
if ! git rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null 2>&1; then
	echo "FAIL: no such branch: $BRANCH"
	cleanup
	exit 1
fi
# A branch with nothing ahead of the trunk is either already landed or an
# orphan (work committed on a detached HEAD, pointer left at base). Both are
# "nothing to land", and the second must never be reported as "landed".
if [ "$(git rev-list --count "$TRUNK..refs/heads/$BRANCH" 2>/dev/null)" = 0 ]; then
	echo "STOP: $BRANCH has 0 commits ahead of $TRUNK — already landed, or ORPHANED"
	echo "      (check: git reflog show $BRANCH | grep -c 'commit' — 0 entries means"
	echo "       the work was committed on a detached HEAD; ask the slot for its HEAD SHA)"
	cleanup
	exit 2
fi

err=$(git switch "$BRANCH" 2>&1)
if [ $? -ne 0 ]; then
	case "$err" in
	*"already used by worktree"* | *"already checked out"*)
		echo "STOP: still checked out in a slot — tell the worker to run done.sh"
		printf '%s\n' "$err" | head -5
		go_home
		cleanup
		exit 2
		;;
	*)
		# The desk's own mess: local files in the way. Clean and retry.
		echo "desk tree was in the way; cleaning and retrying"
		printf '%s\n' "$err" | head -5
		go_home
		err=$(git switch "$BRANCH" 2>&1)
		if [ $? -ne 0 ]; then
			echo "FAIL: cannot check out $BRANCH even after cleaning the desk"
			printf '%s\n' "$err" | head -5
			go_home
			cleanup
			exit 1
		fi
		;;
	esac
fi

# --- rebase onto the trunk -------------------------------------------------
git rebase "$TRUNK"
if [ $? -ne 0 ]; then
	git rebase --abort >/dev/null 2>&1
	echo "STOP: rebase conflict — send it back"
	go_home
	cleanup
	exit 2
fi

# --- the brief's done-check, on the merged tree ----------------------------
sh -c "$TESTCMD"
if [ $? -ne 0 ]; then
	echo "STOP: red on the merged tree — send it back"
	go_home
	cleanup
	exit 2
fi

# --- scope: every changed path must be in the brief ------------------------
# An unchecked diff that fails leaves $DIFF empty, which grep reads as
# "no violations" and lands unscoped work. Check it.
if ! git diff --name-only "$TRUNK...HEAD" >"$DIFF" 2>/dev/null; then
	echo "FAIL: cannot diff $TRUNK...HEAD — refusing to land"
	go_home
	cleanup
	exit 1
fi
grep -vxF -f "$OWNED" "$DIFF"
rc=$?
if [ $rc -eq 0 ]; then
	echo "STOP: out of scope — the paths above are not in the brief"
	go_home
	cleanup
	exit 2
fi
if [ $rc -ne 1 ]; then
	echo "FAIL: scope check broke (grep rc=$rc) — refusing to land"
	go_home
	cleanup
	exit 1
fi

# --- land ------------------------------------------------------------------
if ! go_home; then
	echo "FAIL: could not return to $TRUNK cleanly — nothing landed"
	cleanup
	exit 1
fi

git merge --ff-only "$BRANCH"
if [ $? -ne 0 ]; then
	# Unguarded, this reports success while nothing landed.
	echo "STOP: --ff-only refused — $TRUNK moved under the rebase; re-run land.sh"
	go_home
	cleanup
	exit 3
fi

go_home
echo "LANDED: $BRANCH -> $TRUNK ($(git rev-parse --short HEAD))"
cleanup
if [ "${LAND_PUSH:-0}" = 1 ]; then
	if ! git push --quiet origin "$TRUNK"; then
		echo "PUSH FAILED: landed locally, $TRUNK not on origin"
		exit 3
	fi
	echo "pushed: origin/$TRUNK"
fi
exit 0
