#!/bin/sh
# install.sh [--import] [--dry-run] [--uninstall]
#
# Wire this clone into Claude Code by SYMLINK, so the clone stays the single
# source of truth and `git pull` updates every machine at once. Safe to re-run:
# anything already correct is reported OK, and anything in the way that this
# script did not create is reported SKIP and left untouched.
#
#   ~/.claude/kit              -> this clone (stable path the boot file uses)
#   ~/.claude/skills/<name>    -> ~/.claude/kit/skills/<name>   (one per skill)
#   ~/.claude/CLAUDE.md        created with one line, `@~/.claude/kit/CLAUDE.md`,
#                              if it does not exist. If it does, it is NOT edited
#                              unless you pass --import, which appends that one
#                              import line inside a marked block.
#
#   --import     append the import to an existing ~/.claude/CLAUDE.md
#   --dry-run    print what would change, change nothing
#   --uninstall  remove only links that point into the kit, and the marked block
#
# Honours CLAUDE_CONFIG_DIR. Needs git >= 2.23 (for `git switch`). macOS and
# Linux; not Windows.

set -u

REPO=$(cd "$(dirname "$0")" && pwd -P)
CD=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
KIT=$CD/kit
IMPORT=0 DRY=0 UNINSTALL=0
BEGIN='# >>> claude kit >>>'
END='# <<< claude kit <<<'

for a in "$@"; do
	case "$a" in
	--import) IMPORT=1 ;;
	--dry-run) DRY=1 ;;
	--uninstall) UNINSTALL=1 ;;
	*) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
	esac
done

run() { if [ $DRY = 1 ]; then echo "  would: $*"; else "$@"; fi; }
say() { if [ $DRY = 1 ]; then printf "(dry) %-7s %s\n" "$1" "$2"; else printf "%-7s %s\n" "$1" "$2"; fi; }

# The import line: `~` form when the config dir is the default, else absolute.
if [ "$CD" = "$HOME/.claude" ]; then IMP='@~/.claude/kit/CLAUDE.md'; else IMP="@$KIT/CLAUDE.md"; fi

# link <path> <target>: create, confirm, or refuse to clobber.
link() {
	if [ -L "$1" ]; then
		if [ "$(readlink "$1")" = "$2" ]; then say OK "$1"; return 0; fi
		say SKIP "$1 is a link to $(readlink "$1"), not $2 — remove it yourself to switch"
		return 1
	fi
	if [ -e "$1" ]; then
		say SKIP "$1 exists and is not a link — left untouched"
		return 1
	fi
	run ln -s "$2" "$1" && say LINKED "$1 -> $2"
}

if [ $UNINSTALL = 1 ]; then
	for l in "$KIT" "$CD"/skills/*; do
		[ -L "$l" ] || continue
		case "$(readlink "$l")" in "$REPO" | "$KIT"/*) run rm "$l" && say REMOVED "$l" ;; esac
	done
	if [ -f "$CD/CLAUDE.md" ] && grep -qF "$BEGIN" "$CD/CLAUDE.md"; then
		run sh -c "awk -v b='$BEGIN' -v e='$END' '\$0==b{s=1} !s{print} \$0==e{s=0}' '$CD/CLAUDE.md' >'$CD/CLAUDE.md.tmp' && mv '$CD/CLAUDE.md.tmp' '$CD/CLAUDE.md'"
		say REMOVED "kit block from $CD/CLAUDE.md"
	fi
	exit 0
fi

command -v git >/dev/null || { say FAIL "git is not installed"; exit 1; }
gv=$(git --version | awk '{print $3}')
case "$gv" in 1.* | 2.[0-9].* | 2.1[0-9].* | 2.2[0-2].*) say WARN "git $gv: the scripts need >= 2.23 (git switch)" ;; esac

[ -d "$CD" ] || { run mkdir -p "$CD" && say CREATED "$CD"; }
[ -d "$CD/skills" ] || { run mkdir -p "$CD/skills" && say CREATED "$CD/skills"; }

rc=0
link "$KIT" "$REPO" || rc=1
for s in "$REPO"/skills/*/; do
	n=$(basename "$s")
	[ -f "$s/SKILL.md" ] || continue
	link "$CD/skills/$n" "$KIT/skills/$n" || rc=1
done

# Boot file. A symlinked ~/.claude/CLAUDE.md is skipped in some desktop
# sessions (see the memory docs), so this is a real file holding an import.
if [ ! -e "$CD/CLAUDE.md" ]; then
	if [ $DRY = 1 ]; then echo "  would: create $CD/CLAUDE.md"; else
		printf '%s\n%s\n%s\n' "$BEGIN" "$IMP" "$END" >"$CD/CLAUDE.md"
		say CREATED "$CD/CLAUDE.md (imports the kit's boot file)"
	fi
elif grep -qF "$IMP" "$CD/CLAUDE.md"; then
	say OK "$CD/CLAUDE.md imports the kit"
elif [ $IMPORT = 1 ]; then
	if [ $DRY = 1 ]; then echo "  would: append $IMP to $CD/CLAUDE.md"; else
		printf '\n%s\n%s\n%s\n' "$BEGIN" "$IMP" "$END" >>"$CD/CLAUDE.md"
		say APPENDED "$IMP to $CD/CLAUDE.md ($(wc -l <"$CD/CLAUDE.md" | tr -d ' ') lines now) — check it does not duplicate what is already there"
	fi
else
	say WARN "$CD/CLAUDE.md exists and does not import the kit. Left untouched. Re-run with --import, or add this line yourself: $IMP"
	rc=1
fi

# This clone's own pre-commit hook: refuses home paths, keys, denylisted names.
run git -C "$REPO" config core.hooksPath .githooks && say OK "pre-commit secrets check enabled for this clone"

echo
echo "Next: open Claude Code in a project's main checkout and run /start-desk"
exit $rc
