# Claude Skills

The skills I use with [Claude Code](https://claude.com/claude-code). Every day,
on every machine.

## Skills

| Skill | Description |
| --- | --- |
| [git-rebase-and-resolve-conflicts](git-rebase-and-resolve-conflicts) | Rebases a branch, and resolves every conflict. |
| [simulator-frame-screenshot](simulator-frame-screenshot) | Puts the simulator screen inside a real Apple bezel. |

Every skill stands on its own. Its assets and its README sit in the same folder.

## How it works

Claude Code reads skills from `~/.claude/skills/`. This repository lives
somewhere else, in `~/Developer/`, under version control.

`link.sh` connects the two. It puts a symbolic link in `~/.claude/skills/` for
each skill folder, and Claude Code follows the link without knowing the
difference.

One copy of every skill. One place to change it.

## Requirements

macOS, and [Claude Code](https://claude.com/claude-code). Git, and the GitHub
CLI from `brew install gh`.

Every skill says what it needs, in its own README.

## On a new machine

```bash
gh auth login
git clone https://github.com/mazzsva/claude-skills.git ~/Developer/claude-skills
~/Developer/claude-skills/link.sh
```

Three commands, from any folder. Skills are read at startup, so restart Claude
Code, or run `/reload-skills` and keep working.

## A new skill

A skill starts in `~/.claude/skills/`, as a plain folder, and stays there while
it is still changing. When it is ready it moves in:

```bash
mv ~/.claude/skills/<skill> ~/Developer/claude-skills/
~/Developer/claude-skills/link.sh
```

The move comes first. `link.sh` never takes a name that is already in use, so
the folder itself would stand in the way of its own link.

`link.sh` is safe to run at any time. It creates what is missing, leaves
everything else alone, deletes nothing, and says what it did.

Copyright © 2026 Lorenzo Mazzarotto
