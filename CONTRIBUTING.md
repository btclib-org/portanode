# Contributing

What this repository holds in common with the others of the organization
— the toolchain, the lint gate, the tool tables behind it, the workflow
set and the branch rules — is stated once in the
[btclib-org repository standard](https://github.com/btclib-org/.github),
each rule with the alternative it was decided against. It binds this
repository, so a change departing from it is a divergence, and one filed
as an issue in that repository rather than here: a difference between two
repositories belongs to neither of them.

**This file is the same in every repository of the organization up to
its last section.** What is true of one tree only — the commands that
build its environment, the gates it runs, which of its workflows decide
a merge — is under that heading, and the comparison stops there.

How the organization decides, and who holds which role, is
[`GOVERNANCE.md`][governance]; what it intends to do, and what it
deliberately does not, is [`ROADMAP.md`][roadmap]. Both are the
organization's, one copy each beside the standard.

## The issue tracker

Where an issue is filed, and what an alignment finding has to name, is
[the standard's *What this repository is*][s-what]: an issue spanning
repositories, or whose subject is the standard, goes to
[btclib-org/.github](https://github.com/btclib-org/.github/issues), and
one about this tree alone stays here.

A finding noticed while doing something else goes where `REVIEWING.md`'s
*What is filed, and what is not* says, for an author as much as for a
reviewer: a pull request answering two questions cannot be accepted for
either.

An issue labelled `good first issue` is one set aside for a first
contribution: small and self-contained.
[One search][good-first] lists the open ones across the organization, so
a newcomer need not know in advance which repository to look in.

## Documentation and comments

[Section 9 of the standard][s9] is the prose style beyond *Write
plainly* below, and it governs the prose this tree ships — comments,
docstrings and markdown. It is not restated here: a second wording is
the one that goes stale, which is that section's own *One fact in one
place*.

A commit message is prose this tree ships too, though section 9 does not
say so: [the only merge method the rule accepts][s11] puts it on `main`
as the landing commit's body, so what is written in one is read there
long after the branch is gone.

## Working with an LLM

**Development here is LLM-based.** Most issues, code and reviews are
written by agentic sessions that the maintainer directs and reads.
Humans are welcome, as long as they are comfortable working that way.

**A contribution is yours, whoever wrote it.** Read every line before
you open the pull request, understand it, and be ready to answer a
review without the model. Text or code you have not read, or cannot
explain, is closed without review.

**Write plainly**, in the tree and on the forge: the point first, plain
words, one fact per sentence. On the forge, the title and the first
sentence carry the point; a body is at most two short paragraphs before
any code block or template section; a comment is about 200 words, and
never more than 250, with no list and no heading; a review's summary
takes the shape `REVIEWING.md`'s *The verdict* gives it.

## Pull requests

What `main` accepts, and what it refuses to everyone, is [section 11 of
the standard][s11]. Run the gates locally before opening anything —
the last section of this file says which they are — because CI runs
exactly them, so a red run there is a local run that was not done.

**Every commit of a pull request carries a `Signed-off-by:` trailer
naming its author**, which certifies the [Developer Certificate of
Origin][dco]. `git commit -s` adds it, and `git rebase --signoff <base>`
adds it to commits already made. The `Sign-off` check is required, so a
pull request whose commits lack the trailer cannot merge; its failure
prints the command that adds it. [The standard's *Signatures*][s-sigs]
says why a signature does not replace it, and which commits the
`Sign-off` job skips.

What a pull request's title and description have to say about the issues
it closes, and why a manual link in the Development panel is a trap
neither of them shows, is [the standard's *What a pull request says it
is*][s-title]. Read it before opening one; it is the rule most often
found broken after the fact.

**Before it is opened, the branch's own commit subjects and bodies are
read against that same rule.** The description does not exist yet to
disagree with them, and [the standard][s-title] has the command that
scans the branch's own commit text for a verb in front of a reference.

**The two spellings are named here as well as there, against [section 9's
*One fact in one place*][s9]**, the paragraph above naming the section
and not the forms, which are the half a citation is got wrong in:
`(closes #N)` cites an issue the change closes, wherever the citation
sits — the title, the commit subject where [*Merge method*][s11] makes
that the thing that lands — and `(issue #N)`
cites, in those same places, an issue the change advances and does *not*
close. One token holds one meaning whichever file it sits in, so the
pair is chosen by what is true of the change rather than by which file
is being written, and a tree's own landed subjects are not what to copy
it from: nothing already landed is rewritten, so what a repository wrote
before the rule stays where it is.

`REVIEWING.md` is the standard a review is written against, and is this
file's other half. Read before opening a pull request, it is what the
pull request will be answered against.

A pull request adds no entry to `CHANGELOG.md` or `RELEASE_NOTES.md`, a
release's own pull request excepted ([section 9][s9], [section 12][s12]).

### One subject, opened as soon as it is written

A pull request answers one question. Issues that share a subject are one
pull request, closing each of them; issues that do not are one pull
request each, however small either of them is.

It is opened the moment it is written and verified — not held for the
previous one to be reviewed or to land, and not batched with the next. A
batch arrives as one reviewing job with several subjects, which is the
shape that costs the most to read; a finished pull request held back is
review that could have started and did not.

Working this way stacks branches, which is fine and costs one rule: a
child whose base was amended is moved with the old base named,

```shell
git rebase --onto <new-base> <old-base-sha> <child>
```

because a plain rebase replays the base's old commit inside the child,
and the forge then shows the base's old text as additions with nothing
red anywhere. Read the child's diff afterwards rather than trusting the
rebase, and retarget each child onto `main` as its parent lands.

### The review

A review is given promptly and on local evidence. It does not wait for
CI, does not report a check as a finding, and does not discuss a run at
all: whether CI is green is the author's business, once, at landing time.

The exchange is anchored to a sha rather than to a branch, a branch being
free to move under a review:

- the author hands off by naming the sha pushed and the evidence run
  against it, then leaves that head alone;
- the reviewer answers with findings — where, what is wrong, how they
  know it, and whether each is blocking;
- the author accepts what is reasonable, declines the rest with a reason
  in the thread, pushes the answer without waiting for CI, and resolves
  each thread once answered;
- the reviewer reopens a thread whose finding is still blocking, and
  re-reviews the delta rather than the branch.

**What ends the loop is the ack of record**, and the author does not
supply their own. A reading that says what it found and delivers no
verdict is a review too and ends nothing; [the standard's *Review*][s-rev]
has which is which, and `REVIEWING.md` has how each is written. A
disagreement that survives a second exchange goes to the maintainer
instead of into a third round.

**The ack of record is not the approval *Landing it* asks for**: it is
a bot's review of type COMMENT ([the standard's *Review*][s-rev] says
whose).

### Landing it

CI is read once, and this is where: on the head that lands. `main` does
not ask that head to be up to date with it, and [section 11][s-branch]
says why. So a branch is rebased only where it conflicts with `main`. A
rebase that moved nothing but the base leaves the ack standing; one that
resolved a conflict does not, that resolution being a change no reviewer
has seen.

When `main`'s CI is red after a merge, its repair takes priority over
every other pull request, because until it lands `main`'s runs cannot
tell a new failure from the one already there. A pull request armed with
`--auto` (below) stays armed, and others keep landing meanwhile. Holding
every landing for a repair costs more than the break it guards against,
so the risk of landing on a red `main` is accepted
(btclib-org/.github#1777).

A pull request whose required check is red only because `main` was red
is closed and reopened once the repair lands (`gh pr close <n>`, then
`gh pr reopen <n>`). GitHub then runs its checks on a fresh merge with
the repaired `main`, where a re-run would test the old merge commit. No
push is made, so its approvals and its ack of record stand. `--auto`,
where closing dropped it, is armed again once the checks are green. The
reopen also runs the review bot again, and changes that review requests
are answered like any other review's.

Then squash, [the only method the rule accepts][s11].

**It lands once somebody other than its author has approved that
head**, through `gh pr merge` pinned to it:

```shell
gh pr merge <n> --squash --match-head-commit <the head the checks ran on>
```

With `--auto` added, GitHub runs the same merge once the approval and
the checks are in.

**Where the repository has a bypass, the maintainer may land without
that approval, through it**: [`GOVERNANCE.md`][governance]'s *How a
decision is made* says which repositories.
`--admin` turns off `gh`'s own refusal, and GitHub applies
the bypass to the merge. `enforce_admins` is off, so it waits for no
required check either:

```shell
gh pr merge <n> --squash --admin \
  --match-head-commit <the head the checks ran on>
```

Without `--admin`, `gh pr merge` refuses a head with no approval, saying
it `is not mergeable: the base branch policy prohibits the merge`.

**The pin is not optional**, in either command. Reading the ack and
merging are two calls, and the head is free to move between them — the
push that would move it comes out of the same round the verdict does.
Unpinned, the command takes whatever sits at the head when it runs;
pinned, it refuses a head that has moved, and a round lost that way is
cheaper than a tree nobody has read reaching `main`.
*The review* above anchors the exchange to a sha and [section 11][s11]
has an ack name one: the pin is that rule reaching the call that
performs the landing.

**Verify what landed rather than trusting the answer**, the signature
[the standard asks for][s-sigs] being a valid one rather than a
particular signer's:

```shell
gh api repos/{owner}/{repo}/commits/main \
  --jq '.commit.verification | {verified, reason}'
```

**What it closed is read again here too, from the landed sha rather
than from the pull request**: [the standard's *What a pull request says
it is*][s-title] has the second read, and why the first alone does not
reach a squash subject composed after it runs.

The forge deletes the head branch itself, per the setting section 11
names. What is still yours is bringing every checkout sitting on `main`
up to date,
that being where the next session starts from and a stale one being where
a branch gets built on a base that has moved. `REPOSITORY.md` carries the
settings and why they are what they are.

[s-what]: https://github.com/btclib-org/.github#what-this-repository-is
[s11]: https://github.com/btclib-org/.github#11-github-settings
[s9]: https://github.com/btclib-org/.github#9-prose-comments-and-docstrings
[s12]: https://github.com/btclib-org/.github#12-releasing
[s-title]: https://github.com/btclib-org/.github#what-a-pull-request-says-it-is
[s-rev]: https://github.com/btclib-org/.github#review
[s-sigs]: https://github.com/btclib-org/.github#signatures
[s-branch]: https://github.com/btclib-org/.github#branch-protection-and-rulesets
[dco]: https://developercertificate.org/
[governance]: https://github.com/btclib-org/.github/blob/main/GOVERNANCE.md
[roadmap]: https://github.com/btclib-org/.github/blob/main/ROADMAP.md
[good-first]: https://github.com/search?q=org%3Abtclib-org+label%3A%22good+first+issue%22+is%3Aopen&type=issues

## Worktrees

Run `git fetch origin` in the primary checkout, then check that
`git status --porcelain` is empty and `git branch --show-current` is
`main`. Run `git pull --ff-only` only when both checks pass, then verify
`git rev-parse HEAD origin/main` prints the same sha twice. Create a separate
worktree for each task with
`git worktree add <path> origin/main -b <branch>`. After committing,
remove it with `git worktree remove <path>`. If initialized submodules
make that fail,
check for uncommitted, untracked, and ignored files in the worktree and
its initialized submodules. Preserve anything needed before retrying with
`git worktree remove --force <path>`; it can delete those files. Keep the
primary checkout clean and on `main`; do not
switch branches or stash there. Hooks can fix files in place, and the local
`main` and `refs/stash` are shared by all worktrees.

## This repository in particular

Everything above is the same file in every repository of the
organization; everything below is this one's, and the comparison stops at
this heading.

There is no `.python-version` because the tracked tree has no Python source
and no gate depends on a repository-selected Python interpreter. The Python
used to create hook environments is managed by pre-commit; pin a version here
if a project source file or gate becomes interpreter-sensitive.

### The environment and the gates

uv is the only thing that has to be installed; it fetches interpreters
and tools itself. There is no project here — no `pyproject.toml`, no lock
file, and no Python at all, `check-changelog` being fetched from
`btclib-org/.github` — so nothing is synced and every command is a `uvx`:

```shell
uvx pre-commit run --all-files
uvx pre-commit run --all-files markdownlint-cli2
uvx pre-commit validate-config .pre-commit-config.yaml
```

A `pre-commit run` given neither `--all-files` nor `--files` reads what
is staged, so from a clean tree it reports `(no files to check)Skipped`
and exits 0. Both `pre-commit run` lines above carry the flag for that
reason, and the hook id is the whole of what separates the second from
the first.

That last one is worth running before pushing a change to the hook
config: it catches what a wrong `types_or` tag or a malformed entry would
otherwise turn into a red lint job.

`check-changelog` is a `language: script` hook, run through its own
`#!/usr/bin/env python3` shebang rather than through a `python3` pre-commit
names in the config, and it asks for nothing beyond uv: `uvx` puts the
environment it built for pre-commit ahead of `PATH` for that process, the
hook inherits it, and its `bin/` holds the `python3` uv fetched. With a
`PATH` resolving no `python3` at all, `command -v python3` run from that
same process answers with that `bin/`'s.

**Check exit codes, not filtered output.** `pre-commit run ... | grep -v
Passed` hides a failure, and `grep` finding nothing exits 1, which is not
the gate's answer to anything.

**The gate is not installed as a git hook.** `pre-commit install` writes
into the common git directory, which every worktree of this repository
shares: `git -C <worktree> rev-parse --git-path hooks` answers with the
maintainer's checkout, so one session installing it installs it for every
other. Run the gate by hand before committing.

**The suite under `tests/` runs the launchers and their helpers**, with
`bash` on macOS and Linux and with PowerShell on Windows. CI runs it on
Ubuntu only: `test.yml`, on every pull request. There `tests/run.sh` runs,
and so does every file of `tests/win/` that starts no `cmd.exe`, under
the runner's `pwsh`; the files that do start it are named in the step
of `test.yml` that runs the others. The macOS and Windows halves run by
hand, `tests/run.sh` under the `/bin/bash` 3.2 macOS ships and
`tests/run.ps1` under PowerShell, until a workflow runs them. On macOS and
Linux:

```shell
bash tests/run.sh
```

`tests/README.md` has the Windows command, what the suite covers, and
how a test is added. **A major change adds or updates tests there**:
one that gives a launcher or a helper a new behaviour, or corrects one.

**What neither the gate nor the tests reach is a launcher starting
what it launches.** The hooks read prose, configuration and, through
`shellcheck`, the `.sh` and `.command` launchers themselves —
`shellcheck` reads a launcher by its shebang rather than by directory,
so `linux/scripts/`'s own `.sh` files are in scope already and reaching
them added no hook. The suite runs a launcher's menu and leaves it, no
binary being in the tree, except as `tests/README.md` says. So a change
to what a launcher starts is verified by running it on a macOS, a
Windows and a Linux machine, from a volume that is not the boot disk —
which is the case the paths in these scripts exist for, and the one a
checkout on an internal disk never exercises.

**The `.bat` and `.ps1` halves are read by the generic hooks, and by
`script-security.yml` for PSScriptAnalyzer's findings and for Blinter's
Error, Security and Warning findings** (*What gates a merge*, below).
The same job refuses a non-ASCII byte and a lone CR in a `.bat` or
`.cmd`; its header says why. PowerShell's parser is PSScriptAnalyzer,
and `.pre-commit-config.yaml`'s header says why it is not a hook here.
The command shows the job's findings before a push, and runs as written
in bash, zsh and pwsh. It reads the version the job pins from the
workflow, and stops where it finds none or that version is not
installed. Its empty settings ignore a `PSScriptAnalyzerSettings.psd1`,
as the job does:

```shell
pwsh -Command '$ErrorActionPreference = "Stop"
  $m = Select-String -Path .github/workflows/script-security.yml `
    -Pattern "download/([0-9.]+)/PSScriptAnalyzer\."
  if (-not $m) { throw "no PSScriptAnalyzer pin in script-security.yml" }
  $v = $m[0].Matches[0].Groups[1].Value
  Import-Module PSScriptAnalyzer -RequiredVersion $v
  Invoke-ScriptAnalyzer -Path . -Recurse -Settings @{}'
```

Its `ParseError` severity is PowerShell's own parser refusing the file,
which is a different answer from a style finding.

A finding it reports is fixed or, where it is no defect, suppressed in
the script by a `SuppressMessageAttribute` that says why. The same
command with `-SuppressedOnly` lists the suppressed findings.

**`tests/win/node-args.ps1` tests `win/scripts/bitcoin/node-args.ps1`**,
which the Windows mainnet launcher uses to read a running node's network
switches. It is in the suite, so `tests/run.ps1` runs it. It starts no
process, so `pwsh` also runs it on any system, CI's included:

```shell
pwsh -NoProfile -File tests/win/node-args.ps1
```

**`tests/sh/updater-input.sh` and `tests/win/updater-input.ps1` feed the
updaters malformed `SHA256SUMS`, signature output and version strings**,
and expect each refused with nothing installed. They stand in for a fuzzer
([ISS 646](https://github.com/btclib-org/portanode/issues/646)). The shell
one runs the macOS and Linux updaters in a copy of the tree with
a real throwaway key, and is skipped without `gpg`; the PowerShell one runs the
PowerShell inside the `.bat` files, read from them, and runs on any system
with `pwsh`. It also checks that each fetch offers TLS 1.2 and leaves
`SystemDefault` alone. It is in the suite, so `tests/run.ps1` runs it:

```shell
pwsh -NoProfile -File tests/win/updater-input.ps1
```

`.bat` has Blinter, which installs under uv alone:

```shell
uvx blinter . --no-config --summary
```

It exits non-zero here, and `.pre-commit-config.yaml`'s header says why
it is not a hook. Read what it reports before believing it, and inspect
the file from `git archive`, which applies the checkout attributes.

### What gates a merge, and what only reports

**`lint.yml` runs the gate above on every pull request**, with `uvx
pre-commit run --all-files`, which is the same command this section gives
you: one declaration of what the hooks are, so a hook added to
`.pre-commit-config.yaml` needs no edit to a workflow.

**Whether its answer holds the merge is a separate question**, and the
command is what says which state we are in:

```shell
gh api repos/btclib-org/portanode/branches/main/protection \
  --jq 'has("required_status_checks")'
```

That answers `true`: a red `Lint`, `Dependency review`, `Sign-off`,
`Script security`, `test: every job passed` or `codeql: every job passed`
stops the merge.

**No required check holds an administrator's merge**, here or below,
because `enforce_admins` is off. `REPOSITORY.md`'s *What gates a merge*
has the setting, that it is classic branch protection rather than a
ruleset rule, and that its `strict` and `enforce_admins` flags are off.

**`script-security.yml` runs PSScriptAnalyzer's default rules and
Blinter's Error, Security and Warning rules, over the `.ps1` and `.bat`
scripts on every pull request**, and its header says what fails it. Its
`Script security` job is a required check. A Blinter finding it reports is
fixed or, where it is no defect, recorded in `.github/blinter-baseline.json`
by the command the job prints. For a Warning rule,
`.github/blinter-reasons.md` says why its findings are no defect.

`test.yml`'s `test: every job passed` job passes where every job of
its run did, and the branch rule names it, so a red one holds the
merge.

**`links.yml` and `claude-review.yml` only report, and must go on doing
so.** The first is weekly and reads every link in the markdown, where a
third party returning 502 would be a red merge with nothing to fix; the
second posts the ack of record `REVIEWING.md` describes, which is an
opinion for you to weigh. Neither belongs in a branch rule.

`verified-signatures.yml` reports after each push to `main` whether every
commit pushed is `verified`; [the standard's *Signatures*][s-sigs] has the rule.

`codeql.yml` runs CodeQL over the workflow files on every pull request,
every push to `main` and weekly, which is the code-scanning analysis the
Scorecard's SAST check reads off a merged pull request. Its `codeql:
every job passed` job passes where every job of its run did, and the
branch rule names it, so a red one holds the merge. A CodeQL
alert is fixed, or dismissed only as section 10 of the organization
standard's *scorecard* entry allows.

`scorecard.yml` runs the OpenSSF Scorecard after each push to `main` and
weekly, and publishes the score the `README.md` badge shows. It does not
run on a pull request.

What holds a pull request is the review and green checks, and what
holds every commit that reaches `main` — linear history, no
force push, no deletion — is a ruleset with no bypass actor.
`REPOSITORY.md` reads all of it back from the endpoint rather than
restating it.

### Conventions and measurements the tree relies on

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
- **A commit subject is one physical line, however long.** The
  eighty-column wrap is for files in the tree, and applying it to a
  subject produces a wrapped one. `%s` conceals the result: it takes
  everything up to the first blank line and joins it, so `%s`, `git log
  --oneline` and any `grep` over either report a whole sentence where the
  subject is broken. The squash takes the first physical line, appends
  `(#N)` and moves the remainder into the body. The first line of `%B`
  shows the subject as it will land:

  ```shell
  git show -s --format=%B <sha> | head -1
  ```

- **The executable bit decides nothing on the volume this is built for.**
  macOS synthesises a mode for exFAT rather than storing one: a file
  written there reads `rwx------` whatever `chmod` was asked for, and a
  script runs regardless. `ASSURANCE_CASE.md`'s *Why each filesystem
  is recommended* and `macos/scripts/utilities/set-permissions.sh` cite
  this measurement, made on an exFAT image:

  ```shell
  d=$(mktemp -d)
  hdiutil create -size 20m -fs ExFAT -volname T -o "$d/t.dmg"
  hdiutil attach "$d/t.dmg"
  printf '#!/bin/bash\necho hi\n' > /Volumes/T/u.sh
  chmod 644 /Volumes/T/u.sh && ls -l /Volumes/T/u.sh && /Volumes/T/u.sh
  ```

  It exits 0 and prints `hi` under `-rwx------`. The mode in the index
  matters for the other cases: a clone or an unpacked source archive on
  APFS, where GitHub's zipball carries the index mode through `unzip`.
  Detach the image afterwards with `hdiutil detach /Volumes/T`.
- **`pwsh` is installable.** `brew install powershell` on macOS provides
  it. Once `pwsh` is there, this adds the module at the version
  `script-security.yml` pins, read as the PSScriptAnalyzer command in
  *The environment and the gates* reads it:

  ```shell
  pwsh -Command '$ErrorActionPreference = "Stop"
    $m = Select-String -Path .github/workflows/script-security.yml `
      -Pattern "download/([0-9.]+)/PSScriptAnalyzer\."
    if (-not $m) { throw "no PSScriptAnalyzer pin in script-security.yml" }
    $v = $m[0].Matches[0].Groups[1].Value
    Install-Module -Name PSScriptAnalyzer -RequiredVersion $v -Force `
      -Scope CurrentUser'
  ```

  With both, `[System.Management.Automation.Language.Parser]::ParseFile`
  and PSScriptAnalyzer run for real: a positive control against the
  unmodified tree first, then a clean run against the change, rather than
  a `.ps1` change read for correctness without being parsed.
- **Blinter is compared by version and by line numbers.** Capture the
  version once and run both halves of a comparison under it, stderr
  dropped because its `utf_8` encoding notices move under unrelated
  edits:

  ```shell
  V=$(uvx blinter --version 2>/dev/null | sed -E 's/^v?([0-9.]+).*/\1/')
  uvx --from "blinter==$V" blinter . --no-config --summary 2>/dev/null
  ```

  The job reads with the Blinter that `script-security.yml` pins, so set
  `V` to the pin to match it, and with the baseline and
  `.github/blinter.ini`, which says which rules Blinter runs. That run
  exits 0 on a tree whose findings the baseline holds, and names a finding
  it does not hold and an entry no finding matches. The job checks more
  than this run does, as its header says:

  ```shell
  uvx --from "blinter==$V" blinter . --config .github/blinter.ini \
    --baseline .github/blinter-baseline.json
  ```

  Judge a diff by the set of line numbers per file and rule code, not by
  counts. Lines blinter reads as embedded script, which can include plain
  batch lines after a `$name =` match, get no per-line checks:
  `blinter.parsing.embedded._detect_embedded_script_blocks` returns the
  set.
