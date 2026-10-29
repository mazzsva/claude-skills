# git-clean-up-worktrees-and-branches

Agents make worktrees. Nobody removes them.

Each Claude Code agent that works in isolation leaves a folder in
`.claude/worktrees` and a branch beside it. After a week there are dozens, and
most of them hold work that is already merged. Some of them do not, and those are
the ones that matter.

This finds the first kind and removes it, without a question. It keeps the
second kind, and says why.

## How it decides

A worktree goes when its work is already in the mainline, and nothing else is in
it. Merged by a merge commit, by a squash, by a rebase, or by a pull request on
GitHub. A squash or a rebase gives new hashes, so the test is the content, not
the hash.

A worktree stays when it holds an uncommitted change, an untracked file, or a
commit that was never pushed, in it or in any repository inside it. It stays
when an agent, a Claude Code session, or a process still works in it, or when a
file in it changed in the last 30 minutes. It stays when it is locked,
mid-rebase, or holds another worktree that stays.

A branch follows the same rules. When its worktree goes, the branch goes too.

Work that is pushed but not merged is open work, and it stays. After 30 days
with no commit, it asks.

A squash keeps the result and drops the steps. When a step that was never pushed
holds a version of a file that nothing else holds, it asks before that version
goes.

## Safety

Every worktree goes to the Trash, with its git record. **Put Back** returns
both. Every deleted branch is printed with the one command that brings it back.

It checks each item again just before it acts. It never pushes, never touches a
remote branch, and never runs `rm`. `main`, `master`, `trunk`, `develop`, and
the default branch are never deleted.

A run without `--apply` removes nothing, and says what it would do.

## Requirements

macOS 15 or later, for `trash`. Git 2.38 or later. The GitHub CLI is optional,
and finds squash merges that a later change hid.

Copyright © 2026 Lorenzo Mazzarotto
