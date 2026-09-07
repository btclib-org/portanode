# Releasing PortaNode

A release here is a signed tag and a GitHub release, cut by hand. Nothing
in `.github/workflows` cuts one —

```shell
gh api repos/btclib-org/portanode/actions/workflows \
  --jq '[.workflows[].name]'
```

is what says which workflows there are — and there is nothing to publish
to an index either: what this repository ships is scripts and
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

`YYYY.MM.DD`, the day the folder was assembled — *[calendar
versioning](https://calver.org/)* — and the tag is that string with a `v`
in front. There is no fourth component and no release candidate: a fix to
a release that shipped broken is another day's release.

`VERSION` holds the string a release is cut at, and it is the release
step that moves it. That is worth knowing before editing it for any
other reason: **`VERSION` is also the marker the launchers find the root
by.**

```shell
grep -rn 'VERSION' shared/lib.sh win/scripts/root.bat win/scripts/root.ps1
```

Each walks up from its own location until it finds a directory holding a
`VERSION` file and at least one platform directory beside it — `shared/`
being sourced by every platform's own `lib.sh`, `macos/scripts/lib.sh`
included — before falling back. Renaming that file, or deleting it,
breaks every launcher that was not given `PORTANODE_ROOT`, and does so
with a "binary not found" rather than with anything naming the cause.

`CHANGELOG.md` and `RELEASE_NOTES.md` carry `## [Unreleased]` as their
topmost `##` heading at every commit on the default branch, where
`VERSION` holds the string a release is cut at. The heading and `VERSION`
never agree, and that is by construction rather than by drift: step 2
below retitles the open heading and opens a new one in the same pull
request, so no commit is left with a released version at the top of
either file. A dated placeholder heading would not do — it names a
version before the date it is cut on is known.

## Cutting one

1. Gate the tree and make sure it is clean: `uvx pre-commit run
   --all-files`, exit code 0, then `git status --porcelain` empty.
1. Decide the date, and make the three files say it. `CHANGELOG.md`'s
   `## [Unreleased]` heading becomes `## [YYYY.MM.DD] - <what this
   release is>`; `RELEASE_NOTES.md`'s does the same, its retitled
   section saying what a user has to *act* on, and nothing that is
   merely a change; `VERSION` becomes that string. This pull request
   also opens a new, empty `## [Unreleased]` above the retitled heading
   in both files — the heading ordinary branches append under, and the
   one this same step retitles the next time a release is cut.
1. Land that as a pull request like any other. `main` takes nothing else:
   `main-integrity` has no bypass actor, so a tag cut on a commit that
   was pushed straight to `main` is a tag on a commit that was refused.
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

    `-s` and not a bare `git tag`: `tag-integrity` requires a signature
    on `refs/tags/v*`, and a lightweight tag has no object to carry one.
    `REPOSITORY.md`'s *Rulesets* section has that rule and the command
    that reads which tags it has to match.

1. Publish the release, its body being the section just written:

    ```shell
    gh release create "v$(cat VERSION)" --title "v$(cat VERSION)" \
      --notes-file <(awk -v v="$(cat VERSION)" \
        '$0 ~ "^## \\[" v "\\]" {f=1; next} f && /^## / {exit} f' \
        RELEASE_NOTES.md)
    ```

    `awk` and not `sed -n '/start/,/end/p'`: that range prints the
    heading that ends it, and trimming the last line with `sed '$d'`
    eats a real line whenever the section being cut is the last one in
    the file — which it is, the newest release being at the top.

1. Read back what landed rather than trusting the answer:

    ```shell
    gh api repos/btclib-org/portanode/git/refs/tags/"v$(cat VERSION)" \
      --jq '.object.type'
    ```

    answers `tag`, not `commit`. A `commit` there means the tag went up
    unsigned, and the fix is to delete and re-cut it — which is why
    `tag-integrity` carries no `deletion` rule.

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
