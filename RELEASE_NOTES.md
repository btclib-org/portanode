# Release notes

Notable changes are documented here.
[CHANGELOG.md](./CHANGELOG.md) is the record behind them: this file says
what a user has to act on, that one says what changed and why.

Versions are *[calendar versions](https://calver.org/)*, `YYYY.MM.DD`,
and `VERSION` holds the string a release is cut at. The number says when
the folder was assembled, which is the useful thing to know about a
bundle of somebody else's binaries; it promises nothing about
compatibility, so anything that has to be done by hand on an existing
folder — a datadir that must be moved, a key that must be re-imported, a
launcher that has been renamed — is announced here rather than left to be
discovered on the next double-click.

## [2026.01.29] - git main branch, not released yet

**An update now refuses to install a binary it could not verify.** Both
platforms' update scripts abort unless the download carries a valid PGP
signature from a key already in your keyring; before, a missing `gpg` or
a missing key warned and installed anyway. Import the publisher's key
before the next update — `README.md`'s *Updating Binaries* has where each
comes from — or set `PORTANODE_ALLOW_UNVERIFIED=1`, which installs
unauthenticated binaries and is there for the case where that is a
considered decision rather than an accident.

`keys/electrum.fingerprints` pins the Electrum release key, so an
Electrum download signed by any other key is refused even with the key
imported. `keys/bitcoin-core.fingerprints` pins nothing, Core's
`SHA256SUMS` being signed by many independent builders; add the
fingerprints of the builders you choose to trust if you want that
half pinned too.

**The regtest clean launchers now stop and ask.** Every one of them waits
for a confirmation before deleting a datadir, where some deleted first
and one asked nothing at all. On macOS they also refuse to wipe a datadir
a running node is using, `rm -rf` under a live node being how that node's
data gets corrupted rather than reset.

**Updates now stage on the local disk** and copy only the finished
binaries onto the removable volume, so a `%TEMP%` or an APFS `mktemp`
directory needs the room the download used to take on the folder itself.
The macOS copy re-reads what it wrote and retries until it matches, which
is what the exFAT corruption this works around asked for.

## [2026.01.27] - Initial Release

The first release. Nothing to act on: there was no earlier folder to
upgrade from.
