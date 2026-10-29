---
name: git-clean-up-worktrees-and-branches
description: Moves each git worktree whose work is merged to the Trash, and deletes each merged local branch. Use when asked to clean up, remove, or prune worktrees or branches, or the worktrees that Claude Code agents leave behind.
---

# Git Clean Up Worktrees and Branches

## Goal

Remove each worktree and each local branch whose work the mainline already holds, keep each
one that holds work of mine, and tell me what went and what stayed.

## Quick start

Run the script in the repository of the current project:

```bash
SKILL=$(ls .claude/skills/git-clean-up-worktrees-and-branches/clean-up.sh ~/.claude/skills/git-clean-up-worktrees-and-branches/clean-up.sh 2>/dev/null | head -1)
bash "$SKILL" --apply
```

* **DO** run it without a question to me; it moves only work that the mainline holds, and
  the Trash keeps each folder
* **DO** run it only in the current repository, unless I ask for all of my projects
* **DO NOT** move, delete, or prune an item yourself, and **DO NOT** run `rm`, `git worktree
  remove`, `git worktree prune`, or `git branch -D`; the script checks each item again just
  before it acts, and you do not
* **DO NOT** push, and **DO NOT** delete a remote branch; the cleanup is local
* **DO** run it without `--apply` when I ask only what it would remove; that run removes
  nothing

## How to clean up all of my projects

Use this only when I ask for all of my projects, or all of my repositories:

```bash
SKILL=$(ls .claude/skills/git-clean-up-worktrees-and-branches/clean-up.sh ~/.claude/skills/git-clean-up-worktrees-and-branches/clean-up.sh 2>/dev/null | head -1)
for d in ~/Developer/*/; do [ -e "$d.git" ] && printf '%s\0' "$d"; done | xargs -0 bash "$SKILL" --apply
```

* **DO** report each repository in its own table; one run prints a `REPOSITORY` line and a
  `DONE` line for each

## How to decide about an `ASK` line

An `ASK` line is a worktree or a branch of one of two kinds: pushed but not merged, with no
commit for 30 days; or merged, but with commits that are not pushed and that hold file
versions the mainline does not hold. Ask me about all of them in one question, then include
the ones I chose:

```bash
SKILL=$(ls .claude/skills/git-clean-up-worktrees-and-branches/clean-up.sh ~/.claude/skills/git-clean-up-worktrees-and-branches/clean-up.sh 2>/dev/null | head -1)
bash "$SKILL" --apply --include '<worktree path or branch>' --include '<worktree path or branch>'
```

* **DO** use `AskUserQuestion` with `multiSelect`, one option for each `ASK` line, with the
  detail of the line in the description
* **DO** copy each path or branch from the `ASK` line, in single quotes
* **DO NOT** include a `KEEP` line that I did not name; `--include` cannot remove work that is
  not committed or not merged and not pushed, but a `KEEP` line that is pushed is still my
  open work
* **DO NOT** ask when the run printed no `ASK` line

## How to report

Give one table for each repository, with one row for each line that the script printed:

| Item | Result | Reason |
| --- | --- | --- |
| `<worktree or branch>` | Moved to the Trash, Deleted, Kept, or Failed | The detail from the line |

* **DO** give the `restore with` command of each deleted branch, as the line gives it
* **DO** tell me that a worktree comes back with **Put Back** in the Trash, on its folder and
  on its git record of the same name, and then the `restore with` command of its branch
* **DO** give the cause of each `KEEP` line in plain words, such as `2 commits not pushed`
* **DO** give each `FAILED` line exactly; the script changed nothing for that item, or says
  what it left behind
* **DO NOT** offer to remove a `KEEP` item; the script keeps it because it holds work

## Reference

| Line | Means |
| --- | --- |
| `TRASH`, `TRASHED` | The worktree folder and its git record go, or went, to the Trash |
| `DELETE`, `DELETED` | The local branch is, or was, deleted; the line gives the command that restores it |
| `KEEP` | The item stays; the line says why |
| `ASK` | The item stays until I include it; the line says why it is not sure |
| `NOTE` | A fetch or a remote failed; the script used the refs of the last fetch |
| `FAILED` | The item, or the repository, was not changed, or changed only as the line says |

The script keeps a worktree when any of these is true:

| Check | Keeps it when |
| --- | --- |
| Work | It holds an uncommitted change, an untracked file, a file hidden from `git status`, a commit that is not pushed, or a submodule or a nested repository with work that is not pushed |
| Merge | Its work is not in the mainline, by ancestry, by squash, by rebase, or by a merged pull request |
| Use | It is locked by a live agent or by me, a process or a Claude Code session works in it, a file in it changed in the last 30 minutes, or an operation such as a rebase is in progress |
| Shape | It is the main worktree, it holds the main branch or a worktree that stays, its `.git` link is broken, its path is a symbolic link, or its disk is not connected or cannot be read |

Copyright © 2026 Lorenzo Mazzarotto
