#!/bin/sh
# check-secrets.sh [--staged]
#
# This repository is public. Scan what git would publish for things that must
# never be in it: home-directory paths, private keys, API tokens. Also reads an
# optional, gitignored `.secrets-denylist` (one fixed string per line: client
# names, private repo names, hostnames) so the private words themselves never
# have to be committed to be blocked.
#
# Installed as the pre-commit hook by install.sh (core.hooksPath = .githooks).
# Exit status: 0 clean, 1 findings, 2 not a git repository.

set -u

cd "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || exit 2

if [ "${1-}" = --staged ]; then
	files=$(git diff --cached --name-only --diff-filter=ACMR)
else
	files=$(git ls-files)
fi
[ -n "$files" ] || exit 0

# Built from pieces so this file does not match itself.
U='/Us''ers/[A-Za-z0-9_]'
H='/ho''me/[A-Za-z0-9_]'
PATTERNS="$U|$H|BEGIN [A-Z ]*PRIV""ATE KEY|sk-ant-[A-Za-z0-9_-]{8}|gh[pousr]_[A-Za-z0-9]{20}|github_pat_[A-Za-z0-9_]{20}|AKIA[0-9A-Z]{16}|xox[abposr]-[A-Za-z0-9-]{10}|AIza[0-9A-Za-z_-]{30}"

found=0
out=$(printf '%s\n' "$files" | while IFS= read -r f; do
	[ -f "$f" ] || continue
	grep -nIHE -- "$PATTERNS" "$f" 2>/dev/null
done)
if [ -n "$out" ]; then
	echo "SECRET/PATH: these lines must not be published:"
	printf '%s\n' "$out" | cut -c1-200
	found=1
fi

if [ -s .secrets-denylist ]; then
	out=$(printf '%s\n' "$files" | while IFS= read -r f; do
		[ -f "$f" ] || continue
		grep -nIHiF -f .secrets-denylist -- "$f" 2>/dev/null
	done)
	if [ -n "$out" ]; then
		echo "DENYLIST: private names found (denylist words are not printed):"
		printf '%s\n' "$out" | cut -d: -f1,2 | sed 's/^/  /'
		found=1
	fi
fi

exit $found
