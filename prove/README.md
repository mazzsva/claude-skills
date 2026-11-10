# prove

"Done, and all tests pass" is a claim, not evidence. Anthropic found that, when agents
evaluate their own work, they
"[tend to respond by confidently praising the work](https://www.anthropic.com/research/harness-design-long-running-apps)",
and that
"[it is easy to see tests pass and assume the job is done](https://www.anthropic.com/research/building-c-compiler)".
A second look by the same session repeats the same assumptions.

A reviewer that never saw the build checks a finished change against its spec, and each
requirement gets a pass or a fail, with evidence.

## How it works

* **Evidence comes first.** It runs the build, the tests, and each check in the spec, uses the
  app as a user does, and saves the literal output. A build that succeeds and tests that pass
  do not show that a screen works.
* **The reviewer has no history.** A new subagent gets the spec, the evidence, and the diff
  only. It never reads the conversation or the reasoning of the builder, so it cannot repeat
  the assumptions of the builder.
* **The reviewer looks for stubs.** A fixed return value, an empty handler, or a branch that
  the spec needs and the code does not have.
* **A pass needs proof.** Each `PASS` names an output line, or a file and a line. An edge case
  with no test is a `FAIL`. A check that did not run is `NOT CHECKED`, and never a pass.
* **A fix cannot cheat.** It changes the code. It never changes a requirement, or a test that
  is there, to get a pass.
* **The loop has a limit.** After the third review, it stops and reports what still fails. A
  failure that survives two fixes needs your decision.
* **Cost is part of the design.** In my tests, one review cost 50,000 to 77,000 tokens. So the
  skill asks you about each deviation from the spec before the review, skips the review after
  a fix that only adds a test, and makes no change for a finding about style.

## Safety

The reviewer reports and does not edit. The skill never commits. Without a subagent, the
report says the review was not independent.

## Requirements

Git. A spec from the [specify](../specify) skill gives the best result, but any written list
of requirements works.

Copyright © 2026 Lorenzo Mazzarotto
