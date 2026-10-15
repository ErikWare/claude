#!/bin/sh
# Link ~/.claude/*.md and ~/.claude/skills/* to this repo's home/ so every
# machine shares one copy. An existing real file is kept as <name>.prev.
set -e
src="$(cd "$(dirname "$0")/home" && pwd)"
mkdir -p "$HOME/.claude/skills"
for f in "$src"/*.md "$src"/skills/*; do
  rel="${f#"$src"/}"
  dst="$HOME/.claude/$rel"
  [ -e "$dst" ] && [ ! -L "$dst" ] && mv "$dst" "$dst.prev"
  ln -sfn "$f" "$dst"
  echo "linked $dst"
done
