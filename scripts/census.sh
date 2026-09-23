#!/bin/sh
# census.sh [repo] [trunk] [ceiling]
#
# The desk's view of reality: claims, worktrees, work in flight, orphans. Run
# it at boot and before every brief. Where the desk log and the census
# disagree, the census wins and the log gets corrected.
#
# Exit status: 0 printed (findings are in the output, not the exit code),
# 1 usage / not a git repository.

set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=${1:-.}
TRUNK=${2:-main}
CEILING=${3:-3}

cd "$REPO" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1 || {
	echo "usage: census.sh [repo] [trunk] [ceiling]   ($REPO is not a git repository)" >&2
	exit 1
}

echo "== claims"
"$HERE/claim.sh" list .

echo "== worktrees"
git worktree list | sed 's/^/  /'

echo "== in flight (ceiling $CEILING)"
n=0
for b in $(git for-each-ref --format='%(refname:short)' refs/heads/wt/); do
	git merge-base --is-ancestor "$b" "$TRUNK" && continue
	n=$((n + 1))
	ahead=$(git rev-list --count "$TRUNK..$b")
	up=$(git rev-parse --verify --quiet "refs/remotes/origin/$b" >/dev/null && echo pushed || echo LOCAL-ONLY)
	echo "  $b  +$ahead  $up"
done
if [ $n -gt "$CEILING" ]; then
	echo "  WIP $n/$CEILING — OVER CEILING: land or park before briefing anything new"
else
	echo "  WIP $n/$CEILING"
fi

echo "== orphans"
"$HERE/gates.sh" orphans "$TRUNK" && echo "  none"
exit 0
