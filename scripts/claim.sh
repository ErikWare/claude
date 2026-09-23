#!/bin/sh
# claim.sh — the slot claims ledger.
#
#   claim.sh claim   <slot> <ID> <max-min> <goal...>
#   claim.sh show    <slot>
#   claim.sh release <slot> <ID>
#   claim.sh list    [<repo>]
#
# A claim says "this worktree folder is working on this item". It lives in a
# ledger next to the shared .git (`<git-common-dir>/slot-claims.tsv`), so every
# worktree of one repository sees the same ledger and no worktree's commits can
# carry it. Claims never use `git worktree lock`: `git worktree list` stays a
# census of folders, never of claims.
#
# Line format (tab-separated): slot  ID  claimed-epoch  max-min  goal
#
# Exit status:
#   0  ok
#   1  usage / not a git worktree / unclaimed (show) / ledger error
#   3  FOREIGN: the slot is claimed by a different ID. Never clear it.

set -u

usage() {
	sed -n '3,6p' "$0" | sed 's/^# //' >&2
	exit 1
}

[ $# -ge 1 ] || usage
CMD=$1
shift

# Canonical physical path, so /tmp and /private/tmp are one slot.
canon() { (cd "$1" 2>/dev/null && pwd -P); }

ledger_for() {
	c=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
	[ -n "$c" ] || return 1
	printf '%s/slot-claims.tsv\n' "$c"
}

# mkdir is atomic: a portable lock with no dependencies.
with_lock() {
	lock="$1.lock"
	n=0
	while ! mkdir "$lock" 2>/dev/null; do
		n=$((n + 1))
		if [ $n -gt 50 ]; then
			echo "FAIL: ledger lock held: $lock (remove it if no claim.sh is running)" >&2
			return 1
		fi
		sleep 0.1 2>/dev/null || sleep 1
	done
	return 0
}
unlock() { rmdir "$1.lock" 2>/dev/null; }

case "$CMD" in
claim)
	[ $# -ge 4 ] || usage
	SLOT=$(canon "$1") || { echo "FAIL: no such directory: $1" >&2; exit 1; }
	ID=$2 MAX=$3
	shift 3
	GOAL=$(printf '%s' "$*" | tr '\t\n' '  ')
	case "$MAX" in '' | *[!0-9]*) echo "FAIL: max-min must be an integer" >&2; exit 1 ;; esac
	L=$(ledger_for "$SLOT") || { echo "FAIL: $SLOT is not a git worktree" >&2; exit 1; }
	with_lock "$L" || exit 1
	touch "$L"
	have=$(awk -F '\t' -v s="$SLOT" '$1 == s { print $2 }' "$L")
	if [ -n "$have" ] && [ "$have" != "$ID" ]; then
		unlock "$L"
		echo "FOREIGN CLAIM: $SLOT is claimed by $have — park and report $have"
		exit 3
	fi
	awk -F '\t' -v s="$SLOT" '$1 != s' "$L" >"$L.tmp" &&
		printf '%s\t%s\t%s\t%s\t%s\n' "$SLOT" "$ID" "$(date +%s)" "$MAX" "$GOAL" >>"$L.tmp" &&
		mv "$L.tmp" "$L"
	rc=$?
	unlock "$L"
	[ $rc -eq 0 ] || { echo "FAIL: could not write ledger $L" >&2; exit 1; }
	echo "CLAIMED: $SLOT $ID max=${MAX}m"
	;;
show)
	[ $# -eq 1 ] || usage
	SLOT=$(canon "$1") || { echo "FAIL: no such directory: $1" >&2; exit 1; }
	L=$(ledger_for "$SLOT") || { echo "FAIL: $SLOT is not a git worktree" >&2; exit 1; }
	[ -f "$L" ] || exit 1
	line=$(awk -F '\t' -v s="$SLOT" '$1 == s { print $2 "\t" $3 "\t" $4 "\t" $5 }' "$L")
	[ -n "$line" ] || exit 1
	printf '%s\n' "$line"
	;;
release)
	[ $# -eq 2 ] || usage
	SLOT=$(canon "$1") || { echo "FAIL: no such directory: $1" >&2; exit 1; }
	ID=$2
	L=$(ledger_for "$SLOT") || { echo "FAIL: $SLOT is not a git worktree" >&2; exit 1; }
	[ -f "$L" ] || { echo "OK: no ledger, nothing to release"; exit 0; }
	with_lock "$L" || exit 1
	have=$(awk -F '\t' -v s="$SLOT" '$1 == s { print $2 }' "$L")
	if [ -n "$have" ] && [ "$have" != "$ID" ]; then
		unlock "$L"
		echo "FOREIGN CLAIM: $SLOT is claimed by $have, not $ID — not released"
		exit 3
	fi
	awk -F '\t' -v s="$SLOT" '$1 != s' "$L" >"$L.tmp" && mv "$L.tmp" "$L"
	rc=$?
	unlock "$L"
	[ $rc -eq 0 ] || { echo "FAIL: could not write ledger $L" >&2; exit 1; }
	echo "RELEASED: $SLOT ($ID)"
	;;
list)
	REPO=${1:-.}
	L=$(ledger_for "$REPO") || { echo "FAIL: $REPO is not a git repository" >&2; exit 1; }
	if [ ! -s "$L" ]; then
		echo "no claims"
		exit 0
	fi
	now=$(date +%s)
	awk -F '\t' -v now="$now" '{
		age = int((now - $3) / 60)
		flag = (age > $4) ? "  PAST MAX" : ""
		printf "  %s  %s  age=%dm max=%sm%s: %s\n", $1, $2, age, $4, flag, $5
	}' "$L"
	;;
*) usage ;;
esac
exit 0
