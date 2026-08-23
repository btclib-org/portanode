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
a distribution. What a user takes is a clone or the source archive GitHub
attaches to the release itself; the existing release carries no uploaded
asset:

```shell
gh api repos/btclib-org/portanode/releases \
  --jq '.[] | {tag_name, assets: [.assets[].name]}'
```

## The version string

`YYYY.MM.DD`, the day the folder was assembled — *[calendar
versioning](https://calver.org/)* — and the tag is that string with a `v`
in front. There is no fourth component and no release candidate: a fix to
a release that shipped broken is another day's release.

`VERSION` holds the last released string, and it is the release step that
moves it. That is worth knowing before editing it for any other reason:
**`VERSION` is also the marker the launchers find the root by.**

```shell
grep -rn 'VERSION' macos/scripts/lib.sh win/scripts/root.bat \
  win/scripts/root.ps1
```

Each walks up from its own location until it finds a directory holding a
`VERSION` file — on macOS, one that also holds `macos/` and `win/` —
before falling back. Renaming that file, or deleting it, breaks every
launcher that was not given `PORTANODE_ROOT`, and does so with a "binary
not found" rather than with anything naming the cause.

`CHANGELOG.md` names the version being worked on in its top heading,
where `VERSION` still names the one before it. The two agree only between
the release and the next change, and that is by construction rather than
by drift.

## Cutting one

1. Gate the tree and make sure it is clean: `uvx pre-commit run
   --all-files`, exit code 0, then `git status --porcelain` empty.
1. Decide the date, and make the three files say it. `CHANGELOG.md`'s
   top heading becomes `## [YYYY.MM.DD] - <what this release is>`;
   `RELEASE_NOTES.md` gets a section under the same version saying what a
   user has to *act* on, and nothing that is merely a change;
   `VERSION` becomes that string.
1. Land that as a pull request like any other. `main` takes nothing else:
   `main-integrity` has no bypass actor, so a tag cut on a commit that
   was pushed straight to `main` is a tag on a commit that was refused.
1. Tag the merged commit, **signed**:

    ```shell
    git fetch origin && git checkout origin/main
    git tag -s "v$(cat VERSION)" -m "PortaNode $(cat VERSION)"
    git push origin "v$(cat VERSION)"
    ```

    `-s` and not a bare `git tag`: `tag-integrity` requires a signature
    on `refs/tags/v*`, and a lightweight tag has no object to carry one.
    `REPOSITORY.md` records that the first tag predates the rule and is
    lightweight, which is why this step is spelled out rather than
    assumed.

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
gh release delete "v<version>" --yes
git push origin --delete "v<version>"
git tag -d "v<version>"
```

**After**, do not move the tag. A tag that somebody has fetched is a name
for a tree they have, and moving it makes that name mean two things.
Cut the next day's release instead, and say in `RELEASE_NOTES.md` what
the broken one does and what to do about it.

There is no index to yank from and no attestation to revoke, which is the
one way this is simpler than a publishing repository: what a user has is
a folder they can replace by pulling.
