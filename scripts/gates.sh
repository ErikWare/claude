#!/bin/sh
# gates.sh <gate> [args] — mechanical guards. Each prints nothing and exits 0
# when it passes, and prints the evidence and exits 1 when it fails. That
# contract is the point: a gate with a standing "known benign" output is a gate
# nobody reads, and that is exactly how real ID collisions got past one.
#
#   gates.sh ids       <registry> [base]         ID defined twice, or an ID on <base>
#                                                (default HEAD) that is gone. At landing
#                                                pass the trunk: there HEAD IS the tree.
#   gates.sh ids-refs  <registry> [trunk]        the same new ID filed on two unlanded
#                                                refs (local AND remote) or on a ref and
#                                                the trunk — invisible to any one tree
#   gates.sh wip       <trunk> <ceiling> [prefix]  more unlanded item branches than allowed
#   gates.sh orphans   [trunk]                   a worktree holding commits no branch has
#   gates.sh fresh     <artifact> <marker> [path...]
#                                                build artifact missing the marker, or
#                                                older than the last commit to <path>
#   gates.sh unrun     "<list-tests-cmd>" "<list-run-cmd>"
#                                                a test file on disk that no runner ran
#
# Environment:
#   ID_RE   an item ID               default: [A-Z]{2,}-[0-9]+
#   DEF_RE  a line that DEFINES one  default: ^- \*\*[A-Z]{2,}-[0-9]+\*\*
#
# Exit status: 0 pass, 1 fail, 2 usage or a broken check (a broken check
# never passes).

set -u

ID_RE=${ID_RE:-'[A-Z]{2,}-[0-9]+'}
DEF_RE=${DEF_RE:-'^- \*\*[A-Z]{2,}-[0-9]+\*\*'}

usage() {
	sed -n '2,21p' "$0" | sed 's/^#//' >&2
	exit 2
}

TMP=$(mktemp -d "${TMPDIR:-/tmp}/gates.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT

# defs <file>: "ID<TAB>defining line", one per definition.
defs() {
	grep -E "$DEF_RE" "$1" 2>/dev/null | while IFS= read -r line; do
		id=$(printf '%s\n' "$line" | grep -oE "$ID_RE" | head -1)
		printf '%s\t%s\n' "$id" "$line"
	done
}

gate_ids() {
	[ $# -ge 1 ] || usage
	reg=$1
	base=${2:-HEAD}
	git rev-parse --verify --quiet "$base^{commit}" >/dev/null || { echo "BROKEN: no such base: $base"; exit 2; }
	[ -f "$reg" ] || { echo "BROKEN: no such registry: $reg"; exit 2; }
	fail=0
	dup=$(defs "$reg" | cut -f1 | sort | uniq -d)
	if [ -n "$dup" ]; then
		echo "ID-DUPLICATE: defined more than once in $reg:"
		printf '  %s\n' $dup
		fail=1
	fi
	if git cat-file -e "$base:./$reg" 2>/dev/null; then
		git show "$base:./$reg" | grep -oE "$ID_RE" | sort -u >"$TMP/old"
		grep -oE "$ID_RE" "$reg" | sort -u >"$TMP/new"
		lost=$(comm -23 "$TMP/old" "$TMP/new")
		if [ -n "$lost" ]; then
			echo "ID-LOSS: on $base but gone from $reg (IDs are never deleted — move them to Done):"
			printf '  %s\n' $lost
			fail=1
		fi
	fi
	exit $fail
}

gate_ids_refs() {
	[ $# -ge 1 ] || usage
	reg=$1
	trunk=${2:-main}
	tsha=$(git rev-parse --verify --quiet "$trunk^{commit}") || { echo "BROKEN: no such trunk: $trunk"; exit 2; }
	git show "$tsha:./$reg" >"$TMP/trunk" 2>/dev/null || { echo "BROKEN: $reg not on $trunk"; exit 2; }
	defs "$TMP/trunk" >"$TMP/trunkdefs"
	: >"$TMP/table"
	git for-each-ref --format='%(refname)' refs/heads refs/remotes | while read -r ref; do
		case "$ref" in */HEAD) continue ;; esac
		sha=$(git rev-parse "$ref")
		# Landed, or simply behind: it has nothing the trunk lacks.
		git merge-base --is-ancestor "$sha" "$tsha" && continue
		base=$(git merge-base "$sha" "$tsha") || continue
		git show "$sha:./$reg" >"$TMP/r" 2>/dev/null || continue
		git show "$base:./$reg" >"$TMP/b" 2>/dev/null || : >"$TMP/b"
		defs "$TMP/b" | cut -f1 | sort -u >"$TMP/bids"
		defs "$TMP/r" | while IFS="$(printf '\t')" read -r id line; do
			grep -qxF "$id" "$TMP/bids" && continue # not new on this ref
			printf '%s\t%s\t%s\n' "$id" "${ref#refs/}" "$line"
		done >>"$TMP/table"
	done
	fail=0
	# (a) new on a ref, and the trunk has since filed a different item under it.
	while IFS="$(printf '\t')" read -r id ref line; do
		tline=$(awk -F '\t' -v i="$id" '$1 == i { print $2; exit }' "$TMP/trunkdefs")
		if [ -n "$tline" ] && [ "$tline" != "$line" ]; then
			echo "ID-COLLISION $id: $ref vs $trunk"
			echo "    $ref: $line"
			echo "    $trunk: $tline"
			fail=1
		fi
	done <"$TMP/table"
	# (b) new on two refs with different text. A branch and its own pushed copy
	# carry the same line and collapse to one.
	for id in $(cut -f1 "$TMP/table" | sort -u); do
		n=$(awk -F '\t' -v i="$id" '$1 == i { print $3 }' "$TMP/table" | sort -u | wc -l)
		if [ "$n" -gt 1 ]; then
			echo "ID-COLLISION $id: filed differently on unlanded refs"
			awk -F '\t' -v i="$id" '$1 == i { printf "    %s: %s\n", $2, $3 }' "$TMP/table"
			fail=1
		fi
	done
	exit $fail
}

gate_wip() {
	[ $# -ge 2 ] || usage
	trunk=$1 ceiling=$2 prefix=${3:-wt/}
	git rev-parse --verify --quiet "$trunk^{commit}" >/dev/null || { echo "BROKEN: no such trunk: $trunk"; exit 2; }
	git for-each-ref --format='%(refname:short)' "refs/heads/$prefix" | while read -r b; do
		git merge-base --is-ancestor "$b" "$trunk" || echo "$b"
	done >"$TMP/wip"
	n=$(wc -l <"$TMP/wip" | tr -d ' ')
	if [ "$n" -gt "$ceiling" ]; then
		echo "WIP $n/$ceiling: more items in flight than review can absorb — land or park before briefing:"
		sed 's/^/  /' "$TMP/wip"
		exit 1
	fi
	exit 0
}

gate_orphans() {
	trunk=${1:-main}
	fail=0
	git worktree list --porcelain | awk '
		/^worktree / { p = substr($0, 10) }
		/^HEAD /     { h = $2 }
		/^detached/  { print p "\t" h }' >"$TMP/detached"
	while IFS="$(printf '\t')" read -r path sha; do
		[ -n "$sha" ] || continue
		if [ -z "$(git for-each-ref --contains "$sha" --format='%(refname)' refs/heads 2>/dev/null)" ]; then
			n=$(git rev-list --count "$trunk..$sha" 2>/dev/null)
			echo "ORPHAN: $path HEAD $(git rev-parse --short "$sha") holds $n commit(s) on no branch"
			echo "        recover: git branch -f <its-branch> $sha   (if the branch is behind it)"
			fail=1
		fi
	done <"$TMP/detached"
	exit $fail
}

gate_fresh() {
	[ $# -ge 2 ] || usage
	art=$1 marker=$2
	shift 2
	[ -f "$art" ] || { echo "STALE: $art does not exist"; exit 1; }
	# Assert on content: an exit code of 0 from a build that did nothing is the
	# failure this gate exists for.
	if ! grep -aqF -- "$marker" "$art"; then
		echo "STALE: $art does not contain \"$marker\" — the change did not reach the artifact"
		exit 1
	fi
	src=$(git log -1 --format=%ct -- "$@" 2>/dev/null)
	[ -n "$src" ] || src=$(git log -1 --format=%ct 2>/dev/null)
	built=$(date -r "$art" +%s 2>/dev/null) || { echo "BROKEN: cannot read mtime of $art"; exit 2; }
	if [ -n "$src" ] && [ "$built" -lt "$src" ]; then
		echo "STALE: $art was built $(( (src - built) / 60 )) min before the last commit to its sources"
		exit 1
	fi
	exit 0
}

gate_unrun() {
	[ $# -eq 2 ] || usage
	sh -c "$1" 2>/dev/null | sort -u >"$TMP/ondisk" || { echo "BROKEN: $1"; exit 2; }
	sh -c "$2" 2>/dev/null | sort -u >"$TMP/ran" || { echo "BROKEN: $2"; exit 2; }
	[ -s "$TMP/ondisk" ] || { echo "BROKEN: found no test files — the check itself is wrong"; exit 2; }
	miss=$(comm -23 "$TMP/ondisk" "$TMP/ran")
	if [ -n "$miss" ]; then
		echo "UNRUN: on disk, matched by no runner (discover, do not enumerate):"
		printf '  %s\n' $miss
		exit 1
	fi
	exit 0
}

[ $# -ge 1 ] || usage
g=$1
shift
case "$g" in
ids) gate_ids "$@" ;;
ids-refs) gate_ids_refs "$@" ;;
wip) gate_wip "$@" ;;
orphans) gate_orphans "$@" ;;
fresh) gate_fresh "$@" ;;
unrun) gate_unrun "$@" ;;
*) usage ;;
esac
