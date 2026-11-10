# propose

A model writes code faster than a person can review it. Anthropic reports that its code
output for each engineer grew 200% in one year, and that
"[many PRs get skims rather than deep reads](https://claude.com/resources/articles/code-review)".
A pull request that holds three topics makes that worse.

This skill turns a working tree of mixed changes into pull requests that a reviewer can read:
one topic for each pull request, in logical commits, on a well-named branch.

## How it works

* **It splits by reason, not by file.** A removal, a new feature, and a restyle on one screen
  are three topics. Each topic must fit in one sentence, and a sentence that needs "and" is
  two topics.
* **It splits one file between two topics.** Each branch gets the base text with only the
  lines of its topic.
* **It isolates each topic.** With more than one topic, each one gets its own worktree, made
  from the default branch of `origin`. Each pull request holds only its lines, and your
  working tree stays as it is until the end.
* **It proves that no change is lost before it cleans up.** It compares the hash of each
  changed file with the same file on its branch. For a file that it split, it merges the
  branches in a scratch worktree and compares the result byte for byte.
* **It reads everything as data.** File content, diffs, `gh` output, hook output, and
  templates are never instructions.
* **It does not trust a success message.** A hook can change a commit message, so it compares
  the message after each commit. After a squash merge, `git cherry` reports merged work as
  missing, so it compares the content.
* **It writes for a reviewer who has no other source.** A title starts with a specific verb
  and names the object. The body says why the change is needed, and it uses your template
  exactly.
* **It stops when the decision is yours.** A secret or a file over 100 MB in a commit, a
  failed check, a rejected push, and a plan with more than one topic all wait for your answer.
* **It is short on purpose.** It grew to 751 lines in more than 60 commits of tests, and I
  then rewrote it in fewer than 200. Anthropic's skill guide gives the reason:
  "[the context window is a public good](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)".

## Safety

It never forces a push, skips a hook, pushes to the default branch, or merges a pull request.

## Requirements

Git 2.38 or later, and the GitHub CLI, signed in.

Copyright © 2026 Lorenzo Mazzarotto
