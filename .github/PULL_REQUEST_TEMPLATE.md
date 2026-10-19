<!-- markdownlint-disable-next-line first-line-heading -->
## What this changes

<!-- What the code does now that it did not do before, and why.
     Link the issue it closes, if there is one: "Closes #123". -->

## How it was verified

<!-- The command you ran and what it answered. tests.yml runs the suite
     under tests/, and CONTRIBUTING.md's last section names the tests
     still run by hand. None of them starts what a launcher launches: a
     change to that is verified by running the launcher on a macOS, a
     Windows and a Linux machine, from a volume that is not the boot
     disk. -->

## Checks

<!-- CI runs all of this and rejects the pull request if any of it fails:
     the point of running it locally is not to wait for CI to say so. -->

- [ ] the lint gate is clean: `uvx pre-commit run --all-files`

## Anything the reviewer should know

<!-- A decision you are unsure of, an alternative you rejected, a
     specification that is ambiguous, a follow-up you left out on
     purpose. Delete the section if there is none. -->
