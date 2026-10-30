<!-- markdownlint-disable-next-line first-line-heading -->
## What this changes

<!-- What the code does now that it did not do before, and why.
     Link the issue it closes, if there is one: "Closes #123". -->

## How it was verified

<!-- The command you ran and what it answered. test.yml runs the suite
     under tests/ on Ubuntu, and CONTRIBUTING.md's last section says when
     its macOS and Windows halves run. No test starts what a launcher
     launches: a change to that is verified by running the launcher on a
     macOS, a Windows and a Linux machine, from a volume that is not the
     boot disk. -->

## Checks

<!-- CI runs the gate below, as CONTRIBUTING.md gives it, and rejects the
     pull request if it fails: the point of running it locally is not to
     wait for CI to say so. -->

- [ ] the lint gate is clean: `uvx pre-commit run --all-files`
- [ ] I have read and understood every line of this change, and can
      answer a review of it without the model

## Anything the reviewer should know

<!-- A decision you are unsure of, an alternative you rejected, a
     specification that is ambiguous, a follow-up you left out on
     purpose. Delete the section if there is none. -->
