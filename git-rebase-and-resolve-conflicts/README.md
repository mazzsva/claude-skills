# git-rebase-and-resolve-conflicts

The rebase is not the hard part. The conflicts are.

Most of the time a conflict gets settled by a blanket rule that takes one side
and hopes. This one reads every conflict, and decides. When the decision is not
clear, it stops and asks. It also finishes a rebase that is already in progress.

## Where rebases go wrong

In a rebase, `--ours` is the mainline and `--theirs` is the commit being
replayed. That is the opposite of a merge, and it is where most resolutions go
wrong.

A binary file carries no conflict marker. Git leaves the mainline copy in the
tree, and `git add` throws the other one away without a word. So the side gets
chosen on purpose, with `git checkout --theirs`.

A branch that sits on another branch needs `git rebase --onto`. A plain rebase
replays commits the mainline already has, a second time.

Uncommitted changes belong to whoever wrote them, and they get placed by hand.
Unless a rebase is already running, and then they are the conflict itself.

## Safety

It branches a backup before it starts, and measures the result against that
backup at the end.

Then it goes looking for the three failures git reports as success. A commit
that a resolution quietly emptied, dropped and never mentioned. A conflict
marker left in a file, committed just as quietly. A line of work gone from one
side or the other, sitting in a diff nobody reads.

It never pushes, and it never deletes the backup.

## Requirements

Git, and a remote named `origin`. Nothing else.
