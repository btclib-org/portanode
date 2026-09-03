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
    macos_list=$(git ls-files 'macos/scripts/**' \
      | sed -E 's,^macos/scripts/,,; s,\.(command|sh)$,,' | sort -u)
    win_list=$(git ls-files 'win/scripts/**' \
      | sed -E 's,^win/scripts/,,; s,\.(bat|ps1)$,,' | sort -u)
    linux_list=$(git ls-files 'linux/scripts/**' \
      | sed -E 's,^linux/scripts/,,; s,\.sh$,,' | sort -u)
    diff <(echo "$macos_list") <(echo "$win_list")
    diff <(echo "$macos_list") <(echo "$linux_list")
    ```

- **The shared code is platform-nameless, in `shared/`.** `shared/lib.sh`
  resolves the root and `shared/utilities/lib.sh` carries the download
  and PGP helpers; `win/scripts/utilities/lib.bat` is the Windows half of
  the second, `.bat` and `.ps1` being genuinely different languages from
  `bash` where the shared library is not. `macos/scripts/lib.sh` and
  `macos/scripts/utilities/lib.sh` still exist, each a forwarder to the
  file of the same name under `shared/` — kept at their old paths
  because `Bitcoin-Launcher.command`, `Electrum-Launcher.command` and
  `Utilities-Launcher.command` source the first by that path, every
  script under `macos/scripts/utilities/` sources one or the other of
  the two, and a forwarder keeps the relative-path arithmetic into
  `shared/` in one file per platform instead of in every caller that
  reaches it through this one. `linux/scripts/lib.sh` and
  `linux/scripts/utilities/lib.sh` forward the same way, for the same
  reason: every script under `linux/scripts/bitcoin/`,
  `linux/scripts/electrum/` and `linux/scripts/utilities/` sources one
  of the two directly, rather than doing that arithmetic itself,
  copying the helpers, or sourcing across into `macos/`. The two do not
  chain into each other: `linux/scripts/utilities/lib.sh` reaches
  `resolve_root` through `shared/utilities/lib.sh`'s own source of
  `shared/lib.sh`, never through `linux/scripts/lib.sh`, so a caller
  that only needs the download/PGP/checksum helpers sources
  `linux/scripts/utilities/lib.sh` alone rather than sourcing both. A
  launcher sources one rather than repeating it.
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
- **A launcher runs the folder's own client; a utility that only reports
  may borrow another.** A launcher reaches Bitcoin Core or Electrum by a
  path under the platform's `bin/` and tests it before using it, so a
  folder short of that binary stops at the launcher's own message rather
  than later at the shell's, or at a copy the machine has installed. The
  `-cli` launchers test `bitcoin-cli` for the reason they test
  `bitcoind`: the `btc` shortcut they hand the reader runs it.
  `utilities/health-check` is outside the rule, its subject being the
  folder's datadir rather than the folder's binaries, so it may query
  that datadir through whichever client it finds.

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
git fetch origin && git merge --ff-only origin/main
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

An issue of `btclib-org/.github`'s tracker worked in `btclib` by a coder
names its worktree `wt-github-255-btclib-coder`. No `uv sync` follows
the `cd` — there is no project here — and the editing, the gates and the
commits all happen in the worktree before the push.

```shell
WT=<scratchpad>/wt-<tracker>-<issue>-<repo>-<role>
git worktree add "$WT" origin/main -b <branch>
cd "$WT"
git push origin HEAD:refs/heads/<branch>
```

`-b <branch>` sits after the path and the commit-ish so that the
placeholder ends the command, which is section 9 of the organization
standard's rule. With the placeholder ahead of `"$WT"` the `>` closing
it takes that path as its target, and a path with no directory at it is
a file the paste creates.

Removing the worktree is part of finishing, and it stands in a block of
its own: the block above ends in a placeholder, and a shell that
discards that line as a parse error reads the next as a fresh command —
which, in one block, is this line against whatever `$WT` already held.

```shell
git worktree remove --force "$WT"
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
- **`blinter`'s exit code is not the gate's signal, and neither is a rule
  code's count across the whole tree.** `.pre-commit-config.yaml`'s own
  header says it is run by hand and does not gate; `uvx blinter . --no-config
  --summary` still exits non-zero against an unmodified tree:

    ```shell
    git archive origin/main | tar -x -C <tmpdir> && cd <tmpdir>
    uvx blinter . --no-config --summary; echo $?
    ```

    So a session reading only that exit code cannot tell its own red from
    the tree's. What a diff is judged on is the findings its own changed
    lines produce, read by file, by rule code, and by the set of line
    numbers each group's own `Line N, M:` header carries — not the exit
    code, and not a rule code's count, because the same code fires
    independently elsewhere: a file can carry two unrelated findings
    under one code, one on a line a diff removes and one that stays, and
    the code's count in that file is then identical before and after
    even though the diff's own finding is gone. A count of the header's
    own line numbers is not the key either, for the same reason: it is
    that same rejected quantity under another name, so a fixed instance
    paired with a different, newly introduced instance of the same code
    still reads as no change, and `Context:` offers no help where its
    text is the same generic phrase for both, as it is for a
    delayed-expansion finding. The line numbers themselves still show
    that swap, and show it even where blinter's own dedup — one
    `Context:` per (file, code) group when every instance in it shares
    one string — has collapsed two same-shaped instances to a single
    line. What this key does not clear is a pure shift: an unrelated
    edit earlier in the file that moves every later finding down by the
    same offset changes the set with nothing in the group itself gained
    or lost, which costs one extra look at the diff rather than a
    missed defect.
- **The `was read using 'utf_8' encoding` block is on stderr, and it is
  dropped rather than compared.** Which files it names moves under an
  ASCII-only edit to an unrelated part of them, so a comparison that
  keeps the block opens on a difference the diff did not make. The
  report itself is on stdout, so sending stderr away drops the block and
  leaves the report whole; a pipe alone does not reach it, and a run
  that merges the two streams has to filter the lines back out.

    ```shell
    uvx blinter . --no-config --summary 2>/dev/null
    ```

    `blinter/io/encoding.py` asks `charset_normalizer` for the file's
    encoding and keeps that answer only where its `coherence` is above
    `0.7`, then decodes with the name it kept and reports that name. The
    guard meant to suppress the warning for a file already read as UTF-8
    or ASCII compares that name against `utf-8`, `utf-8-sig` and
    `ascii`, spelled with hyphens, while `charset_normalizer` answers
    `utf_8` with an underscore — a spelling Python accepts as an alias
    for the codec and the guard does not accept as a match — so a file
    holding no byte above 127 is named, and converting it to UTF-8 as
    the warning advises is a no-op on it. What an edit moves is the
    coherence, and the `0.7` gate reads it before the guard is reached
    at all: below the gate the answer is discarded, the file decodes as
    hyphenated `utf-8`, and the guard matches that — which is what
    spares a file here rather than the guard's own `ascii` arm, every
    `.bat` measured that `charset_normalizer` named `ascii` having
    scored `0.0`, already below the gate. Coherence is derived from the
    decoded text rather than from its bytes, so ASCII lines can move it;
    they do not always, and where they do the move depends on where in
    the file they go — one file stayed at `ascii` under the same block
    prepended, appended and inserted mid-file, where another crossed the
    gate downward.
- **`ROOTDIR` is resolved, never assumed.** Every script derives it from
  its own location or from `PORTANODE_ROOT`, because the folder is
  mounted at a different point on every machine it is plugged into.
- **`resolve_root` fails silently, not loudly.** `shared/lib.sh` walks
  upward from `start_dir` looking for a directory holding `VERSION` plus
  a platform directory, and where the walk finds none it returns
  `start_dir` itself rather than an error — so a caller whose probe never
  finds a real root is handed back a directory as plausible as one that
  was found, and every path built on it afterwards is wrong the same
  way. This is what makes the loop's own probe — `VERSION` plus *any
  one* of `macos/`, `win/` or `linux/`, rather than all three — a real
  decision and not a cosmetic one: read the comment beside the loop
  before loosening or tightening it, since either changes how often a
  caller ends up at the fallback above instead of at a real root.
- **The executable bit is set on what macOS and Linux run, and on
  nothing else**, which is the rule and not a description of today's
  tree:

    ```shell
    git ls-files -s | awk '$1 == "100755" { print $4 }'
    ```

    answers with the `.command` and `.sh` launchers, at the root and
    under `macos/scripts/` and `linux/scripts/`, and with nothing else.
    The root `.sh` launchers are Linux's own entry point too —
    dispatching or refusing by `uname -s`, not macOS-exclusive — so
    they earn the bit on both platforms' terms rather than only
    macOS's; `linux/scripts/`'s own `.sh` files get the same bit for
    the same reason macOS's do, a shell reading the file directly. The
    `.bat` and `.ps1` halves stay 100644 because Windows does not read
    a POSIX mode, and every `lib.sh` — those under `shared/` and each
    platform's forwarders into them alike — is sourced rather than run;
    an executable bit on any of them would say a thing about the file
    that running it does not bear out. A new
    `.command` left non-executable does nothing when it is
    double-clicked in Finder, which is the way it is meant to be run.

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

- **Linux's own exFAT driver does not synthesise a mode the way macOS's
  does: it computes one from the mount's `fmask`, and omitting `fmask`
  does not mean no mask at all.** Measured on GitHub Actions
  `ubuntu-latest` (kernel `6.17.0-1022-azure`, the in-kernel `exfat`
  module installed from `linux-modules-extra-$(uname -r)`, the image
  built with `exfatprogs` 1.2.2), mounting directly with `mount -t
  exfat` rather than through a desktop's own `udisks2` automount policy —

    ```shell
    truncate -s 32M /tmp/t.img
    mkfs.exfat /tmp/t.img
    sudo mount -t exfat -o loop /tmp/t.img /tmp/t-default
    printf '#!/bin/bash\necho hi\n' | sudo tee /tmp/t-default/u.sh
    sudo chmod 644 /tmp/t-default/u.sh
    ls -l /tmp/t-default/u.sh && /tmp/t-default/u.sh
    ```

    — mounts with `fmask=0022,dmask=0022` though neither was named on
    the command line, which is the driver's own default rather than an
    absence of one; `chmod 644` changes nothing, and the mode reads
    `-rwxr-xr-x` (`0777 & ~0022`), and the script runs, exit 0. The same
    image mounted `-o fmask=133` instead reads `-rw-r--r--`
    (`0777 & ~0133`), and the script fails with `Permission denied`,
    exit 126. So a script on a plain, unconfigured mount runs the way
    macOS's synthesis makes it run, but by a mount option rather than
    unconditionally — raising `fmask` past `022` is an escape hatch out
    of that guarantee that macOS has none of. What a desktop's own
    `udisks2` automount passes for `fmask` was not measured here.

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
- **A path is relative to `ROOTDIR` where the launcher itself consumes
  it, and absolute where it is printed for use outside that process.**
  The use decides, not the form and not the length. A path passed as an
  argument is one the launcher consumes. A message interpolating a
  variable built as `$ROOTDIR/...` names an absolute path as surely as a
  literal one does. Printed for use outside covers a reader orienting
  themselves on the machine in front of them and a command pasted into a
  shell alike: `$ROOTDIR` alone, the resolved locations a Bitcoin
  launcher's opening block reports, a message whose subject is how long a
  path is — which rendered relative would name one short enough to fit
  whatever refused it — and the command an Electrum launcher prints in
  place of its own. That last is where the ground shows plainly: rendered
  relative the line does not orient a reader worse, it does not run. The
  absolute form costs a line that holds only on the machine that printed
  it, the folder mounting somewhere else on the next one, so a reader
  pasting one into a bug report hands over a path nobody else has. A path
  outside the folder entirely — a system binary, a user's keyring — is
  outside the rule rather than an exception to it.
- **Never state how many of anything a file holds.** A stated count is a
  line every open branch has to edit, and nothing here checks one.
- **The version is a date**: `VERSION` holds `YYYY.MM.DD` and a release
  tag is that string with a `v` in front. `RELEASING.md` is the
  procedure.
- **A pull request that closes an issue names it in its title, in
  parentheses**; one that closes nothing carries no parentheses. The
  title becomes the landing commit's subject, `squash_merge_commit_title`
  being `COMMIT_OR_PR_TITLE`.
- **A commit subject is one physical line, however long.** The
  eighty-column wrap above is for files in the tree, and applying it to a
  subject is what produces a wrapped one. `%s` conceals the result: it
  takes everything up to the first blank line and joins it, so `%s`
  itself, `git log --oneline` and any `grep` over either report a whole
  sentence where the subject is broken. The squash does not join — it
  takes the first physical line, appends `(#N)` and moves the remainder
  into the body. The read that shows the subject as it will land is the
  first line of `%B`:

    ```shell
    git show -s --format=%B <sha> | head -1
    ```

## How to verify

The lint gate, and what it does not reach, are `CONTRIBUTING.md`'s last
section. Nothing here runs a launcher, so a change to one is verified by
running it — on the platform it is for, from a volume that is not the
boot disk — and a session that could not do that says so rather than
leaving it to be assumed.

"Could not do that" is narrower than it reads: the mechanism belongs to
GitHub Actions, not to any one runner it offers. A workflow using
`on: push` runs from whatever branch carries it rather than needing to
sit on the default branch first — that requirement is
`workflow_dispatch`'s alone — so a scratch branch holding a throwaway
workflow file produces a real run on `ubuntu-latest`, `windows-latest`,
or any other label it offers, without that workflow ever landing on
`main`. `gh run list` and `gh run view --log` retrieve the output, and
deleting the branch afterwards (`git push origin --delete <branch>`) is
a remote ref, not a file, so it leaves nothing behind to clean up.

What such a run cannot establish is a property of the runner it lands
on, not of GitHub Actions itself. Neither `ubuntu-latest` nor
`windows-latest` carries a desktop session, so a `.desktop` file's trust
behaviour in a file manager is out of reach on the first and a GUI
launcher's own double-click through Explorer is out of reach on the
second, for the same underlying reason. exFAT-on-a-removable-drive
behaviour is only reachable through a loopback image, on any runner,
which is not the same thing as a drive plugged into a running machine.
