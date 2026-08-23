#!/bin/bash
set -e
R="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.claude/skills
for d in "$R"/*/; do
  n=$(basename "$d")
  if [ -e ~/.claude/skills/"$n" ]; then
    echo "skip  $n"
  else
    ln -s "$d" ~/.claude/skills/"$n"
    echo "link  $n"
  fi
done
