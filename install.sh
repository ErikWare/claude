#!/bin/sh
# Link ~/.claude/*.md to this repo's home/ so every machine shares one copy.
# An existing real file is kept as <name>.prev. Safe to re-run.
set -e
src="$(cd "$(dirname "$0")/home" && pwd)"
mkdir -p "$HOME/.claude"
for f in "$src"/*.md; do
  dst="$HOME/.claude/$(basename "$f")"
  [ -e "$dst" ] && [ ! -L "$dst" ] && mv "$dst" "$dst.prev"
  ln -sfn "$f" "$dst"
  echo "linked $dst"
done
