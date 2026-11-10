---
name: rebase
description: Rebases a branch onto another branch and resolves each conflict. Use when rebasing onto a mainline, continuing a rebase that is already in progress, resolving rebase conflicts, or when a pull request conflicts with its base branch.
---

# Rebase

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
* **DO** take the backup from the tip that git saved, when a rebase is already in progress;
  HEAD is detached, so `--show-current` prints nothing, and `ORIG_HEAD` can point at another
  commit after a reset:
  `git branch "backup/rebase/$(date +%Y%m%d-%H%M%S)" "$(cat "$(git rev-parse --git-path rebase-merge/orig-head)")"`
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
* **DO** pick a side for a binary file on purpose, with `git checkout --theirs -- <file>` for
  my version or `--ours` for the mainline, before the `git add`; it holds no marker, and git
  leaves the mainline version in the tree for `git add` to keep
* **DO** stop and ask me when a resolution is unclear, and leave the rebase in progress;
  `git rebase --abort` loses each resolution that you made, so run it only when I say so

## How to verify

```bash
git log --format=%s origin/<mainline>..HEAD
git log --format=%s origin/<mainline>..<backup>
git grep -n "^<<<<<<< \|^>>>>>>> " HEAD
git diff origin/<mainline> HEAD
git diff <backup> HEAD
```

* **DO** account for each subject that the first two commands do not agree on; the rebase
  rewrote every hash, so the subjects are what compare. A subject that only the second prints
  is a commit that is gone: the mainline holds its patch already, `--onto` left it out, or a
  resolution emptied it, and git reports each case as success with an exit status of 0
* **DO** read the third command; git commits a marker I left behind and reports success
* **DO** account for each removed line in both diffs: in the first, one of my commits must
  remove it on purpose, and in the second, the mainline must be the cause; any other removed
  line is lost work
* **DO** run the build and the tests of the project; a commit that replays with no conflict
  can still use a name that the mainline changed. Put the fix in a new commit, and tell me
* **DO NOT** push, and **DO NOT** delete the backup branch, until I ask

## How to push

Push only when I ask, and only after the verification:

```bash
git push --force-with-lease origin <branch>
```

* **DO** use `--force-with-lease`, and never `--force`; a rebase rewrites each commit, so a
  plain push is rejected, and the lease refuses when the branch on `origin` moved after the
  fetch

## Reference

A rebase replays my commits onto the mainline, so the sides are the opposite of a merge:

| Side | Marker | Content |
| --- | --- | --- |
| `--ours` | `<<<<<<< HEAD` | The mainline, and each commit of mine already replayed |
| `--theirs` | `>>>>>>> <commit>` | The commit of mine being replayed |

Copyright © 2026 Lorenzo Mazzarotto
