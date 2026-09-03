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

## The issue tracker

Where an issue is filed, and what an alignment finding has to name, is
[the standard's *What this repository is*][s-what]: an issue spanning
repositories, or whose subject is the standard, goes to
[btclib-org/.github](https://github.com/btclib-org/.github/issues), and
one about this tree alone stays here.

A finding noticed while doing something else is filed, not carried.
`REVIEWING.md`'s *Every collateral finding becomes an issue* is the whole
of what to do with one, and it applies to an author as much as to a
reviewer: a pull request answering two questions cannot be accepted for
either.

## Documentation and comments

[Section 9 of the standard][s9] is the prose style, and it governs the
prose this tree ships — comments, docstrings and markdown. It is not
restated here: a second wording is the one that goes stale, which is
that section's own *One fact in one place*.

A commit message is prose this tree ships too, though section 9 does not
say so: [the only merge method the rule accepts][s11] puts it on `main`
as the landing commit's body, so what is written in one is read there
long after the branch is gone.

## Pull requests

What `main` accepts, and what it refuses to everyone, is [section 11 of
the standard][s11]. Run the gates locally before opening anything —
the last section of this file says which they are — because CI runs
exactly them, so a red run there is a local run that was not done.

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
that the thing that lands, and a `CHANGELOG.md` entry — and `(issue #N)`
cites, in those same places, an issue the change advances and does *not*
close. One token holds one meaning whichever file it sits in, so the
pair is chosen by what is true of the change rather than by which file
is being written, and a tree's own landed subjects are not what to copy
it from: nothing already landed is rewritten, so what a repository wrote
before the rule stays where it is.

`REVIEWING.md` is the standard a review is written against, and is this
file's other half. Read before opening a pull request, it is what the
pull request will be answered against.

`CHANGELOG.md` gets an entry for anything a reader would notice, and the
release notes move only for something a user has to *act* on, in the
repositories that publish.

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

### The landing queue

Where more than one pull request is open against this repository, only
one is carried to `main` at a time: rebased onto the tip, reviewed on
that head, and landed, while every other one waits, untouched, for its
turn. This governs which of several *already open* pull requests reaches
`main` next; *One subject, opened as soon as it is written* above governs
the moment before that, when a finished one is opened — the two do not
conflict, since a pull request is still opened without delay and still
waits its turn once several are open.

The reason is CI throughput, not the ack a waiting pull request keeps —
`REVIEWING.md`'s *The verdict* states what an ack belongs to, and
*Landing it* below states which rebase voids one. Every rebase queues
this repository's whole check matrix against the organization's ceiling
on concurrent jobs, so rebasing every waiting pull request after each
landing spends that capacity on runs the next landing invalidates
anyway, and delays the one pull request that is actually next: work
spent on a pull request that is not next is work that delays the one
that is. The ceiling's figure is `REPOSITORY.md`'s, under *Plan-gated
settings*, beside the command that re-derives it.

Order is cheapest and least contended first, most invasive last, so that
a large change does not sit at the head blocking everything behind it.

The maintainer may declare a bounded exception — several pull requests in
flight against one repository, for a named piece of work — trading the
cost above for throughput; it is recorded as a comment in
[btclib-org/.github](https://github.com/btclib-org/.github/issues), by
*The issue tracker* above, and holds only for the work it names.

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
  in the thread, and pushes the answer without waiting for CI;
- the reviewer resolves the threads they opened, that being what says a
  finding is closed, and re-reviews the delta rather than the branch.

**What ends the loop is the ack of record**, and the author does not
supply their own. A reading that says what it found and delivers no
verdict is a review too and ends nothing; [the standard's *Review*][s-rev]
has which is which, and `REVIEWING.md` has how each is written. A
disagreement that survives a second exchange goes to the maintainer
instead of into a third round.

### Landing it

CI is read once, and this is where. Rebase onto `main`'s tip, push that
head so the checks run on the tree that will land, and only then wait for
them: checks read before a rebase describe a tree nobody is landing. A
rebase that moved nothing but the base leaves the ack standing; one that
resolved a conflict does not, that resolution being a change no reviewer
has seen.

Then squash, [the only method the rule accepts][s11].

**The maintainer's bypass is not automatic — it has to be invoked, and
`gh pr merge` cannot invoke it**, refusing client-side before it asks
GitHub anything:

```text
Pull request is not mergeable: the base branch policy prohibits the merge
```

The merge endpoint applies it server-side, and it is the same endpoint
the merge button asks:

```shell
gh api -X PUT repos/{owner}/{repo}/pulls/<n>/merge \
  -f merge_method=squash -f sha=<the head the checks ran on>
```

**The `sha` is not optional.** Reading the ack and merging are two
calls, and the head is free to move between them — the push that would
move it comes out of the same round the verdict does. Unpinned, the
command takes whatever sits at the head when it runs; pinned, [the
endpoint answers `409` where the head has moved][gh-merge], and a round
lost that way is cheaper than a tree nobody has read reaching `main`.
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
[s-title]: https://github.com/btclib-org/.github#what-a-pull-request-says-it-is
[s-rev]: https://github.com/btclib-org/.github#review
[s-sigs]: https://github.com/btclib-org/.github#signatures
[gh-merge]: https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request

## This repository in particular

Everything above is the same file in every repository of the
organization; everything below is this one's, and the comparison stops at
this heading.

### The environment and the gates

uv is the only thing that has to be installed; it fetches interpreters
and tools itself. There is no project here — no `pyproject.toml`, no lock
file, no Python at all — so nothing is synced and every command is a
`uvx`:

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

**Check exit codes, not filtered output.** `pre-commit run ... | grep -v
Passed` hides a failure, and `grep` finding nothing exits 1, which is not
the gate's answer to anything.

**The gate is not installed as a git hook.** `pre-commit install` writes
into the common git directory, which every worktree of this repository
shares: `git -C <worktree> rev-parse --git-path hooks` answers with the
maintainer's checkout, so one session installing it installs it for every
other. Run the gate by hand before committing.

**What the gate does not reach is running the thing this repository
ships.** The hooks read prose, configuration and, through `shellcheck`,
the `.sh` and `.command` launchers themselves — `shellcheck` reads a
launcher by its shebang rather than by directory, so `linux/scripts/`'s
own `.sh` files are in scope already and reaching them added no hook —
but nothing here runs one. So what stands in for a suite is running the
launcher on a macOS, a Windows and a Linux machine, from a volume that
is not the boot disk — which is the case the paths in these scripts
exist for, and the one a checkout on an internal disk never exercises.

**The `.bat` and `.ps1` halves are read by the generic hooks and by no
parser.** PowerShell's is PSScriptAnalyzer, and
`.pre-commit-config.yaml`'s header says why it is not a hook here; run it
by hand, against a `pwsh` that carries the module:

```shell
pwsh -Command 'Invoke-ScriptAnalyzer -Path . -Recurse'
```

Its `ParseError` severity is PowerShell's own parser refusing the file,
which is a different answer from a style finding.

`.bat` has Blinter, which installs under uv alone:

```shell
uvx blinter . --no-config --summary
```

It exits non-zero here, and `.pre-commit-config.yaml`'s header says why
that is not a hook: not one of the findings the rules that set its exit
code produce here is a defect, and it suppresses by rule code rather
than by line. Read what it reports before believing it, and take the
file with `git archive` rather than with `git show` — `CLAUDE.md`'s
bullet on these files says why.

**`E010` is one rule code covering two different shapes of a
`^`-continued `for /f`, and only one of them is the false positive the
paragraph above describes.** A caret inside the backquoted command
substitution is a continuation like any other, and the loop runs; a
caret between `in` and the file set's own opening parenthesis is not a
continuation, and cmd.exe genuinely loses the loop's `do`. Which shape a
given `E010` names is read from where the caret sits relative to the
backquotes, not from the code.

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

That answers `true`: a red `Lint` stops the merge. `REPOSITORY.md`'s
*What gates a merge* has the setting, that it is classic branch
protection rather than a ruleset rule, and what its `strict` flag costs.

**`links.yml` and `claude-review.yml` only report, and must go on doing
so.** The first is weekly and reads every link in the markdown, where a
third party returning 502 would be a red merge with nothing to fix; the
second posts the ack of record `REVIEWING.md` describes, which is an
opinion for you to weigh. Neither belongs in a branch rule.

What holds a pull request is the review and a green `Lint`, and what
holds every commit that reaches `main` — signature, linear history, no
force push, no deletion — is a ruleset with no bypass actor.
`REPOSITORY.md` reads all of it back from the endpoint rather than
restating it.
