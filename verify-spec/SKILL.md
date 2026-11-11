---
name: verify-spec
description: Verifies a finished change against its spec in a fresh context, and reports each requirement as pass or fail with the evidence. Use when asked to verify, check, or prove that a change does what was asked, or before work that was built from a spec is reported as done. Not for a small change, where the build and the tests are enough.
---

# Verify Spec

## Goal

Show me, for each requirement, the evidence that the change does what the spec says. A
statement of done from the session that wrote the code is not evidence.

## Quick start

Do the sections in order. First find the criteria and the change:

```bash
ls -t specs 2>/dev/null | head -5
B=$(git merge-base HEAD origin/HEAD 2>/dev/null || echo HEAD)
git status --short && git diff --stat "$B"
```

* **DO** use the spec that I name, or the spec in `specs/` that this change was built from; ask
  me when two specs fit
* **DO** write the requirements from my request as a numbered list in a temporary file when
  there is no spec, and show that list in the report as criteria that you assumed
* **DO** check that the diff holds the full change, the commits of the branch and the files
  that are not committed; name the base yourself when `origin/HEAD` is not set
* **DO** stop and ask me when the spec and the change are about different work

## How to collect the evidence

Run the checks that the project has, and each line under Check in the spec, and save the
literal output in a temporary file. Leave out a check that the project does not have:

```text
build   the result line, with each error and each new warning
tests   the numbers that passed and failed, and the result of each test for an edge case
lint    the result line
app     for each action under Check: what you did, and what you saw
```

* **DO** follow `CLAUDE.md` and the project for how to build, test, lint, and run the app
* **DO** use the changed behaviour in the running app as a user does, when the project has a
  way to run it; a build that succeeds and tests that pass do not show that a screen works
* **DO** call the changed behaviour from a small program outside the repository, when the
  project is a library with no app to run
* **DO** write `NOT CHECKED` with the reason when you cannot run a check here, such as a check
  that needs a device; a check that did not run is not a pass
* **DO** save what you did and the output, and not your summary or the result that you
  expected; the reviewer reads this file, and an expected value gives it your reading of the
  spec

## How to get an independent review

Start a subagent that did not write the code, and give it this brief with the paths filled in:

```text
You review a change that you did not write. Report only: do not edit a file in the
repository, and put each file that you make outside it.
Repository: <path>. Spec: <path>. Evidence: <path>.
Change: `git diff <base>`, and the untracked files in `git status --short`.
For each numbered requirement, find the code that implements it, and give PASS, FAIL, or
NOT CHECKED with the evidence: the file and line, a command and its output, or what the
evidence file shows for the running app.
For each edge case, name the test that covers it, and give its result.
Look for a stub: a fixed return value, an empty handler, or a branch that the spec needs and
the code does not have.
Report only a gap that affects correctness. Skip style.
Keep each real problem at its severity. Do not decide that it is acceptable.
```

* **DO** ask me, before you start the review, about each line under Deviations that goes
  against a requirement, and show me what the evidence says about it; when I accept it, change
  the requirement in the spec to match, and when I reject it, change the code. A review costs
  much more than a question, and my answer decides what it checks
* **DO** give the reviewer the spec, the evidence, and the diff only; a reviewer that reads the
  main conversation or your reasoning repeats your assumptions
* **DO** check that each `PASS` from the reviewer names its evidence; agreement between two
  instances of the same model is not proof
* **DO** do the review yourself when you cannot start a subagent, and say in the report that
  the review was not independent

## How to fix a failure

* **DO** fix the code for each `FAIL`, and add each test that is missing; do not change a
  requirement, or a test that is there, to get a pass
* **DO** stop and ask me when you think that the spec is wrong, or when a requirement has two
  readings and the code satisfies only one; I decide if the spec or the code changes
* **DO** collect the evidence again after each fix, and get the review again when the fix
  changed code, because a fix can break a requirement that passed; a fix that only adds a test
  needs the test run and not a review
* **DO** stop after the third review and report what still fails; a failure that survives
  two fixes needs a decision from me
* **DO NOT** change code for a finding that does not affect correctness; to fix each finding
  of a reviewer adds layers, and tests for cases that cannot occur

## How to report

```text
# | Requirement | Verdict | Evidence
1 | The session survives a restart | PASS | SessionTests.testRestore passed; home screen after relaunch
2 | An expired token shows sign-in | FAIL | AuthStore.swift:88 has no branch for expiry; no test
3 | Sync works on a mobile network | NOT CHECKED | Needs a device: turn Wi-Fi off, then open the list
```

* **DO** give each requirement and each edge case one line, also the ones that pass
* **DO** quote the output line, or name the file and line, as the evidence; "the tests pass"
  alone is not evidence
* **DO** list each file that the change touches, the small changes also, and each line under
  Deviations in the spec; I review the diff from this list, and a summary leaves the small
  changes out
* **DO** end with what I must check myself, and with each finding of the reviewer that you
  did not fix and the reason
* **DO NOT** commit; the `open-pr` skill does that when I ask

## Reference

| Verdict | Use it when |
| --- | --- |
| `PASS` | The output of a command, or what you saw in the running app, shows the behaviour |
| `FAIL` | The behaviour is absent, wrong, or a stub, or an edge case has no test |
| `NOT CHECKED` | You had no way to observe it here; say what I must do to check it |

Copyright © 2026 Lorenzo Mazzarotto
