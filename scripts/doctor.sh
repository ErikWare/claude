#!/bin/sh
# doctor.sh [--run] — the honest adoption check. Run it in any repository.
#
# One line per item, OK, MISSING or WARN. It never creates or changes
# anything. With --run it also runs TEST_CMD on the trunk, which is the only
# way to know the desk has an oracle rather than a string.
#
# Exit status: 0 nothing MISSING, 1 at least one MISSING, 2 usage.

set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
RUN=0
case "${1-}" in --run) RUN=1 ;; "") ;; *) echo "usage: doctor.sh [--run]" >&2; exit 2 ;; esac

. "$HERE/conf.sh"
miss=0
ok() { echo "OK       $*"; }
missing() { echo "MISSING  $*"; miss=1; }
warn() { echo "WARN     $*"; }

if [ -z "$CONF_TOP" ]; then
	missing "git repository (cwd is not in one)"
	exit 1
fi
ok "git repository: $CONF_TOP"

if [ "$CONF_TOP" = "$CONF_MAIN" ]; then
	ok "main checkout"
else
	warn "this is a linked worktree; the desk runs in the main checkout $CONF_MAIN"
fi

if git rev-parse --verify --quiet "refs/heads/$TRUNK" >/dev/null; then
	ok "trunk branch: $TRUNK"
else
	missing "trunk branch: $TRUNK (no such branch, or no commits yet)"
fi

if git remote get-url origin >/dev/null 2>&1; then
	ok "origin remote"
else
	warn "no origin remote: done.sh's push (the orphan insurance) is off"
fi

if [ -f "$CONF_FILE" ]; then
	ok ".claude/desk.conf"
else
	missing ".claude/desk.conf (copy the kit's templates/desk.conf)"
fi

if [ -z "$TEST_CMD" ]; then
	missing "TEST_CMD: needs the command that proves this project works"
elif [ $RUN = 0 ]; then
	ok "TEST_CMD set: $TEST_CMD (not run; --run runs it on the trunk)"
elif [ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" != "$TRUNK" ]; then
	warn "TEST_CMD not run: HEAD is not $TRUNK"
else
	log=$(mktemp "${TMPDIR:-/tmp}/doctor.XXXXXX")
	(cd "$CONF_TOP" && sh -c "$TEST_CMD") >"$log" 2>&1
	rc=$?
	if [ $rc -eq 0 ]; then
		ok "TEST_CMD exits 0 on $TRUNK"
	else
		missing "TEST_CMD exits $rc on $TRUNK:"
		tail -5 "$log" | sed 's/^/           | /'
	fi
	rm -f "$log"
fi

if [ -z "$REGISTRY" ]; then
	warn "REGISTRY not set: the ID gates are off"
elif [ ! -f "$CONF_TOP/$REGISTRY" ]; then
	missing "registry $REGISTRY (set REGISTRY= in desk.conf to turn the ID gates off)"
elif out=$(cd "$CONF_TOP" && "$HERE/gates.sh" ids "$REGISTRY" 2>&1); then
	ok "registry $REGISTRY passes gates.sh ids"
else
	missing "registry $REGISTRY fails gates.sh ids:"
	printf '%s\n' "$out" | head -5 | sed 's/^/           | /'
fi

n=0
for d in $SLOT_PATTERN; do
	[ -d "$d" ] && n=$((n + 1))
done
if [ $n -gt 0 ]; then
	ok "$n slot folder(s) match $SLOT_PATTERN"
else
	missing "slot folders matching $SLOT_PATTERN"
fi

if [ -d "$CONF_TOP/docs/briefs" ]; then
	ok "docs/briefs/"
else
	missing "docs/briefs/"
fi

exit $miss
