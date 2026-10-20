# Assurance case

`README.md` tells a user what PortaNode does, and its *Limitations, not
vulnerabilities* states what it does not protect. This page argues why
the rest holds: what is defended and against whom, where input enters,
which trust boundaries the launchers cross, and how each threat is
countered or why it is accepted. Where `README.md` already states a fact,
this page points to it. Where a countermeasure is still owed, it cites
the open issue.

## What is claimed

- **A launcher runs the folder's own binaries on the folder's own data.**
  It resolves the root from its own location, and runs Bitcoin Core or
  Electrum from the platform's `bin/` with a data directory under the
  root (`CLAUDE.md`'s *What is in the tree, and what is not*).
- **An update installs only what its publisher signed.** The updaters
  refuse a download whose PGP signatures do not satisfy
  `keys/*.fingerprints`, as `README.md`'s *PGP verification fails closed*
  says. The open issues under *The publishers and `bin/`* below are where
  it falls short.
- **An installed binary that changes is detected.** `checksums.sha256`
  records each binary after a verified install, and `verify-binaries`
  and the rollbacks check against it.
- **A release of this repository is what the maintainer signed.**
  `VERIFYING.md` says how to check it.

## Threat model

PortaNode is a folder of launchers on a portable drive. It runs no
service of its own: what talks to the network is Bitcoin Core and
Electrum, which the launchers start, and the updaters' downloads. The
launchers run with the rights of the user who starts them; none asks
for more.

**What is defended.**

- The integrity of the Bitcoin Core and Electrum binaries in `bin/`,
  against a download that is not the publisher's.
- The integrity of the launchers, against a copy of the repository that
  is not the maintainer's.
- The wallets and the node's data, against a launcher that deletes or
  opens the wrong folder's.
- The privacy of an Electrum wallet's addresses, for a user who chooses
  `mainnet-local-server-only`.

**The adversaries.**

- Whoever sits between the updaters and the publishers: a hostile
  network, a compromised mirror, or a compromised download server.
- Whoever serves a copy of this repository that is not the maintainer's,
  or takes over the maintainer's GitHub account.
- Another account or process on the machine the drive is plugged into.
- Whoever finds or takes the drive.
- The public Electrum servers the plain mainnet launcher connects to.

**What is not defended.** Each is stated in `README.md`'s *Limitations,
not vulnerabilities*:

- a key imported into your own keyring that is not the publisher's;
- an update installed with verification switched off;
- the data on a drive that is lost or stolen;
- the corruption risk Bitcoin Core warns of on exFAT under macOS;
- launchers that are not signed or notarized, so the operating system
  cannot tell them from an attacker's script.

Nor is the machine the drive is plugged into. The launchers run as its
user, and an administrator or malware there can read and change every
file on the drive.

## Entry points

- **The folder itself**, taken by `git clone` or as a ZIP (`README.md`'s
  *Getting the folder*). `VERIFYING.md` checks a clone at a release tag.
- **The launchers a user runs**: the `Bitcoin-Launcher.*`,
  `Electrum-Launcher.*` and `Utilities-Launcher.*` menus at the root, and
  the scripts under `macos/scripts/`, `win/scripts/` and `linux/scripts/`
  they reach (`README.md`'s *Launcher Notes*).
- **The environment.** This lists every variable the scripts read with a
  `PORTANODE_` prefix:

    ```shell
    git grep -h -o -E 'PORTANODE_[A-Z_]+' \
      -- '*.sh' '*.command' '*.bat' '*.ps1' | sort -u
    ```

- **The network, through the updaters.** Only the updaters, and on
  Windows the `latest-*-version.ps1` helpers they call, download
  anything; they reach `bitcoincore.org` and `download.electrum.org`.
  This lists the scripts that call a downloader:

    ```shell
    git grep -l -E 'curl |Invoke-WebRequest' \
      -- '*.sh' '*.command' '*.bat' '*.ps1'
    ```

- **The user's GPG keyring and `keys/*.fingerprints`**, which together
  decide what an update accepts.
- **The files on the drive** that the launchers and the binaries read:
  `bin/`, `checksums.sha256`, `bitcoin-datadir/bitcoin.conf`, and
  Electrum's own configuration in `electrum-datadir/`.
- **The ports and sockets the binaries open**: Bitcoin Core's P2P port,
  its RPC where it is on (the regtest Qt launchers pass `-server`, the
  regtest `-cli` launchers run `bitcoind`, which turns it on itself, and
  `bitcoin.conf` sets it on no network), Electrum's connections to its
  servers, and Electrum's daemon RPC: a unix socket, `daemon_rpc_socket`,
  in the network's datadir (`electrum-datadir/` on mainnet, a subdirectory
  on the others) on macOS and Linux, and a TCP port on `127.0.0.1` on
  Windows (`README.md`'s *Choosing a filesystem*).

## Trust boundaries

**This repository and your folder.** A copy of the folder is trusted
once its release tag verifies (`VERIFYING.md`). The tag and the key both
come from GitHub, so a takeover of the maintainer's account could
replace both. That is accepted: for a user who checked the fingerprint
once, a tag signed by another key prints another fingerprint.
`tag-integrity` does not by itself make a tag signed (`REPOSITORY.md`'s
*Rulesets*); `RELEASING.md` reads each tag's signature back after
cutting it. A ZIP carries no signature, and is outside this boundary.

**The publishers and `bin/`.** A download crosses here, and is trusted
only once its signatures verify against the keys `keys/*.fingerprints`
pins, Bitcoin Core asking for several builders and Electrum for its
release key (`README.md`'s *Updating Binaries*). Which key is the
publisher's is yours to establish, as *Limitations, not
vulnerabilities* says, and so is the decision to switch verification
off ([ISS 670] is to remove that switch). Open issues where this
boundary is weaker than claimed:

- [ISS 668]: macOS `update-bitcoin` can install a `Bitcoin-Qt.app` zip
  that `SHA256SUMS` does not list.

The updaters refuse a version older than the installed one, or one that
is not digits and dots, unless `--allow-downgrade` is passed
(`refuse_downgrade` in `shared/utilities/lib.sh`, and
`win/scripts/utilities/compare-versions.ps1`). On macOS and Linux they
fetch through `curl_https`, which allows HTTPS only on the request and on
every redirect (`--proto '=https' --proto-redir '=https'`).

The Windows updaters refuse a file `Get-FileHash` cannot read, compare
the hash and path fields of a checksum line whole, and
`update-bitcoin.bat` looks a name up in `SHA256SUMS` by its exact field.
They download into a fresh
`%TEMP%\portanode-<name>.<GUID>` that `mkdir` creates or the update
stops, and run with `System32` as the current directory, so a `gpg.bat`
or `powershell.bat` planted in the folder is not run.

**`bin/` and what runs.** `checksums.sha256` records integrity, not
authenticity (*Limitations, not vulnerabilities*). What it does not yet
cover is [ISS 658] (the rest of a macOS app bundle) and [ISS 659]
(symlinks in `tree_hash`).

**The drive and the machine.** The drive is meant to move between
machines, so it is the perimeter: *The folder is unencrypted, and it is
portable* says what protects the data on it. `set-permissions` restricts
the data directories to the owner where the filesystem stores
permissions, and cannot on exFAT (`README.md`'s *Security Notes*).
`bitcoin.conf` sets `server=1` on no network, so a mainnet Qt node opens
no RPC and writes no `.cookie`. The regtest Qt launchers pass `-server`
and the regtest `-cli` launchers run `bitcoind`, which turns RPC on and
writes a `.cookie` itself, so on regtest RPC is open to local processes,
with a `.cookie` exFAT cannot protect.
`bitcoin.conf`'s `[secrets]` comment says where local secrets
belong. Bitcoin Core binds RPC to the loopback interface
unless `rpcbind` and `rpcallowip` both say otherwise.

**The launcher and its environment.** The root a launcher resolves
decides which binaries and which data it uses. A set
`PORTANODE_ROOT` has to pass the probe the walk applies, a `VERSION`
beside `macos/`, `win/` or `linux/`, or the launcher stops. An Alice
`-clean` launcher deletes regtest data only when it finds no node
running on it. On macOS and Linux it reads each argument of a command
line whole (`regtest_node_running_on` in `shared/lib.sh`).

The mainnet launcher refuses to start while a mainnet node is running.
It reads a node's flags as whole arguments, so a path holding
`-regtest` is not the flag. On macOS and Linux a network flag read as
true anywhere on the line selects that network, where Bitcoin Core reads
only the last value, so `-testnet -testnet=0` can hide a mainnet node;
a path with a space before a flag-shaped word still reads as the flag.
On Windows the last value wins, as in Core (`node-args.ps1`). Bitcoin
Core itself refuses a second node on one data directory.

**Electrum and its servers.** The plain `mainnet` launcher uses
Electrum's own server choice, and `mainnet-local-server-only` talks to a
server on this machine only. `README.md`'s *Electrum* says what each
reveals.

## Secure design principles

Saltzer and Schroeder's principles, as they apply to launchers.

- **Fail-safe defaults.** An update that cannot be verified is refused:
  no `gpg`, no good signature, too few pinned signers, or a pin file that
  lists no key. `keys/bitcoin-core.fingerprints` ships with no key, so a
  fresh clone installs no Bitcoin Core until its user chooses the
  builders to trust.
- **Economy of mechanism.** The macOS and Linux scripts share one
  library, `shared/`, for the root walk (`resolve_root` in
  `shared/lib.sh`), the PGP check (`pgp_verify_or_fail`) and the checksum
  bookkeeping (`update_checksum`, `verify_checksum_entry`), both in
  `shared/utilities/lib.sh`. The Windows half is a separate
  implementation, kept in step by review (`REVIEWING.md`'s *Does the
  change reach the other platforms?*).
- **Least privilege.** The launchers ask for no rights beyond their
  user's (*Threat model*), and only the updaters reach the network
  themselves (*Entry points*).
- **Open design.** Every launcher is a short script in the tree, and the
  limitations are published (*Limitations, not vulnerabilities*).
- **Psychological acceptability.** The private Electrum path is a menu
  entry of its own, `mainnet-local-server-only`, rather than a setting
  to find.

## Common implementation weaknesses

Weaknesses from MITRE's CWE list that scripts of this kind are exposed
to, and what counters each.

- **Download of code without integrity check (CWE-494).** PGP
  verification before install, then `checksums.sha256`, as above. Its
  open gaps are the issues under *The publishers and `bin/`*.
- **Improper verification of a signature (CWE-347).** The PGP check
  reads `gpg`'s status lines, not its exit code, and counts only distinct
  pinned keys with a good signature (`pgp_verify_or_fail` in
  `shared/utilities/lib.sh`, and `win/scripts/utilities/lib.bat`).
- **Untrusted search path (CWE-426).** The Windows updaters and
  utilities leave the folder for `System32` before they run `gpg`,
  `powershell` or another command by bare name.
- **Insecure temporary file (CWE-377).** The macOS and Linux updaters
  download into a fresh `mktemp -d` directory, the Windows ones into a
  fresh `%TEMP%\portanode-<name>.<GUID>`.
- **Cleartext transmission (CWE-319).** Every download URL is `https`,
  and on macOS and Linux a redirect to another scheme is refused
  (`curl_https`). The Windows updaters' `Invoke-WebRequest` calls are
  not known to refuse one: [ISS 695].
- **Improper neutralization of output (CWE-150).** [ISS 629]: the log
  monitors print `debug.log` lines to the terminal unfiltered.
- **Shell defects.** `shellcheck` reads every `.sh` and `.command`
  script as a hook of the lint gate, which `lint.yml` runs on every pull
  request (`CONTRIBUTING.md`'s last section). The required `Script security`
  check runs a security analysis on the `.bat` and `.ps1` halves
  ([ISS 644]).
- **Secrets in the tree.** `detect-secrets` runs as a hook of the lint
  gate, against `.secrets.baseline`.

[ISS 629]: https://github.com/btclib-org/portanode/issues/629
[ISS 644]: https://github.com/btclib-org/portanode/issues/644
[ISS 658]: https://github.com/btclib-org/portanode/issues/658
[ISS 659]: https://github.com/btclib-org/portanode/issues/659
[ISS 668]: https://github.com/btclib-org/portanode/issues/668
[ISS 670]: https://github.com/btclib-org/portanode/issues/670
[ISS 695]: https://github.com/btclib-org/portanode/issues/695
