#!/bin/sh
# done.sh <branch>
#
# The contributor reporting done. Run in the slot. It makes sure the work is
# reachable from <branch> — not merely from this folder's HEAD — then pushes the
# branch and detaches, which frees the branch name so the desk can land it.
#
# Why it refuses so much: the most expensive failure on record is the ORPHANED
# BRANCH. Work gets committed on a detached HEAD, the branch pointer stays at
# its base, and from everywhere else the branch reads "0 commits ahead" —
# indistinguishable from a branch nobody touched. It happened four times in one
# day. This script will not report done unless the branch contains HEAD.
#
#   DONE_PUSH=0   skip the push (for a project with no remote). The push is the
#                 cheapest orphan insurance there is: a pushed commit can be
#                 recovered by name from any machine.
#
# Exit status:
#   0  branch contains the work, pushed (or push disabled / no remote), detached
#   1  usage / not a worktree / detach failed
#   2  dirty: commit or park first
#   4  ORPHAN: HEAD holds commits the branch does not, and they have diverged
#   5  push failed: the work is local only — do not report done yet

set -u

usage() {
	echo "usage: done.sh <branch>" >&2
	exit 1
}

[ $# -eq 1 ] || usage
BRANCH=$1

if [ -z "$(git rev-parse --show-toplevel 2>/dev/null)" ]; then
	echo "FAIL: cwd is not a git worktree"
	exit 1
fi

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
	echo "STOP: commit or park these first"
	git status --porcelain | head -20
	exit 2
fi

if ! git rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null; then
	echo "FAIL: no such branch: $BRANCH"
	exit 1
fi

on=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)
head_sha=$(git rev-parse HEAD)
br_sha=$(git rev-parse "refs/heads/$BRANCH")

if [ -n "$on" ] && [ "$on" != "$BRANCH" ]; then
	echo "FAIL: on branch $on, not $BRANCH"
	exit 1
fi

if [ -z "$on" ] && [ "$head_sha" != "$br_sha" ]; then
	if git merge-base --is-ancestor "$head_sha" "$br_sha"; then
		: # HEAD is behind the branch: nothing here the branch lacks.
	elif git merge-base --is-ancestor "$br_sha" "$head_sha"; then
		# Detached work ahead of the branch: the orphan shape. Fast-forward only.
		git branch -f "$BRANCH" "$head_sha" >/dev/null || {
			echo "FAIL: could not move $BRANCH to $head_sha"
			exit 1
		}
		echo "RESCUED: $BRANCH was behind the detached work; fast-forwarded to $(git rev-parse --short "$head_sha")"
		br_sha=$head_sha
	else
		echo "ORPHAN: HEAD $(git rev-parse --short "$head_sha") and $BRANCH $(git rev-parse --short "$br_sha") have diverged."
		echo "        Nothing was moved. Decide which holds the work, then e.g.:"
		echo "        git switch $BRANCH && git cherry-pick <sha>..."
		exit 4
	fi
fi

if [ "${DONE_PUSH:-1}" != 0 ] && git remote get-url origin >/dev/null 2>&1; then
	if ! git push --quiet -u origin "refs/heads/$BRANCH:refs/heads/$BRANCH" 2>/dev/null; then
		# A rewritten branch (after a send-back rebase) needs a lease, never a bare force.
		if ! git push --quiet --force-with-lease -u origin "refs/heads/$BRANCH:refs/heads/$BRANCH"; then
			echo "PUSH FAILED: $BRANCH exists only on this machine — do not report done yet"
			exit 5
		fi
	fi
	echo "pushed: origin/$BRANCH @ $(git rev-parse --short "$br_sha")"
fi

if [ -n "$on" ]; then
	git switch --quiet --detach || {
		echo "FAIL: could not detach — do not report done yet"
		exit 1
	}
fi

echo "DONE: $BRANCH @ $(git rev-parse --short "$br_sha") is free for the desk"
exit 0
