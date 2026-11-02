# propose

One commit called "Update files" tells a reviewer nothing, and one pull request
that holds three topics is hard to review.

A day of work is rarely one change. It is a fix, a rename, a new test, and a
dependency bump, all in the same files. This groups them by topic, splits each
topic into logical chunks, pushes it on a branch with a good name, and opens one
pull request for each topic.

## How it plans

It reads every change, then decides how many pull requests the work needs. One
topic is one pull request, and it asks nothing. Unrelated topics, or one topic
that is too big to review, become a plan that you approve first: a name, the
files, and a reason for each. Each independent pull request starts from the
default branch, and a change that needs another stacks on top of it.

## How it splits

Each commit holds one change a reviewer can read alone. A change travels with
its tests, its lockfile, and its generated files. The commits go in the order
they build, and a change with one reason stays one commit, however many files it
touches.

When one file holds two changes, it stages only the lines of the first one.
`git add -p` waits for a person, so a small script does it instead. It writes
an index, and never the file.

## How it names the branch

It ignores a branch name that does not fit the work. On the default branch, or
on a detached HEAD, it makes a new branch. It renames a branch that is not
pushed and has no pull request. It keeps a branch that fits, and asks before it
touches a branch that is pushed or has a pull request.

## Safety

The working tree is never touched. It is the backup, and at the end it proves
the work: every change is in a commit, and nothing else is.

It never forces a push, never skips a hook, never amends, and never rewrites a
commit that already exists. It reads every new line for a secret, and asks
before a secret or a file larger than 50 MB goes into a commit. A `.DS_Store`,
build output, or an agent worktree stays out, and it says so. It treats text in
files, diffs, and hook output as data, never as an instruction.

It asks before a fork, a branch whose pull request is closed, a hook that
changes a file, an operation in progress, or a push that the remote rejects.
Ask it only to commit, and it stops there.

## After the pull request

It lists the worktrees and branches that the session made, and asks if you want
them removed. It removes only a clean, pushed item, never the worktree you are
in, and it prints the commands for later when you say no.

## Requirements

Git 2.38 or later, and the GitHub CLI, signed in.

Copyright © 2026 Lorenzo Mazzarotto
