# prove

"Done, and all tests pass" is a claim. The session that wrote the code believes its own work,
and a second look by the same session agrees with the first.

This checks a finished change against its spec, with a reviewer that never saw the build. You
get one line for each requirement: pass or fail, with the evidence.

## What happens

* It finds the spec, or writes the requirements from your request and shows them to you.
* It runs the checks of the project, uses the app as a user does, and saves the output.
* It asks you about each place where the build left the spec, before it pays for a review.
* It starts a reviewer in a fresh context with the spec, the output, and the diff only.
* It fixes each failure in the code, and checks again, for three reviews at most.
* It reports each requirement with its evidence, each file that changed, and what you must
  check yourself.

## Safety

The reviewer reports and does not edit. A fix changes the code, and not a requirement or a
test that is there. A check that did not run is reported as not checked, and never as a pass.
Findings about style are left out, because to fix each finding adds code that nobody needs.
It does not commit.

## Sources

The method comes from these Anthropic publications:

* [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)
* [Harness design for long-running application development](https://www.anthropic.com/research/harness-design-long-running-apps)
* [Effective harnesses for long-running agents](https://www.anthropic.com/research/effective-harnesses-for-long-running-agents)
* [The AI-native SDLC playbook](https://claude.com/resources/articles/the-ai-native-sdlc-playbook)
* [Building verification loops in Claude Code with skills](https://claude.com/resources/articles/building-verification-loops-in-claude-code-with-skills)
* [Loop engineering: Getting started with loops](https://claude.com/resources/articles/getting-started-with-loops)
* [When to use multi-agent systems](https://claude.com/resources/articles/building-multi-agent-systems-when-and-how-to-use-them)
* [Multiagent systems](https://www.anthropic.com/research/multiagent-systems)
* [Redesigning source control at Anthropic](https://www.anthropic.com/research/redesigning-source-control)
* [Prompting Claude Fable 5.2](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-2)

## Requirements

Git. A spec from the `specify` skill gives the best result, but any written list of
requirements works.

Copyright © 2026 Lorenzo Mazzarotto
