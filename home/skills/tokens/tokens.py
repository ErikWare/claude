#!/usr/bin/env python3
"""Real token use of Claude Code sessions, from the transcripts' own usage records (no estimates).
Usage: tokens.py [--dir PROJECT_CWD] [--session ID] [--all]
  default: the newest session of the project whose cwd is --dir (default: $PWD), subagents included.
  --all: every session of that project.
Prints one line per session: total  in  cache_write  cache_read  out  context_now  cost_usd, then the TOTAL int.
Opus 5.5 rates ($/1M): in 4, cache write 1h 8, cache read 0.4, out 20."""
import argparse, json, os, sys
from pathlib import Path

RATE = {"in": 4, "cw": 8, "cr": 0.4, "out": 20}


def proj_dir(cwd: str) -> Path:
    return Path.home() / ".claude" / "projects" / cwd.replace("/", "-").replace("_", "-")


def usage(files) -> dict:
    seen, s, last = set(), dict.fromkeys(RATE, 0), 0
    for f in files:
        for ln in open(f, errors="ignore"):
            try:
                d = json.loads(ln)
            except ValueError:
                continue
            m = d.get("message")
            if not isinstance(m, dict) or not m.get("usage") or m.get("id") in seen:
                continue
            seen.add(m.get("id"))
            u = m["usage"]
            row = {"in": u.get("input_tokens") or 0, "cw": u.get("cache_creation_input_tokens") or 0,
                   "cr": u.get("cache_read_input_tokens") or 0, "out": u.get("output_tokens") or 0}
            for k in s:
                s[k] += row[k]
            if f == files[0]:
                last = row["in"] + row["cw"] + row["cr"]
    s["total"], s["ctx"] = sum(s[k] for k in RATE), last
    s["usd"] = sum(s[k] * RATE[k] for k in RATE) / 1e6
    return s


def main() -> int:
    a = argparse.ArgumentParser()
    a.add_argument("--dir", default=os.getcwd())
    a.add_argument("--session")
    a.add_argument("--all", action="store_true")
    o = a.parse_args()
    p = proj_dir(o.dir)
    while not p.exists() and o.dir not in ("/", ""):          # a repo subdir: walk up to the session's project
        o.dir = str(Path(o.dir).parent)
        p = proj_dir(o.dir)
    sessions = sorted(p.glob("*.jsonl"), key=lambda f: f.stat().st_mtime, reverse=True)
    if o.session:
        sessions = [f for f in sessions if f.stem.startswith(o.session)]
    elif not o.all:
        sessions = sessions[:1]
    if not sessions:
        print(f"no sessions under {p}", file=sys.stderr)
        return 1
    tot = 0
    for f in sessions:
        s = usage([f, *sorted((f.parent / f.stem / "subagents").glob("*.jsonl"))])
        tot += s["total"]
        print(f"{f.stem[:8]} total {s['total']:,} in {s['in']:,} cw {s['cw']:,} cr {s['cr']:,} out {s['out']:,} "
              f"ctx {s['ctx']:,} ${s['usd']:.2f}")
    print(tot)
    return 0


if __name__ == "__main__":
    sys.exit(main())
