# conf.sh — sourced, never run. Reads the project's .claude/desk.conf.
#
# The file is KEY=value lines, committed, so every worktree has it. It is
# PARSED, never sourced or eval'd: only lines matching ^[A-Z_]+= count, one
# layer of surrounding quotes is stripped, anything else (comments, blanks)
# is ignored. An environment variable of the same name overrides the file.
#
# Sets: CONF_TOP (worktree top), CONF_MAIN (main checkout), CONF_FILE, and
# every key below. Provides: conf_require KEY.

CONF_KEYS="TRUNK BRANCH_PREFIX SLOT_PATTERN TEST_CMD TYPECHECK_CMD BUILD_CMD REGISTRY ID_RE DEF_RE WIP_CEILING PUSH_AFTER_LAND PUSH_ON_DONE"

CONF_TOP=$(git rev-parse --show-toplevel 2>/dev/null) && CONF_TOP=$(cd "$CONF_TOP" && pwd -P)
CONF_MAIN=
_c=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) &&
	CONF_MAIN=$(cd "$_c/.." 2>/dev/null && pwd -P)
CONF_FILE=${CONF_TOP:+$CONF_TOP/.claude/desk.conf}

# Remember which keys the environment set (set-but-empty counts: REGISTRY=).
_env=" "
for _k in $CONF_KEYS; do
	eval "[ -n \"\${$_k+x}\" ]" && _env="$_env$_k "
done

if [ -n "$CONF_FILE" ] && [ -f "$CONF_FILE" ]; then
	while IFS= read -r _l || [ -n "$_l" ]; do
		case $_l in [A-Z_]*=*) ;; *) continue ;; esac
		_k=${_l%%=*} _v=${_l#*=}
		case $_k in *[!A-Z_]*) continue ;; esac
		case " $CONF_KEYS " in *" $_k "*) ;; *) continue ;; esac
		case $_env in *" $_k "*) continue ;; esac
		case $_v in \"*\") _v=${_v#\"} _v=${_v%\"} ;; \'*\') _v=${_v#\'} _v=${_v%\'} ;; esac
		# Safe: the value is assigned, not expanded. The key is whitelisted.
		eval "$_k=\$_v"
	done <"$CONF_FILE"
fi

_d() { eval "[ -n \"\${$1+x}\" ]" || eval "$1=\$2"; }
_d TRUNK main
_d BRANCH_PREFIX wt/
_d SLOT_PATTERN "${CONF_MAIN:+$(dirname "$CONF_MAIN")/$(basename "$CONF_MAIN")-wt-[1-9]}"
_d TEST_CMD ""
_d TYPECHECK_CMD ""
_d BUILD_CMD ""
_d REGISTRY BACKLOG.md
_d ID_RE '[A-Z]{2,}-[0-9]+'
_d DEF_RE '^- \*\*[A-Z]{2,}-[0-9]+\*\*'
_d WIP_CEILING 3
_d PUSH_AFTER_LAND 0
_d PUSH_ON_DONE 1
unset _c _k _v _l _env

# conf_require KEY: exit 1 with a CONFIG line when KEY is empty.
conf_require() {
	eval "_v=\${$1-}"
	[ -n "$_v" ] && return 0
	case $1 in
	TEST_CMD) echo "CONFIG: TEST_CMD not set in .claude/desk.conf — a desk without a test command is no oracle" ;;
	*) echo "CONFIG: $1 not set in .claude/desk.conf" ;;
	esac
	exit 1
}
