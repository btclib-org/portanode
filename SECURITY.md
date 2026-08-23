# Security policy

## Reporting a vulnerability

If you have found a security vulnerability, please do not open a GitHub
issue: an issue is public from the moment it is filed, and so is the
window between filing it and a fix being released.

Use [*Report a vulnerability*][advisory] instead. It opens a private
advisory visible to the maintainers alone, and it is a thread you are in
— what is asked and what is fixed reaches you without anybody having to
remember to write.

[advisory]: https://github.com/btclib-org/portanode/security/advisories/new

If you would rather not, or the form does not open for you, email
*security at btclib dot org*. An address needs no GitHub account and no
repository setting to work, which is why it is kept beside the button
rather than replaced by it.

## What belongs here, and what belongs upstream

This project starts somebody else's binaries from a folder. What belongs
here is what the scripts around them decide:

- **the install path.** How a download is fetched, what signature it is
  held to, what makes verification pass, and what is written to disk
  before it has passed. A path that installs a binary whose signature did
  not verify is the defect this repository exists to prevent.
- **the pinning.** `keys/electrum.fingerprints` and
  `keys/bitcoin-core.fingerprints` decide which signers are accepted; a
  change that widens either, or that makes an empty list mean "accept
  anything" rather than "require one good signature", is a report.
- **what the launchers expose.** `bitcoin-datadir/bitcoin.conf` is what
  the node is started with, so an rpc binding or a credential handling
  that reaches past the local machine is this repository's.
- **what is left on the volume.** Wallets, cookies and logs live in the
  folder, and the folder is portable by design — a script that widens
  permissions on one of those directories is a report.

What Bitcoin Core or Electrum *does* once started is theirs, and belongs
to [bitcoin/bitcoin](https://github.com/bitcoin/bitcoin/security/policy)
and to [spesmilo/electrum](https://github.com/spesmilo/electrum). So is a
flaw in a binary this repository merely downloads.

Report it wherever you found it, though: routing a report is the
maintainers' job, not the reporter's, and a doubt about which project
owns a flaw is not a reason to keep it to yourself.

## Supported versions

The latest release, and nothing is backported. A folder is upgraded by
replacing the scripts in it — a clone pulled, or the newer release's
source archive unpacked over it — and the binaries under `macos/bin/` and
`win/bin/` are untouched by that, being ignored by git and installed by
the update scripts.

**A folder copied rather than cloned receives nothing automatically.**
That is a supported way to use this, and this is its price: a fix
published here reaches a clone through a `git pull` and reaches a copy
only when somebody replaces the files. `VERSION` is what says which
release a folder is, and it is the file to read before deciding whether
it needs replacing.

## Limitations, not vulnerabilities

These are known and inherent.

- **The trust root is the keys in your own GPG keyring**, and this
  repository cannot establish it for you. `keys/*.fingerprints` pins
  which signer is accepted once a key is imported; it does not say the
  key you imported is the publisher's. Verify a fingerprint against the
  publisher's own site before importing, which is what `README.md`'s
  *Updating Binaries* section asks.
- **`PORTANODE_ALLOW_UNVERIFIED=1` installs unauthenticated binaries**,
  and it is documented rather than removed because the alternative is
  somebody working around the check in a way nobody can see. Setting it
  is a decision, and it is not a defect in the script that obeyed it.
- **`checksums.sha256` is integrity and not authenticity.** It detects a
  binary that changed under you; it says nothing about where the binary
  came from, that being what the PGP step decides. A checksum entry is
  appended only after a verified install, which is what keeps the two
  from being confused.
- **The folder is unencrypted, and it is portable.** Wallets and cookies
  sit on a volume that is meant to be unplugged and carried, so the
  device is the perimeter — full-disk encryption on the volume, or a
  wallet passphrase, is what stands between a lost drive and the coins on
  it. Nothing in this repository provides either.
- **The launchers are not signed or notarized.** macOS Gatekeeper and
  Windows SmartScreen will treat a `.command` or a `.bat` from this
  folder as unrecognised, and the way past that is the same click an
  attacker's script would ask for. Read a launcher before running it;
  they are short and they are all in the tree.
