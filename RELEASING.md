# Releasing PortaNode

A release here is a signed tag and a GitHub release, cut by hand. Nothing
in `.github/workflows` cuts one —

```shell
git ls-tree --name-only -r origin/main -- .github/workflows
```

is what says which workflows the tree holds: it reads `origin/main`'s
own tree object, never the index and never the working directory, so a
file only staged or only present on disk does not appear in it. That
needs a checkout with `origin/main` fetched, where the API read it
replaces needed only `gh`'s own authentication and no clone at all. The
API's own `actions/workflows` list answers a neighbouring question in
any case — which workflows GitHub will run — and keeps a workflow's
entry after the branch carrying its file is deleted, so the two diverge
wherever such a branch has existed. And there is nothing to publish to
an index either: what this repository ships is scripts and
configuration, and the binaries they install are downloaded from their
own publishers at update time rather than attached here.

So the release is an announcement and a fixed point to roll back to, not
a distribution. What it ships is the source archive GitHub attaches to
it; a release cut by the steps below carries no uploaded asset beyond
that archive, nothing in them asking `gh release create` to attach one.
The check is the same before the first release as after any of them:

```shell
gh api repos/btclib-org/portanode/releases \
  --jq '.[] | {tag_name, assets: [.assets[].name]}'
```

Empty output means there is no release to check yet, not that one exists
and carries nothing; where the list is non-empty, every entry's `assets`
answering `[]` is what confirms the claim above.

## The version string

[Section 12 of the organization
standard](https://github.com/btclib-org/.github#12-releasing) sets
calendar versioning, `YYYY.M.D`. The tag is that string with a `v` in
front, per section 11's `tag-integrity` ruleset and its `refs/tags/v*`
target; here that string names the day the folder was assembled. There
is no fourth component and no release candidate: a fix to a release
that shipped broken is another day's release.

`VERSION` holds the string a release is cut at, and it is the release
step that moves it there. Between releases it holds `YYYY.M`, month
only, so a checkout of `main` reports itself as work in progress rather
than as a day nothing was assembled on. The month is the one after the
month of the release just cut, rather than the calendar's current one;
those two differ whenever a release is cut in the month already
running. Comparison is component-wise and a missing component reads as
`0`, so `2026.9` sorts *below* `2026.9.7` — a checkout declaring
`2026.9` after that release would report itself older than the release
it already contains — where `2026.10` sorts above it.

What the rule holds is each commit against the releases reachable from
it, not the sequence of values `VERSION` takes across `main`. A second
release cut in the same month moves the string down, to that release's
own day, and the bump after it moves it back up; at each of those
commits `VERSION` is the newest release contained or above it, which is
the whole of what is required. The numbers do fall, so reading the rule
as one about a rising sequence is the misreading available, and it
answers a question nothing here asks.

This is worth knowing before editing `VERSION` for any other reason:
**it is also the marker the launchers find the root by.**

```shell
grep -rn 'VERSION' shared/lib.sh win/scripts/root.bat win/scripts/root.ps1
```

Each walks up from its own location until it finds a directory holding a
`VERSION` file and at least one platform directory beside it — `shared/`
being sourced by every platform's own `lib.sh`, `macos/scripts/lib.sh`
included — before falling back. Renaming that file, or deleting it,
breaks every launcher. One given `PORTANODE_ROOT` stops with a message
naming that variable; the others fall back to their own folder and fail
with a "not found" error, such as `Error: Binaries directory not found at
macos/bin`, rather than with anything naming the cause.

## Cutting one

1. Gate the tree and make sure it is clean: `uvx pre-commit run
   --all-files`, exit code 0, then `git status --porcelain` empty. Run
   the alert command of the step before the tag here too, so that a fix
   lands before the release notes do. CI runs the suite on Ubuntu only,
   so run it by hand on the other two platforms, each exiting 0:
   `/bin/bash tests/run.sh` on a Mac, and `tests\run.ps1` on Windows
   under both `pwsh` and `powershell`, as `tests/README.md` shows.

1. Decide the date, and make the three files say it. `CHANGELOG.md`
   gains `## v<version>`, the tag's own heading, alone on its line,
   above the previous release's. The first line of its body says what
   the release is; the rest takes what a user would notice, written
   from the squash subjects since the previous tag, grouped and
   shortened:

    ```shell
    tag=v<previous version>
    ```

    ```shell
    git log "${tag:?}"..HEAD --format=%s
    ```

   `RELEASE_NOTES.md` gains the same heading, its section saying what a
   user has to *act* on, and nothing that is merely a change. Where
   either file still holds a `## [Unreleased]` section, its content is
   folded into this one and the heading is deleted. `VERSION` becomes
   the date, `YYYY.M.D`.
1. Land that as a pull request like any other. `main` takes nothing else:
   `main-integrity` has no bypass actor, so a tag cut on a commit that
   was pushed straight to `main` is a tag on a commit that was refused.
1. Check that `VERIFYING.md` names the key that is about to sign. Git
   signs with `user.signingkey`; where it is unset, git signs with the
   committer identity, and the command prints an error naming `key`, then
   `not named: none`.
   The command reads the secret keyring, because a name that two keys
   share can match a public key this machine cannot sign with. Where the
   setting matches no secret key or more than one, it names none.
   Otherwise it looks for the primary key's fingerprint, spaces aside, in
   the key list of `origin/main`'s `VERIFYING.md`:

    ```shell
    key=$(git config user.signingkey)
    primary=$(gpg --with-colons --list-secret-keys "${key:?}" \
      | awk -F: '$1=="sec"{n++} $1=="fpr"&&n==1&&f==""{f=$10}
          END{if(n==1)print f; exit n!=1}') \
      && git fetch origin \
      && git show origin/main:VERIFYING.md | grep '^- primary key:' \
        | tr -d ' ' | grep -qF "${primary:?}" \
      && echo "named" || echo "not named: ${primary:-none}"
    ```

    `not named: none` means that `user.signingkey` is unset, or matched no
    secret key or several, so the setting is what changes, not
    `VERIFYING.md`. Where it
    answers `not named` with a fingerprint, change `VERIFYING.md` to name that
    primary key and its signing subkey, and land the change as a pull
    request before the tag. A tag signed by a key the file does not
    name is not a release (`VERIFYING.md`, *Who signs the tags*).
1. Read the open alerts and stop while any is open. The command prints
   each open Dependabot and code-scanning alert, and exits `0` only
   where there is none and both calls answered:

    ```shell
    open=$({ gh api --paginate \
        'repos/btclib-org/portanode/dependabot/alerts?state=open' \
        --jq '.[] | "dependabot \(.number) \(.dependency.package.name)"' \
      && gh api --paginate \
        'repos/btclib-org/portanode/code-scanning/alerts?state=open' \
        --jq '.[] | "code-scanning \(.number) \(.rule.id) \(.html_url)"'; }) \
      && { test -z "$open" || { printf '%s\n' "$open"; false; }; }
    ```

    Fix the alert and run the command again. A Scorecard alert may be
    dismissed only as [section 10 of the organization
    standard](https://github.com/btclib-org/.github#10-workflows)'s
    *scorecard* entry allows. A call that fails (404, 403) stops the
    release as an open alert does.
1. Tag the merged commit, **signed**, from the primary checkout brought
   forward under `CLAUDE.md`'s *The primary checkout is the maintainer's*
   preconditions — on `main` and clean — plus the ancestry `--ff-only`
   itself requires. Chained with `&&`, so a refusal on either of the
   first two commands stops the sequence rather than signing and pushing
   a tag on whatever commit `HEAD` was left at:

    ```shell
    git fetch origin && git merge --ff-only origin/main && \
      git tag -s "v$(cat VERSION)" -m "PortaNode $(cat VERSION)" && \
      git push origin "v$(cat VERSION)"
    ```

    `-s` and not a bare `git tag`: a lightweight tag has no object to
    carry a signature, and `tag-integrity` does not check one.
    `REPOSITORY.md`'s *Rulesets* section has what the rule refuses and
    the command that reads which tags it has to match.

1. Publish the release, its body being the section just written:

    ```shell
    gh release create "v$(cat VERSION)" --title "v$(cat VERSION)" \
      --notes-file <(awk -v v="$(cat VERSION)" \
        '$0 ~ "^## v" v "$" || $0 ~ "^## \\[" v "\\]" {f=1; next}
         f && /^## / {exit} f' \
        RELEASE_NOTES.md)
    ```

    `awk` and not `sed -n '/start/,/end/p'`: that range prints the
    heading that ends it, and trimming the last line with `sed '$d'`
    eats a real line whenever the section being cut is the last one in
    the file.

1. Read back what landed rather than trusting the answer:

    ```shell
    sha=$(gh api repos/btclib-org/portanode/git/refs/tags/"v$(cat VERSION)" \
      --jq '.object.sha')
    gh api repos/btclib-org/portanode/git/tags/"${sha:?}" \
      --jq '.verification.verified'
    ```

    answers `true`. A lightweight tag has no tag object, so the second
    call answers 404, and an unsigned annotated tag answers `false`. The
    fix for either is to delete and re-cut it — which is why
    `tag-integrity` carries no `deletion` rule.
1. Review the bestpractices.dev answers. Refresh the saved answers with
   btclib-org/.github's `.github/scripts/bestpractices.py`, and run its
   `--stale` and `--differ` to find what to read (section 10 of its README).
   Read <https://www.bestpractices.dev/projects/15649> against the release
   and update every answer it changed: the release notes, the
   vulnerabilities it fixed and the signed tag. Then refresh the saved
   answers again. An advisory this repository publishes is owed the same
   review.
1. Open a separate pull request that bumps `VERSION` to `YYYY.M`, the
   month that sorts above the day just tagged — see *The version string*
   above. It does not travel with the release: every command above reads
   `$(cat VERSION)` literally, so a tree already bumped before the tag is
   cut tags and publishes the month-only string instead of the release's
   own day.

## If something goes wrong

**Before anybody has taken the release**, delete the tag and the release
and cut them again:

```shell
gh release delete --yes v<version>
git push origin --delete v<version>
git tag -d v<version>
```

**After**, do not move the tag. A tag that somebody has fetched is a name
for a tree they have, and moving it makes that name mean two things.
Cut the next day's release instead, and say in `RELEASE_NOTES.md` what
the broken one does and what to do about it.

There is no index to yank from and no attestation to revoke, which is the
one way this is simpler than a publishing repository: what a user has is
a folder they can replace by pulling.
