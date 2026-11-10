# specify

A short request leaves the important decisions open. The model then makes them with defaults
that can be wrong for your app, and you find out after the build.

This finds those decisions before any code exists. It reads your code, shows you what is not
decided, asks you one question at a time, and writes a spec that says what done means.

## What happens

* It reads the request against the code, and finds a file that already does a similar thing.
* It lists the decisions that the work forces, with the ones you did not know about.
* It asks one question at a time, with choices, and the questions that change the most first.
* It writes `specs/<topic>.md`: numbered requirements, edge cases, what is out of scope, and
  exact checks.
* It stops, and gives you a prompt to start the build in a new session.

## Safety

It writes one file, and each piece of work gets its own. It keeps `specs/` out of git for
that clone, so a spec is never committed or pushed. It does not start the build unless you
ask.

## Sources

The method comes from these Anthropic publications:

* [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)
* [A field guide to Claude Fable 5: Finding your unknowns](https://claude.com/resources/articles/a-field-guide-to-claude-fable-finding-your-unknowns)
* [The AI-native SDLC playbook](https://claude.com/resources/articles/the-ai-native-sdlc-playbook)
* [Harness design for long-running application development](https://www.anthropic.com/research/harness-design-long-running-apps)
* [Best practices for using Claude Opus 4.7 with Claude Code](https://claude.com/resources/articles/best-practices-for-using-claude-opus-4-7-with-claude-code)

## Requirements

Git.

Copyright © 2026 Lorenzo Mazzarotto
