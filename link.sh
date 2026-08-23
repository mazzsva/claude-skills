#!/bin/bash
# Copyright © 2026 Lorenzo Mazzarotto
set -e
R="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.claude/skills
for p in "$R"/*/; do
  d="${p%/}"
  n=$(basename "$d")
  l=~/.claude/skills/"$n"
  if [ ! -d "$d" ]; then
    continue
  elif [ ! -f "$d/SKILL.md" ]; then
    echo "none  $n holds no SKILL.md"
  elif [ -L "$l" ] && [ ! -e "$l" ]; then
    ln -sfn "$d" "$l"
    echo "heal  $n was pointing at nothing"
  elif [ -L "$l" ] && [ "$(readlink "$l")" = "$d" ]; then
    echo "skip  $n"
  elif [ -e "$l" ] || [ -L "$l" ]; then
    echo "busy  $n is taken by something else in ~/.claude/skills"
  else
    ln -s "$d" "$l"
    echo "link  $n"
  fi
done
for l in ~/.claude/skills/*; do
  if [ -L "$l" ] && [ ! -e "$l" ]; then
    n=$(basename "$l")
    echo "dead  $n points at nothing, remove it with rm ~/.claude/skills/$n"
  fi
done
