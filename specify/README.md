# specify

A vague request gets industry defaults. A request that is too specific stops the model from a
better path. Anthropic's field guide to Claude Fable 5 names the real limit: the quality of
the work is
"[bottlenecked by my ability to clarify its unknowns](https://claude.com/resources/articles/a-field-guide-to-claude-fable-finding-your-unknowns)".

This skill finds those unknowns before any code exists. It interviews you about the decisions
that only you can make, and writes a spec that a new session can build from and that the
[prove](../prove) skill can check.

## How it works

* **It reads the code before it asks.** A question that the repository answers costs you a
  turn. It also finds a file that already does a similar thing, because source code shows a
  pattern better than words do.
* **It shows you the decisions that you did not know about.** A migration of saved data, a
  second platform, a screen with no data: the code forces them, and the request did not
  mention them.
* **It asks only what changes the result.** One question at a time, the largest decision
  first, with choices and a recommendation. Each other decision gets a default, and the spec
  marks it as assumed. When words are not enough, it offers a throwaway prototype.
* **It specifies the result, not the path.** Each requirement is a behaviour that a person or
  a test can observe. A spec that fixes the implementation stops a better one that the model
  finds during the build.
* **It defines done.** Requirements are numbered, edge cases need tests, and each check is an
  exact command with expected output.
* **It hands the build to a new session.** As the
  [Claude Code best practices](https://code.claude.com/docs/en/best-practices) say, "the
  build begins with a clean context and a written definition of done". When the code forces
  the build to leave the spec, the build logs the deviation there, and `prove` asks you.

## Safety

A spec stays local. The skill adds `specs/` to the ignore list of that clone, in a file that
git does not track, so no skill commits or pushes it. A prototype goes outside the
repository, or the skill deletes it after you look. The build starts only when you ask.

## Requirements

Git.

Copyright © 2026 Lorenzo Mazzarotto
