# propose

One commit called "Update files" tells a reviewer nothing, and one pull request that holds
three topics is hard to review.

This commits every pending change, split by reason into logical commits, pushes each topic on
a well-named branch, and opens one pull request for each topic. It uses your template, and it
writes a title that starts with a specific verb and names the object.

## What happens

* On the default branch, detached, or in a worktree: it makes a new branch for each topic from
  the default branch, builds each in its own worktree, and opens the pull requests.
* On a feature branch: it keeps the branch, renames it when the name does not fit, and adds the
  commits. A branch with an open pull request gets the new commits, and the skill suggests a
  new title when the old one is stale.
* After a merged or closed pull request: it starts a new branch.
* At the end, the changes live on the branches, and the working tree is clean.

## Safety

It commits everything that git does not ignore. It stops and asks only for a secret, a file
over 100 MB, a rejected push, or a failed check. It never forces a push, skips a hook, amends a
commit that exists, or pushes to the default branch.

## Requirements

Git 2.38 or later, and the GitHub CLI, signed in.

Copyright © 2026 Lorenzo Mazzarotto
