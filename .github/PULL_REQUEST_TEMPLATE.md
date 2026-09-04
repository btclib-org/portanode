<!-- markdownlint-disable-next-line first-line-heading -->
## What this changes

<!-- What the code does now that it did not do before, and why.
     Link the issue it closes, if there is one: "Closes #123". -->

## How it was verified

<!-- The command you ran and what it answered. There is no suite here:
     what stands in for one is running the launcher on a macOS, a
     Windows and a Linux machine, from a volume that is not the boot
     disk, which is the case the launcher's own paths exist for. -->

## Checks

<!-- CI runs all of this and rejects the pull request if any of it fails:
     the point of running it locally is not to wait for CI to say so. -->

- [ ] the lint gate is clean: `uvx pre-commit run --all-files`
- [ ] `CHANGELOG.md` has an entry, if a user would notice the change;
      `RELEASE_NOTES.md` too, if it is one a user has to act on
- [ ] every commit carries a verified signature

## Anything the reviewer should know

<!-- A decision you are unsure of, an alternative you rejected, a
     specification that is ambiguous, a follow-up you left out on
     purpose. Delete the section if there is none. -->
