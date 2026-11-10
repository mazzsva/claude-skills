# rebase

The rebase is not the hard part. The conflicts are, and git reports three kinds of lost work
as success, with an exit status of 0.

This skill reads each conflict and decides. It then proves that the result holds each commit
and each line that the branch had. When a resolution is not clear, it stops and asks.

## How it works

* **It knows that the sides are the opposite of a merge.** In a rebase, `--ours` is the
  mainline, and `--theirs` is the commit of yours that git replays. Most wrong resolutions
  start here.
* **It picks the side of a binary file on purpose.** A binary file holds no conflict marker.
  Git leaves the mainline copy in the tree, and `git add` keeps it without a word.
* **It finds the commit that git dropped.** A resolution can empty a commit. Git then drops
  the commit and reports success. A rebase rewrites each hash, so the skill compares the
  subjects of the commits with those of a backup branch.
* **It finds the marker that git committed.** Git commits a `<<<<<<<` line that stays in a
  file, and reports success. The skill searches the result for each marker.
* **It accounts for each removed line.** In the diff against the mainline, one of your commits
  must remove the line on purpose. In the diff against the backup, the mainline must be the
  cause. Any other removed line is lost work.
* **It runs the build and the tests.** A commit that replays with no conflict can still use a
  name that the mainline changed.
* **It takes the backup from the correct commit.** For a rebase that is already in progress,
  it reads the tip from `rebase-merge/orig-head`, because `ORIG_HEAD` can point at another
  commit after a reset.
* **It does not abort to ask.** `git rebase --abort` loses each resolution, so the skill
  leaves the rebase in progress while it waits for your answer.

## Safety

It makes a backup branch first, and it pushes only when you ask, with `--force-with-lease`.

## Requirements

Git, and a remote named `origin`.

Copyright © 2026 Lorenzo Mazzarotto
