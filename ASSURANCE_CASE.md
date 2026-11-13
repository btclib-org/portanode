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
  root. `resolve_root` in `shared/lib.sh` resolves the root,
  `CONTRIBUTING.md` gives the path convention, and `README.md`'s
  *Expected Binaries by OS* names what `bin/` holds.
- **An update installs only what its publisher signed.** The updaters
  refuse a download without good PGP signatures from enough of the keys
  in `keys/`, as `README.md`'s *PGP verification fails closed* says. The
  open issues under *The publishers and `bin/`* below are where it falls
  short.
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

- a key in a publisher's repository that is not its signer's;
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
  On Windows each fetch goes through `fetch-https.ps1`, which calls
  `Invoke-WebRequest` itself and `save-response.ps1` for a file. Under
  `pwsh` it fails on a redirect unless it writes a file, as its header
  says; the updaters run under `powershell`. This lists the scripts that
  call a downloader, leaving out comments and messages:

    ```shell
    git grep -E \
      'curl(_https)? |Invoke-WebRequest|HttpWebRequest|fetch-https\.ps1 ' \
      -- '*.sh' '*.command' '*.bat' '*.ps1' ':!tests' \
      | grep -vE '^[^:]+:[[:space:]]*(#|REM |echo )' | cut -d: -f1 | sort -u
    ```

- **The keyrings in `keys/`**, which decide what an update accepts.
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
  Windows (*Why each filesystem is recommended* below).

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
only once its signatures verify against the keyrings in `keys/`, Bitcoin
Core asking for several builders and Electrum for its release key
(`README.md`'s *Updating Binaries*). Which key is its signer's is what
the publishers' repositories establish, as *Limitations, not
vulnerabilities* says.

The updaters refuse a version that is not digits and dots, and one older
than the installed one unless `--allow-downgrade` is passed
(`refuse_downgrade` in `shared/utilities/lib.sh`, and
`win/scripts/utilities/compare-versions.ps1`). On macOS and Linux they
fetch through `curl_https`, which allows HTTPS only on the request and on
every redirect (`--proto '=https' --proto-redir '=https'`), and
`update-bitcoin.sh` takes a `SHA256SUMS` entry only where its name field
equals the file's name, exactly once (`verify_sha256sums`).

The Windows updaters fetch through `fetch-https.ps1`, which follows a
redirect only to HTTPS, refuse a file `Get-FileHash` cannot read, compare
the hash and path fields of a checksum line whole, and
`update-bitcoin.bat` looks a name up in `SHA256SUMS` by its exact field.
They download into a fresh
`%TEMP%\portanode-<name>.<GUID>` that `mkdir` creates or the update
stops, and run with `System32` as the current directory, so a `gpg.bat`
or `powershell.bat` planted in the folder is not run.

**`bin/` and what runs.** `checksums.sha256` records integrity, not
authenticity (*Limitations, not vulnerabilities*). On macOS an app
bundle is recorded and checked whole, by `tree_hash`, which hashes
symlinks too.

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
decides which binaries and which data it uses. A set `PORTANODE_ROOT`
has to pass the probe the walk applies, a `VERSION` beside `macos/`,
`win/` or `linux/`, or the launcher stops. An Alice `-clean` launcher
deletes regtest data only when it finds no node running on it. On macOS
and Linux it reads the command line `ps` prints, which keeps no argument
boundaries, so a flag counts only as a word of its own
(`regtest_node_running_on` in `shared/lib.sh`). On Windows it splits the
command line as the mainnet launcher does, below, and as the Bitcoin
Core releases `README.md`'s *Version Compatibility* supports split it.
On every platform it also reads the network from `bitcoin.conf`, or the
file `-conf` names, and from the files they include. It reads them for
every node that names a `-datadir`, as Bitcoin Core reads them for a
node on the launcher's own data directory, and as they are now, not as
they were when the node started. Where it cannot read one that Core
would read, it stops, unless the node's `-datadir` is known to name
another directory. Where its own data directory exists, it resolves that
directory and the node's `-datadir` and compares the two, so a junction,
a symbolic link or another spelling of the path does not hide a node,
and a node's `-datadir` that is relative or does not resolve stops it as
a node on the directory does. On Windows, where the two final paths
differ, the directories still match by volume serial number and file
index. Where its own data directory does not resolve and is not known to
be missing, any regtest node's `-datadir` that does not spell it stops
it. On macOS and Linux a node's `-datadir` is read up to each following
space in turn, and counts as resolving only where a reading that ends
before a word starting with `-`, or at the end of the line, resolves. A
`-datadir` holding a space followed by `-` that does not resolve, where
its part before that space does, reads as the directory that part names.

The mainnet launcher refuses to start while a mainnet node is running.
It reads a node's flags as whole arguments, so a path holding
`-regtest` is not the flag. Like Bitcoin Core, it reads no flag after a
lone `-`. On macOS and Linux a network flag read as true before a lone
`-` selects that network, where Core reads only the last value, so
`-testnet -testnet=0` can hide a mainnet node; a path with a space
before a flag-shaped word still reads as the flag. There a node under
`/Volumes/My - Drive` reads as one with no network flag and, up to that
`-`, no `-datadir`. So it counts, unless it is a `bitcoind` whose own
configuration files and the default `bitcoin.conf` of the user running
the launcher both select another network (below). On Windows the last
value wins, as in Core (`node-args.ps1`). Bitcoin Core itself refuses a
second node on one data directory.

The mainnet launcher also reads a node's configuration files, as the
Alice `-clean` launcher does, in the node's own data directory: the one
its last `-datadir` names, or, for a `bitcoind` that names none, Bitcoin
Core's default for the user running the launcher. A node whose flags
select mainnet does not count where the files select testnet3, testnet4,
signet or regtest. It still counts where they select more than one
network or an unknown one, or cannot be read, and where its `-datadir`
is relative. A `bitcoin-qt` that names no `-datadir` counts too: it may
use the directory its own settings store, which the launcher does not
read ([ISS 944](https://github.com/btclib-org/portanode/issues/944)). On
macOS and Linux the files have to select another network both with the
flags up to each lone `-` and with all of them. The files are read as
they are now, so a mainnet node whose files have selected another
network since it started does not count. On macOS and Linux neither does
another user's `bitcoind` with no `-datadir` where the launcher's user
has a default `bitcoin.conf` selecting another network, nor a node whose
`-datadir` or `-conf` holds a space followed by `-` where the part
before that space names a directory or a file selecting another network.

**Electrum and its servers.** The plain `mainnet` launcher uses
Electrum's own server choice, and `mainnet-local-server-only` talks to a
server on this machine only. `README.md`'s *Electrum* says what each
reveals.

## Why each filesystem is recommended

`README.md`'s *Choosing a filesystem* gives the filesystem for each set
of operating systems. This is why.

- **APFS, NTFS and ext4** are each the filesystem its one operating
  system uses for its own boot disk: full permission bits, a journal,
  and nothing to install.
- **exFAT** is a filesystem macOS and Windows both read and write
  with nothing to install. NTFS needs a third-party driver to write
  from macOS, and APFS is unreadable outside macOS, so exFAT answers
  every pairing that includes macOS, and all three.
- **exFAT stores no Unix mode.** macOS reports every file executable whatever
  `chmod` asked, as `CONTRIBUTING.md`'s *Conventions and measurements the tree
  relies on* measures. Ubuntu's exFAT driver computes the mode from the mount's
  `fmask`, which defaults to the mounting process's umask, so an `fmask` that
  clears the owner's execute bit stops the launchers.
  `linux/scripts/utilities/set-permissions.sh` carries that measurement.
- **exFAT cannot hold Electrum's daemon socket on macOS and Linux.**
  There the daemon's RPC channel is a unix socket in the datadir, and
  exFAT refuses the bind: `ENOTSUP` on macOS, `EPERM` under Ubuntu's
  kernel driver, `EIO` under `exfat-fuse`. A wallet file is still
  written; every command reaching it afterwards fails. The Electrum
  launchers there make the same bind before starting Electrum, and
  their comments say why.
- **Windows is not affected.** Electrum's RPC channel there is a TCP
  port on `127.0.0.1`. On an exFAT volume, creating a wallet, starting
  the daemon, `load_wallet` and `getbalance` each answer as they do on
  NTFS, so the Windows launchers make no such check.
- **NTFS answers Windows and Ubuntu** because the Linux kernel's
  in-tree `ntfs3` driver reads and writes it. The kernel documents
  that; it is not measured here. macOS reads NTFS only, so NTFS answers
  no pairing that includes macOS.

Bitcoin Core's warning against exFAT on macOS is accepted, as
*Limitations, not vulnerabilities* in `README.md` says.

## Secure design principles

Saltzer and Schroeder's principles, as they apply to launchers.

- **Fail-safe defaults.** An update that cannot be verified is refused:
  no `gpg`, no keyring in `keys/`, or too few of its keys with a good
  signature. A key in the user's own keyring does not count.
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
  keys of `keys/` with a good signature (`pgp_verify_or_fail` in
  `shared/utilities/lib.sh`, and `win/scripts/utilities/lib.bat`).
- **Untrusted search path (CWE-426).** The Windows updaters and
  utilities leave the folder for `System32` before they run `gpg`,
  `powershell` or another command by bare name. The updaters look `gpg`
  up there and start it by the path found, from inside a folder they
  make for its home in their fresh download folder.
- **Insecure temporary file (CWE-377).** The macOS and Linux updaters
  download into a fresh `mktemp -d` directory, the Windows ones into a
  fresh `%TEMP%\portanode-<name>.<GUID>`.
- **Cleartext transmission (CWE-319).** Every download URL is `https`,
  and a redirect to another scheme is refused (`curl_https`, and
  `win/scripts/utilities/fetch-https.ps1`).
- **Improper neutralization of output (CWE-150).** The log monitors
  escape control characters in the `debug.log` lines they print:
  `README.md`'s *Logs and Debugging* says which (`escape_controls` in
  `shared/lib.sh`, and `win/scripts/utilities/monitor-bitcoin-log.ps1`).
- **Shell defects.** `shellcheck` reads every `.sh` and `.command`
  script as a hook of the lint gate, which `lint.yml` runs on every pull
  request (`CONTRIBUTING.md`'s last section). The required `Script security`
  check runs a security analysis on the `.bat` and `.ps1` halves
  (`script-security.yml`; `REPOSITORY.md`'s *What gates a merge*).
- **Secrets in the tree.** `detect-secrets` runs as a hook of the lint
  gate, against `.secrets.baseline`.
