# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

There is no project here. What this repository ships is launchers — one
per network and per platform — that start somebody else's binaries from a
folder that is not the boot disk. `README.md` is what a user reads,
`CONTRIBUTING.md`'s last section is the environment and the gates, and
`REPOSITORY.md` is the settings that live outside the tree.

## What is in the tree, and what is not

- **The binaries are not.** `macos/bin/.gitignore` and
  `win/bin/.gitignore` name Bitcoin Core's and Electrum's executables one
  by one, and the update scripts are what put them there. So a fresh
  clone launches nothing until `update-bitcoin` and `update-electrum`
  have run, and a launcher failing with "binary not found" on a clean
  checkout is the tree working as designed.
- **Neither is the chain data.** `bitcoin-datadir/` and
  `electrum-datadir/` are tracked for their configuration and their
  `README.md`; blocks, chainstate, wallets and logs are ignored.
- **The same launcher is written four ways.** `.sh` for a shell,
  `.command` for a double-click in Finder, `.bat` for cmd.exe and `.ps1`
  for PowerShell. Nothing generates one from another and nothing checks
  that they agree, so a change to one is a change owed to the others —
  where the other exists, which is not everywhere:

    ```shell
    diff <(git ls-files 'macos/scripts/**' \
            | sed -E 's,^macos/scripts/,,; s,\.(command|sh)$,,' | sort -u) \
         <(git ls-files 'win/scripts/**' \
            | sed -E 's,^win/scripts/,,; s,\.(bat|ps1)$,,' | sort -u)
    ```

- **The shared code is in `lib`.** `macos/scripts/lib.sh` resolves the
  root, `macos/scripts/utilities/lib.sh` carries the download and PGP
  helpers, and `win/scripts/utilities/lib.bat` is the Windows half of the
  second. A launcher sources one rather than repeating it.
- **`keys/*.fingerprints` decide what an update will install.**
  `electrum.fingerprints` pins one key, so an Electrum download signed by
  anything else is refused; `bitcoin-core.fingerprints` pins none, Core's
  `SHA256SUMS` being signed by many independent builders, and with no
  fingerprint listed the updater still requires one good signature from a
  key already in the keyring. Both files carry the reasoning in their own
  comments; a diff that empties either one weakens an install path
  without touching a script.
- **`*/checksums.sha256` is append-only**, and records integrity rather
  than authenticity: it detects a binary that changed under you, where
  the PGP step above is what says the binary was the publisher's. An
  entry is added after a verified install and never rewritten.

## The primary checkout is the maintainer's

**Never work in it.** No edit, no `git add`, no commit, no branch switch,
no rebase, no `git stash` — the hooks fix files in place. It is a local
reference only, and it stays on `main`.

Reading it is fine, but `git fetch` moves `refs/remotes/origin/main` and
leaves the work tree where it was, so a `grep` or a `Read` against the
checkout answers for whenever it was last brought forward, not for now.
The read that cannot go stale is `git show origin/main:<path>`: it
answers from the ref `git fetch` just moved, never from the tree. For a
path git filters on checkout — `.bat` here — it is current without being
faithful, and the bullet on those below names the read that is both.

Where the checkout has to be current rather than merely readable, a
fast-forward of a clean `main` brings it up:

```shell
git fetch origin && git merge --ff-only origin/main   # clean main only
```

That writes no commit, switches no branch and runs no hook, so it is on
the permitted side of *never work in it*, not an exception to it. Stop
if the checkout is not on `main` or is not clean: that is no longer
bringing it forward.

**Every session works in a worktree**, its own, from the first edit,
named `wt-<tracker>-<issue>-<repo>-<role>` rather than after the issue
alone. `tracker` is the repository whose issue tracker holds the issue:
an issue number is unique only within one tracker, so
`btclib-org/.github#45` and `btclib-org/btclib#45` are different issues
that would otherwise name the same worktree. `issue` is what prevents
the collision that has actually happened — two worktrees of different
work sharing a generic basename in one repository's own `.git`, keyed on
its path's basename. `repo` prevents a different collision, a *path*
one rather than a `.git` one: two repositories each keep their own
`.git/worktrees/<basename>` and cannot collide there, but the workers of
one session share one scratchpad directory, so a session carrying one
issue into several repositories computes the same target path for each
of them, and `git worktree add` refuses a directory that already
exists — or worse, a second worker reads the first one's tree; naming it
this way also sorts every worktree of one issue together. `role` covers
the narrower case of a coder and its reviewer holding a worktree at
once, which the ordinary sequence avoids by each removing its own.

```shell
WT=<scratchpad>/wt-<tracker>-<issue>-<repo>-<role>  # wt-github-255-btclib-coder
git worktree add -b <branch> "$WT" origin/main
cd "$WT"                              # no uv sync: there is no project
# edit, gate and commit here, then
git push origin HEAD:refs/heads/<branch>
git worktree remove --force "$WT"     # removing it is part of finishing
```

**Never `git stash` in a worktree either: `refs/stash` is shared.** A
worktree isolates files, not refs, so `git stash push` pushes onto the
same stack every other session pops from. Commit to your own branch
instead.

**Do not rewrite `refs/heads/main`, or advance it with work that is not
yours.** Your own branch is what you push, and the pull request is what
moves `main`.

## What will otherwise waste a session

- **There is no `pyproject.toml`**, so the tool configuration that lives
  in one elsewhere lives in files of its own: `.typos.toml` for typos,
  `.taplo.toml`, `.yamllint.yaml`, `.markdownlint.jsonc`. codespell's two
  exceptions are hook arguments instead, that tool taking a flag where
  typos takes none, and `.pre-commit-config.yaml` says so beside them.
- **There is no `.python-version` either**, and that is a decision rather
  than an omission — the organization's standard leaves the file to each
  repository. `git ls-files '*.py'` is empty here, so the only Python is
  the interpreter `uvx pre-commit` builds a hook environment with, and
  pinning one would be a version number nothing in this tree reads and
  no gate re-derives. What it would buy is the hook environments being
  the same interpreter on every machine; what it costs is a line that
  ages on its own. Add it the day a hook is sensitive to which
  interpreter ran it.
- **`.bat` files are CRLF in the working tree and LF in the index**,
  `.gitattributes` declaring `text eol=crlf`. A tool that normalizes one
  leaves `git diff` empty and the checkout wrong, which is why the
  line-ending hook excludes them and why `REVIEWING.md` carries a command
  that reads the file rather than the diff. It is also why
  `git show origin/main:<path>` is the wrong read for one of these: it
  hands back the blob, so a `.bat` arrives LF and any line-ending
  measurement taken from it describes the extraction rather than the
  file. `git cat-file blob` and the contents API answer LF for the same
  reason. `git archive` applies the attribute, so it is the read that is
  both current and faithful:

    ```shell
    git archive origin/main -- <path> | tar -xO
    ```

    Measured against a checkout of the same commit, that returns the
    file's carriage returns where the reads above return none — which is
    how a batch linter came to report a tracked `.bat` as LF-only, from
    a file that is CRLF everywhere it is actually read.
- **PowerShell for the `.ps1` half is installable, not merely
  referenced.** `CONTRIBUTING.md` names
  `pwsh -Command 'Invoke-ScriptAnalyzer -Path . -Recurse'` as what stands
  in for a `.ps1` gate, but not how to get `pwsh` itself on a machine
  that lacks it: `brew install powershell` on macOS gets PowerShell
  7.6.5, letting
  `[System.Management.Automation.Language.Parser]::ParseFile` and
  PSScriptAnalyzer both run for real — a positive control against the
  unmodified tree first, then a clean run against the fix — rather than
  a `.ps1` change being read for correctness without ever being parsed.
  `Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser` once
  `pwsh` is there.
- **`ROOTDIR` is resolved, never assumed.** Every script derives it from
  its own location or from `PORTANODE_ROOT`, because the folder is
  mounted at a different point on every machine it is plugged into.
- **The executable bit is set on what macOS runs and on nothing else**,
  which is the rule and not a description of today's tree:

    ```shell
    git ls-files -s | awk '$1 == "100755" { print $4 }'
    ```

    answers with the `.command` and `.sh` launchers, at the root and
    under `macos/scripts/`, and with nothing else. The `.bat` and `.ps1`
    halves stay 100644 because Windows does not read a POSIX mode, and
    the two `lib.sh` are sourced rather than run — an executable bit on
    either would say a thing about the file that running it does not
    bear out. A new `.command` left non-executable does nothing when it
    is double-clicked in Finder, which is the way it is meant to be run.

- **The bit decides nothing on the volume this is built for.** macOS
  synthesises a mode for exFAT rather than storing one: a file written
  there reads `rwx------` whatever `chmod` was asked for, and a script
  runs regardless. Measured on an exFAT image —

    ```shell
    hdiutil create -size 20m -fs ExFAT -volname T -o /tmp/t.dmg
    hdiutil attach /tmp/t.dmg
    printf '#!/bin/bash\necho hi\n' > /Volumes/T/u.sh
    chmod 644 /Volumes/T/u.sh && ls -l /Volumes/T/u.sh && /Volumes/T/u.sh
    ```

    — which exits 0 and prints `hi` under `-rwx------`. So what the mode
    in the index is for is the other cases: a clone or an unpacked source
    archive on APFS, where GitHub's zipball carries the index mode
    through `unzip` unchanged.

## Model

The default model for this repository is Sonnet. Switch to Opus only for
a change to what a launcher decides — a verification path, a rollback, a
choice two platforms have to make the same way. Use `/model opus` for the
session, then switch back.

Do not use Fable unless explicitly instructed.

## Conventions to match

- **The prose style is `CONTRIBUTING.md`'s "Documentation and comments"
  section**: neutral, factual, dry; a comment carries the reasoning
  *including the negative result*; measure rather than assert; one fact
  in one place; no history in the prose.
- **Markdown wraps at 80 columns**, tables included (MD013 is on), so
  long commands go in fenced blocks split with `\`.
- **A path is relative to `ROOTDIR`, never absolute.** The one exception
  is a path outside the folder entirely — a system binary, a user's
  keyring — and there is no exception for anything the folder carries.
- **Never state how many of anything a file holds.** A stated count is a
  line every open branch has to edit, and nothing here checks one.
- **The version is a date**: `VERSION` holds `YYYY.MM.DD` and a release
  tag is that string with a `v` in front. `RELEASING.md` is the
  procedure.
- **A pull request that closes an issue names it in its title, in
  parentheses**; one that closes nothing carries no parentheses. The
  title becomes the landing commit's subject, `squash_merge_commit_title`
  being `COMMIT_OR_PR_TITLE`.

## How to verify

The lint gate, and what it does not reach, are `CONTRIBUTING.md`'s last
section. Nothing here runs a launcher, so a change to one is verified by
running it — on the platform it is for, from a volume that is not the
boot disk — and a session that could not do that says so rather than
leaving it to be assumed.
