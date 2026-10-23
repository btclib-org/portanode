# Verifying a release

Each release of PortaNode has a signed tag named `v` and the date it was
cut (`RELEASING.md`). Check the tag's signature before you run a
launcher from it: the signature is what says the folder holds what the
maintainer released.

## Who signs the tags

The tags are signed with the OpenPGP key of the maintainer,
[`fametrano`](https://github.com/fametrano), Ferdinando Ametrano:

- primary key: `FFCF 3A68 D839 0BED 5EFF  EF7F 35DC D452 3E9E 1B1E`
- the subkey that signs the tags:
  `49E5 2319 B377 848A 737E  2DBE 2279 DA8B C269 4720`

A tag signed by any other key is not a release of this repository until
this file names that key.

### The revoked key

The tags up to `v2026.10.17` were signed with an earlier key. The
maintainer revoked it on 2026-10-19 as superseded:

- revoked primary key: `91D9 67D0 8A2F 3646 A0C4  2ED0 07B5 59B7 1373 BF5D`
- revoked subkey: `B115 1204 0C6E 86D7 B5E0  3DD1 4D71 ED3A 9A8E DFC5`

*A tag signed by the revoked key* says what you see for such a tag.

## Getting the key

The key is published on the maintainer's GitHub account. Import it, then
check that its fingerprint is the current primary key above:

```shell
curl -fsSL https://github.com/fametrano.gpg | gpg --import
gpg --fingerprint FFCF3A68D8390BED5EFFEF7F35DCD4523E9E1B1E
```

That address serves the revoked key as well, so that the older tags can
be checked.

## Checking a tag

Verify a clone, not a ZIP. The ZIP of `main` and the source archive
GitHub attaches to a release carry no signature.

```shell
git clone https://github.com/btclib-org/portanode.git
git -C portanode tag --sort=-v:refname
git -C portanode verify-tag v<version>
```

The second command lists the tags, newest first. The third exits `0` on
a good signature by the current key. To read which key signed, print the
status line `gpg` writes for it:

```shell
git -C portanode verify-tag --raw v<version> 2>&1 | grep VALIDSIG
```

The last field of that line is the fingerprint of the primary key. Compare
it, spaces aside, with the primary key under *Who signs the tags*. The
field after `VALIDSIG` is the key that made the signature, here the
subkey. It is `gpg`'s status line for programs, so the language of `gpg`'s
messages does not change it. `gpg` also warns that the key is not
certified with a trusted signature until you certify the key yourself;
the fingerprint is what decides. Without the key imported,
`git verify-tag` exits `1`.

Then put the folder at that tag:

```shell
git -C portanode checkout v<version>
```

To move to a later release, fetch the tags, and verify the new one before
checking it out:

```shell
git -C portanode fetch --tags origin
git -C portanode verify-tag v<version>
```

GitHub checks the same signature against the keys on the maintainer's
account. That is GitHub's word; `git verify-tag` against the key you
checked is your own.

### A tag signed by the revoked key

For `v2026.10.17` and the tags before it, `git verify-tag` exits `1`:
`gpg` warns that the key has been revoked, and git does not count a
revoked key's signature as good. The signature itself can still be good.
Read the status lines:

```shell
git -C portanode verify-tag --raw v<version> 2>&1 | grep -E 'REVKEYSIG|VALIDSIG'
```

`REVKEYSIG` says the signature is good and the key is revoked. On
`VALIDSIG`, the first fingerprint must be the revoked subkey and the last
field the revoked primary key, both under *The revoked key*. The date
after the first fingerprint is when the signer says the signature was made.
It must be before 2026-10-19. A date from the signer is not proof, so also
read what GitHub recorded when the tag was pushed:

```shell
sha=$(git -C portanode rev-parse v<version>)
gh api repos/btclib-org/portanode/git/tags/"$sha" \
  --jq '.verification | {verified, reason, verified_at}'
```

`verified_at` is GitHub's own date.

## What the signature does not cover

The tag covers the scripts and the configuration in this repository. The
Bitcoin Core and Electrum binaries are not in it: the updaters download
them from their publishers and check those publishers' signatures, which
*Updating Binaries* in `README.md` describes.

The key and this file both come from GitHub, so whoever controls the
maintainer's account controls both. `ASSURANCE_CASE.md` names that risk.
