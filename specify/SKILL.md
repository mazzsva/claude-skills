---
name: specify
description: Finds the decisions that a feature or a change leaves open, interviews me about them, and writes a spec with requirements that can be checked. Use when asked to specify, scope, or think through work before it is built, or when a request for large work leaves its main decisions open. Not for a change that one prompt describes in full.
---

# Specify

## Goal

Write a spec: the decisions that only I can make, and a definition of done that a new session
can build from and that the `prove` skill can check.

## Quick start

Do the sections in order. First read my request against the code:

```bash
git rev-parse --show-toplevel && git status --short --branch
ls specs 2>/dev/null
git check-ignore -q specs/x || echo 'specs/' >> "$(git rev-parse --git-path info/exclude)"
```

* **DO** run the third command; it adds `specs/` to the ignore list of this clone only, in a
  file that git does not track, so that the `propose` skill never commits or pushes a spec
* **DO** read the code that the request touches before the first question; a question that the
  repository answers costs me a turn
* **DO** find a file that already does a similar thing; it becomes the reference in the spec,
  because source code shows a pattern better than my words do
* **DO** ask me, in one question, what I know about this part of the code and what I decided
  already, when my request does not say; the next section depends on the answer

## How to find what is not decided

Before the interview, show me the decisions that this work forces and that my request does not
make, with the ones that I probably do not know about:

```text
Decision | Why it matters | Recommendation
```

* **DO** write the list for what I know, and explain each term that I did not use
* **DO** include what the code makes necessary and I did not mention, such as a migration of
  saved data, a second platform, or a screen with no data
* **DO NOT** list a choice of implementation that you can change later at no cost to me; that
  choice is yours

## How to interview me

Ask in this order, because an early answer changes the later questions:

```text
1. What changes the data model, an interface between two parts, or what the user sees
2. What is out of scope, and how complete the result must be
3. The edge cases, and what must occur in each one
4. How to prove that the work is done
```

* **DO** ask one question at a time, with two to four choices and your recommendation first
* **DO** ask about a decision only when a different answer changes the result for me, and
  skip a topic of the list that the code settles; give each other decision a default, and
  write that default in the spec as assumed
* **DO** offer a throwaway prototype with fake data, or three or four different directions,
  when I cannot describe the result but I would know it when I see it; put it outside the
  repository, or delete it after I look, because the `propose` skill commits each file that
  it finds
* **DO NOT** ask me how to build it; I decide what the result is, and you decide the path

## How to write the spec

```markdown
# <Feature>

Status: draft

## Goal
The problem, the result, and who or what it affects.

## Decisions
- <What I decided, with the choice that I am most likely to change first>
- <A default that I did not confirm> (assumed)

## Requirements
1. <A behaviour that a person or a test can observe>

## Edge cases
Each one needs a test.
- <Case>: <what must occur>

## Out of scope
- <What this work does not do>

## Constraints
- Reference: <a file that already does a similar thing>
- <A library, a pattern, or a behaviour that must not change>

## Check
- <Command>: <the output that means pass>
- <Action in the running app>: <what to see>

## Deviations
```

* **DO** write to `specs/<topic>.md`, with the topic in two to four words of kebab case, or to
  the path that I give; one file for each piece of work keeps two specs apart
* **DO** write each requirement as a behaviour that a person or a test can observe, not as a
  step of the implementation; a spec that fixes the path stops a better path that you find
  during the build
* **DO** number each requirement; the `prove` skill reports by number
* **DO** make each line under Check exact: a command with the output that means pass, or an
  action in the running app with what to see; leave the action out when the project has no app
  to run, and give no number of tests, because the `prove` skill finds the test for each edge
  case
* **DO** say how complete the result must be, such as the empty state and the error state; a
  request with no stated scope gets the smallest result that satisfies it
* **DO** keep the spec in proportion to the work, and on one page when the work permits; write
  an edge case only when its result does not follow from a requirement, and an assumed default
  only when a different default changes the result
* **DO** leave Deviations empty; the build writes there each place where it left the spec

## How to hand over

Show me the decisions, with the assumed ones marked. Correct the spec until I accept it, set
its status to `accepted`, and give me this prompt for a new session:

```text
Build specs/<topic>.md. When the code forces you to leave the spec, pick the conservative
option, write it under Deviations in the spec, and keep going. When the build is done, use
the prove skill.
```

* **DO** ask me each question that is still open before you set the status; a spec with an
  open question is not a definition of done
* **DO NOT** start the build in this session, unless I ask for it; a new session starts with a
  clean context and the written definition of done, without the turns of the interview

Copyright © 2026 Lorenzo Mazzarotto
