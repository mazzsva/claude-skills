---
name: git-rebase-and-resolve-conflicts
description: Rebases a branch onto another branch and resolves each conflict. Use when rebasing onto a mainline, continuing a rebase that is already in progress, or resolving rebase conflicts.
version: 1.0.0
---

# Git Rebase and Resolve Conflicts

## Goal

Move a branch onto the newest commits of the mainline, and resolve each conflict with your
own judgement.

## Quick start

```bash
git status --short --branch
git branch "backup/$(git branch --show-current)/$(date +%Y%m%d-%H%M%S)"
git fetch origin && git rebase origin/<mainline>
```

* **DO** stop and tell me when the working tree holds changes of mine; they are mine to
  place, unless a rebase is in progress, when they are the conflict itself
* **DO** rebase onto `origin/<mainline>`; `git fetch` moves that ref, and leaves the local
  branch of the same name on the commit it already held
* **DO** make the backup branch; the verification below compares against it
* **DO** take the backup from `ORIG_HEAD` when a rebase is already in progress, with
  `git branch "backup/rebase/$(date +%Y%m%d-%H%M%S)" ORIG_HEAD`; HEAD is detached, so
  `--show-current` prints nothing and the line above fails on the empty name
* **DO** rebase a branch that sits on another branch with `git rebase --onto
  origin/<mainline> <that branch>`; a plain rebase replays commits the mainline already
  holds another way

## How to resolve a conflict

```bash
git diff --name-only --diff-filter=U
git add <file>
GIT_EDITOR=true git rebase --continue
```

* **DO** set `GIT_EDITOR=true`; this environment shows no editor, and git waits forever
* **DO** resolve and `git add` every file the first command lists, then continue; git stops
  again at the next commit it cannot replay, so repeat the block until it reports success
* **DO** pick a side for a binary file with `git checkout --theirs -- <file>` before the
  `git add`; it holds no marker, and git leaves the mainline version in the tree for
  `git add` to keep
* **DO** abort with `git rebase --abort`, and ask me, when a resolution is unclear

## How to verify

```bash
git log --format=%s origin/<mainline>..HEAD
git log --format=%s origin/<mainline>..<backup>
git grep -n "^<<<<<<< \|^>>>>>>> " HEAD
git diff origin/<mainline> HEAD
git diff <backup> HEAD
```

* **DO** account for each subject that the first two commands do not agree on; the rebase
  rewrote every hash, so the subjects are what compare, and one that only the second prints
  is a commit git dropped after a resolution emptied it, reported as success with an exit
  status of 0
* **DO** read the third command; git commits a marker I left behind and reports success
* **DO** treat a removed line as a mistake in both diffs; the first drops the work of the
  mainline, and the second drops mine, unless the mainline rewrote that line
* **DO NOT** push, and **DO NOT** delete the backup branch, until I ask

## Reference

A rebase replays my commits onto the mainline, so the sides are the opposite of a merge:

| Side | Marker | Content |
| --- | --- | --- |
| `--ours` | `<<<<<<< HEAD` | The mainline, and each commit of mine already replayed |
| `--theirs` | `>>>>>>> <commit>` | The commit of mine being replayed |

Copyright © 2026 Lorenzo Mazzarotto
