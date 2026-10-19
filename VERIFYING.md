# Verifying a release

Each release of PortaNode has a signed tag named `v` and the date it was
cut (`RELEASING.md`). Check the tag's signature before you run a
launcher from it: the signature is what says the folder holds what the
maintainer released.

## Who signs the tags

The tags are signed with the OpenPGP key of the maintainer,
[`fametrano`](https://github.com/fametrano), Ferdinando Ametrano:

- primary key: `91D9 67D0 8A2F 3646 A0C4  2ED0 07B5 59B7 1373 BF5D`
- the subkey that signed the tags so far:
  `B115 1204 0C6E 86D7 B5E0  3DD1 4D71 ED3A 9A8E DFC5`

A tag signed by any other key is not a release of this repository until
this file names that key.

## Getting the key

The key is published on the maintainer's GitHub account. Import it, then
check that its fingerprint is the primary key above:

```shell
curl -fsSL https://github.com/fametrano.gpg | gpg --import
gpg --fingerprint 91D967D08A2F3646A0C42ED007B559B71373BF5D
```

That address also serves the maintainer's other keys. Only the one named
above signs the tags.

## Checking a tag

Verify a clone, not a ZIP. The ZIP of `main` and the source archive
GitHub attaches to a release carry no signature.

```shell
git clone https://github.com/btclib-org/portanode.git
git -C portanode tag --sort=-v:refname
git -C portanode verify-tag v<version>
```

The second command lists the tags, newest first. The third exits `0` on
a good signature. To read which key signed, print the status line `gpg`
writes for it:

```shell
git -C portanode verify-tag --raw v<version> 2>&1 | grep VALIDSIG
```

The last field of that line is the fingerprint of the primary key. Compare
it, spaces aside, with the primary key under *Who signs the tags*. The
first field is the key that made the signature, here the subkey. It is
`gpg`'s status line for programs, so the language of `gpg`'s messages does
not change it. `gpg` also warns that the key is not certified with a
trusted signature until you certify the key yourself; the fingerprint is
what decides. Without the key imported, `git verify-tag` exits `1`.

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

## What the signature does not cover

The tag covers the scripts and the configuration in this repository. The
Bitcoin Core and Electrum binaries are not in it: the updaters download
them from their publishers and check those publishers' signatures, which
*Updating Binaries* in `README.md` describes.

The key and this file both come from GitHub, so whoever controls the
maintainer's account controls both. `ASSURANCE_CASE.md` names that risk.
