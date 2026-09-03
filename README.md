# PortaNode

<!-- The badges are what the reader decides with, one property of the
tree per badge, in the three groups btclib-org/.github's README.md
section 2 fixes: what the software is, whether it works, and what the
OpenSSF makes of it. Nothing here is a Python package and there is no
`release.yml`, so the first group is empty, the licence badge with it
-- that one earns its line in the long description an index renders and
in the copy an unpacked sdist carries, neither of which this tree has.
Inside the second the gates come in the order that section lists them --
pre-commit.ci, then the lint workflow -- and the sentinels follow in the
order section 10's calendar schedules them, which is the order and not
the instants: the day and the hour a sentinel owns are that section's
and are not restated here. Which sentinels this tree carries is section
10's record rather than a choice made here, the badge and the workflow
being one membership: `links` is every repository's and the record gives
this tree no other, so there is no Scorecard badge and no
`scorecard.yml` behind it. One badge per line keeps a change to one line
and every line inside MD013. -->
[![pre-commit.ci status](https://results.pre-commit.ci/badge/github/btclib-org/portanode/main.svg)](https://results.pre-commit.ci/latest/github/btclib-org/portanode/main)
[![lint workflow status](https://github.com/btclib-org/portanode/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/btclib-org/portanode/actions/workflows/lint.yml)
[![links workflow status](https://github.com/btclib-org/portanode/actions/workflows/links.yml/badge.svg?branch=main)](https://github.com/btclib-org/portanode/actions/workflows/links.yml)

## Portable (external‑disk‑friendly) cross-platform Bitcoin node

PortaNode bundles scripts, binaries, and data for running Bitcoin Core
(and Electrum) on macOS, Windows and Linux.

If you’ve ever tried running an indexed full Bitcoin node
on a portable external disk shared between several operating systems,
you know the kinds of problems this is meant to address.

It works best on an NVMe drive in a portable USB 3 / Thunderbolt
enclosure, formatted for whichever of macOS, Windows and Ubuntu it has
to run under — see *Choosing a filesystem* below.

## Choosing a filesystem

The right filesystem for the drive depends on which of macOS, Windows
and Ubuntu it has to run under, not on a single default:

| Care about         | Filesystem |
|--------------------|------------|
| macOS only         | APFS       |
| Windows only       | NTFS       |
| Ubuntu only        | ext4       |
| macOS and Windows  | exFAT      |
| macOS and Ubuntu   | exFAT      |
| Windows and Ubuntu | NTFS       |
| All three          | exFAT      |

- **APFS, NTFS and ext4** are each the filesystem the one operating
  system they serve already uses for its own boot disk: full
  permission bits, a journal, and nothing to install. Moving the drive
  to a second operating system later means reformatting it.
- **exFAT** is the filesystem macOS and Windows both read and write
  with nothing to install, and it is the answer for every pairing that
  includes macOS: Windows' own NTFS needs a third-party driver to write
  from macOS, and macOS's own APFS is unreadable outside macOS, so
  neither platform's own filesystem crosses to the other where macOS is
  one of the two. It carries no Unix permission bits, and the two
  platforms that read it do not fail identically on that account: macOS
  synthesises the execute bit as always-on regardless of `chmod`,
  measured by mounting an exFAT image and running a script whose mode
  denies it (`CLAUDE.md`'s *What will otherwise waste a session* has
  the commands), while Ubuntu's own exFAT driver instead computes a mode
  from the mount's own `fmask` — measured the same way, beside the
  macOS bullet in `CLAUDE.md`: a plain mount defaults to `fmask=0022`
  and the script still runs, but a mount raising `fmask` past that
  clears the execute bit and the script fails, a mount option away from
  the guarantee macOS's synthesis gives unconditionally.
- **exFAT on Linux carries a further cost specific to Electrum**: its
  daemon binds a unix domain socket inside `electrum-datadir` for its own
  RPC channel, and every wallet command — `getinfo` included — goes
  through it. Measured on Ubuntu's own kernel exFAT driver, on
  `ubuntu-latest`: the bind fails with `EPERM` (`exfat-fuse` answers
  `EIO` instead, both refusing the same call), `daemon -d` then times out
  waiting for the daemon to be ready, `getinfo` answers `Daemon not
  running`, and no `daemon_rpc_socket` appears in the datadir — where an
  ext4 control on the same runner answers each of those the other way.
  What cannot exist there is the RPC channel rather than the wallet:
  `electrum create` writes its wallet file into such a datadir without
  error — a file parsing as JSON with the same keys as the control's —
  and it is every command reaching that wallet afterwards that has
  nothing to go through. Both volumes measured are loopback images, which
  is as close as a runner gets to a drive plugged into a running machine.
  `linux/scripts/electrum/`'s launchers detect the failing bind before
  starting Electrum and refuse rather than start it silently broken.
- **macOS refuses the same bind.** Measured against a volume made with
  `hdiutil create -fs ExFAT`: the bind answers `ENOTSUP` where the same
  call in a directory on APFS succeeds, and Electrum's daemon then fails
  to start its RPC server on `daemon_rpc_socket` with that errno.
  `macos/scripts/electrum/`'s launchers make the same bind before
  starting Electrum and refuse on it. What cannot exist on such a
  datadir is the RPC channel rather than the wallet: `electrum create`
  writes a wallet file there without error, and it is every command
  reaching that wallet afterwards that has nothing to go through.
- **Windows is not affected.** Electrum binds a TCP port on `127.0.0.1`
  for that channel there instead of a unix socket, so the call that
  fails above is never made. Measured on `windows-latest` against a
  volume `diskpart` formatted `fs=exfat`: creating a wallet, starting
  the daemon, `load_wallet` and `getbalance` each answer as they do
  against an NTFS control on the same runner, and the daemon's own log
  names the socket it bound as `socktype=tcp`.
  `win/scripts/electrum/`'s launchers carry no such check.
- **NTFS** read-write from Ubuntu is the kernel's own in-tree `ntfs3`
  driver, documented by the kernel rather than measured here; from
  macOS, NTFS is read-only without a third-party driver, which is why
  it does not answer any pairing that includes macOS.

## Prerequisites

- **Operating System**: fairly recent macOS, Windows or Linux versions.
- **Disk Space**: At least 700GB free for Bitcoin Core data (mainnet) full sync.
  Pruned mainnet, regtest and testnet require less. Below 100GB free
  `validate-setup` fails outright, whatever the network and whether or not
  pruning is on.
- **Permissions**: Ensure the external disk is mounted and writable. A folder
  taken by either route in *Getting the folder* below needs nothing made
  runnable by hand: the launchers carry the executable bit in the repository
  and both routes keep it, and an exFAT volume reports every file as
  executable whatever its mode. A folder that reached the disk some other way
  is under *Troubleshooting*.
- **Dependencies**: None required beyond standard OS tools. For advanced use,
  ensure Python (for Electrum) and command-line tools are available.

## Getting the folder

Take it onto the disk it will run from, by either route:

```shell
git clone https://github.com/btclib-org/portanode.git
```

or unzip the ZIP of `main` the repository page offers. Both keep the
executable bit the launchers carry in the repository, which is what
*Prerequisites*' **Permissions** bullet above is about; a folder that
reached the disk any other way is under *Troubleshooting*.

Where on the disk it sits is free. A launcher walks up from its own
location to the `VERSION` file that marks the root, and reads
`PORTANODE_ROOT` before it walks at all — *Environment Overrides* below.

## Quick Start

1. Mount your external disk and navigate to the PortaNode folder.
1. For macOS: Double-click `Bitcoin-Launcher.command`,
   `Electrum-Launcher.command`, or `Utilities-Launcher.command`.
1. For Windows: Double-click `Bitcoin-Launcher.bat`,
   `Electrum-Launcher.bat`, or `Utilities-Launcher.bat` (or the matching
   `.ps1` from PowerShell).
1. For Linux: run the script for the network and mode you want directly
   from a shell, e.g. `bash linux/scripts/bitcoin/mainnet-8333-qt.sh` —
   the root `Bitcoin-Launcher.sh`, `Electrum-Launcher.sh` and
   `Utilities-Launcher.sh` do not yet reach `linux/scripts/`, so there is
   no numbered menu on this platform yet.
1. On macOS or Windows, pick the numbered menu entry for the network
   and mode you want.
1. Follow on-screen prompts (e.g., confirm data deletion for clean scripts).

## Launcher Notes

- `Bitcoin-Launcher.*`, `Electrum-Launcher.*` and `Utilities-Launcher.*`
  are the entry points on macOS and Windows: one file per task, with a
  numbered menu reaching every per-network script under `macos/scripts/`
  and `win/scripts/`. The same names exist as `.sh` files at the root
  for Linux too, but each currently refuses to run rather than
  reaching `linux/scripts/`, which is run by its own path instead — see
  *Quick Start* above.
- `.command` files are intended for double‑clicking in Finder on macOS.
- The root `.sh` files dispatch to the `.command` or `.bat` menu of
  whichever platform they detect, run from a shell (macOS directly, or
  Windows through MSYS/Cygwin); `linux/scripts/`'s own `.sh` files are
  outside that dispatch and are each run directly.
- `.bat` files are intended for Command Prompt/PowerShell on Windows.
- `.ps1` files are intended for PowerShell on Windows (menu-based, same options
  as `.bat`).

## Folder Structure

- `macos/`
    - `bin/`: macOS binaries for Bitcoin Core and Electrum (e.g.,
      `Bitcoin-Qt.app/`).
    - `bin/backup/`: macOS backups created by update scripts.
    - `checksums.sha256`: macOS checksums (versioned).
    - `scripts/`
        - `bitcoin/`: Bitcoin Core launch scripts (.command). See
          `macos/scripts/bitcoin/README.md`.
        - `electrum/`: Electrum launch scripts (.command). See
          `macos/scripts/electrum/README.md`.
        - `utilities/`: macOS maintenance scripts (updates, verification, cleanup,
          logs).

- `win/`
    - `bin/`: Windows binaries (e.g., `electrum.exe`).
    - `bin/backup/`: Windows backups created by update scripts.
    - `checksums.sha256`: Windows checksums (versioned) at `win/checksums.sha256`.
    - `scripts/`
        - `bitcoin/`: Bitcoin Core launch scripts (.bat). See
          `win/scripts/bitcoin/README.md`.
        - `electrum/`: Electrum launch scripts (.bat). See
          `win/scripts/electrum/README.md`.
        - `utilities/`: Windows maintenance scripts (updates, verification, cleanup,
          logs).

- `linux/`
    - `bin/`: Linux binaries for Bitcoin Core and Electrum (e.g.,
      `electrum.AppImage`).
    - `bin/backup/`: Linux backups created by update scripts.
    - `checksums.sha256`: Linux checksums (versioned) at
      `linux/checksums.sha256`.
    - `scripts/`
        - `bitcoin/`: Bitcoin Core launch scripts (.sh). See
          `linux/scripts/bitcoin/README.md`.
        - `electrum/`: Electrum launch scripts (.sh). See
          `linux/scripts/electrum/README.md`.
        - `utilities/`: Linux maintenance scripts (updates, verification,
          cleanup, logs).

- `bitcoin-datadir/`: Bitcoin Core configuration/data (e.g., `bitcoin.conf`).
- `electrum-datadir/`: Electrum data (wallets, regtest/testnet data).

## Detailed Setup

### Bitcoin Core

- **Mainnet**: `Bitcoin-Launcher.*`'s menu runs `mainnet-8333-qt` (GUI).
- **Testnet3**: `Bitcoin-Launcher.*`'s menu runs `testnet3-18333-qt`.
- **Testnet4**: `Bitcoin-Launcher.*`'s menu runs `testnet4-48333-qt`.
- **Regtest**: `Bitcoin-Launcher.*`'s menu runs the `regtest-*` scripts,
  GUI or CLI, for Alice, Bob and Carol. Clean entries reset data before
  starting.
- Data is stored in `bitcoin-datadir/`. Configure via `bitcoin.conf`.
- On Linux, the same script names are under `linux/scripts/bitcoin/`
  with a `.sh` extension, run directly rather than through a menu.

### Electrum

- **Mainnet**: `Electrum-Launcher.*`'s menu runs `mainnet` or
  `mainnet-local-server-only` (connects to local server).
- **Testnet3**: `Electrum-Launcher.*`'s menu runs `testnet3`.
- **Testnet4**: `Electrum-Launcher.*`'s menu runs `testnet4`.
- **Regtest**: `Electrum-Launcher.*`'s menu runs `regtest`.
- Data in `electrum-datadir/`. Wallets are in `wallets/`.
- On Linux, the same script names are under `linux/scripts/electrum/`
  with a `.sh` extension, run directly rather than through a menu.

### Environment Overrides

Set `PORTANODE_ROOT` to customize the root path (e.g., if moving the folder):

- macOS or Linux: `export PORTANODE_ROOT=/path/to/portanode`
- Windows: `set PORTANODE_ROOT=C:\path\to\portanode`

## Updating Binaries

- On macOS, update using `./macos/scripts/utilities/update-bitcoin.sh` or
  `./macos/scripts/utilities/update-electrum.sh`; on Windows, use
  `win/scripts/utilities/update-bitcoin.bat` or
  `win/scripts/utilities/update-electrum.bat`; on Linux, use
  `linux/scripts/utilities/update-bitcoin.sh` or
  `linux/scripts/utilities/update-electrum.sh`. Each platform's updater
  backs up the version it replaces, verifies the download's PGP
  signature, and records the new binary's checksum.
- Rollback with `./macos/scripts/utilities/rollback-bitcoin.sh` or
  `./macos/scripts/utilities/rollback-electrum.sh` on macOS,
  `win/scripts/utilities/rollback-bitcoin.bat` and
  `win/scripts/utilities/rollback-electrum.bat` on Windows, or
  `linux/scripts/utilities/rollback-bitcoin.sh` and
  `linux/scripts/utilities/rollback-electrum.sh` on Linux, if an update
  causes issues. Rollback needs the backup an update created, so it is
  only available after one has run.
- Validate setup with `./macos/scripts/utilities/validate-setup.sh`,
  `win/scripts/utilities/validate-setup.bat`, or
  `linux/scripts/utilities/validate-setup.sh` after updating, and test
  with the regtest scripts.
- **PGP verification fails closed.** Update scripts abort the install unless the
  download carries a valid PGP signature. This requires `gpg` to be installed
  and the signer's key imported: a detached signature file typically carries
  no public key, so `gpg` can validate only against a key already in the
  local keyring, and a missing key — not a missing signature — is the usual
  cause of a validation failure. To bypass (installs UNAUTHENTICATED
  binaries — not recommended), set `PORTANODE_ALLOW_UNVERIFIED=1` in the
  environment.
    - **Bitcoin Core signing keys**: obtain builder keys from
      [bitcoin-core/guix.sigs](https://github.com/bitcoin-core/guix.sigs/tree/main/builder-keys)
      and import with `gpg --import`.
    - **Electrum signing key**: obtain the release signing key from electrum.org
      (Download page) and import with `gpg --import`.
    - **Key pinning**: `keys/electrum.fingerprints` and
      `keys/bitcoin-core.fingerprints` list pinned signer fingerprints. If a file
      lists any fingerprint, the matching download must be signed by one of those
      keys. Electrum ships pinned to its release key; the Bitcoin Core list is a
      template you can populate with the builders you choose to trust (without it,
      any imported builder key that signed `SHA256SUMS` is accepted).
- **If an updater cannot run** — no network access to bitcoincore.org or
  electrum.org, or a release the updater's scraper does not find — download
  the binary by hand from
  [bitcoincore.org](https://bitcoincore.org/en/download/) or
  [electrum.org](https://electrum.org/#download) and verify its checksum
  against the official source yourself, then replace `macos/bin/`
  (`Bitcoin-Qt.app`, or the command-line tools `macos/bin/README.md` lists),
  `win/bin/` (`bitcoin-qt.exe`, `bitcoind.exe`, `bitcoin-cli.exe`,
  `bitcoin-tx.exe`, `bitcoin-util.exe`, `bitcoin-wallet.exe`, `bitcoin.exe`),
  or `linux/bin/` (`bitcoin-qt`, `bitcoind`, `bitcoin-cli`, `bitcoin-tx`,
  `bitcoin-util`, `bitcoin-wallet`, `bitcoin`) for Bitcoin Core, or
  `macos/bin/Electrum.app/`, `win/bin/electrum.exe`, or
  `linux/bin/electrum.AppImage` for Electrum. The Windows file to fetch is
  Electrum's standalone `electrum-<version>.exe`: the portable build of the
  same release keeps its data directory under whichever directory a
  launcher was started from and discards the `--dir` the launchers pass, so
  `win/scripts/electrum/`'s launchers refuse it. A hand-replaced binary
  carries no updater backup and no checksum entry, so rollback and
  `validate-setup`'s checksum check do not see it until an updater run
  records one.
- **Checksums**: `macos/checksums.sha256`, `win/checksums.sha256` and
  `linux/checksums.sha256` keep ever-growing lists of acceptable hashes
  labeled by version; update scripts append a new entry (only after a
  successful PGP verification) and never rewrite an existing one. These
  files provide **integrity and rollback**
  checks (detecting corruption/tampering of an already-installed binary), not
  authenticity — authenticity comes from the PGP step above. Where to get each
  project's signing key is the *PGP verification fails closed* bullet above.

### Expected Binaries by OS

- **macOS (`macos/bin/`)**: `Bitcoin-Qt.app/`, `Electrum.app/`, and the Bitcoin
  Core command-line tools (see `macos/bin/README.md`)
- **Windows (`win/bin/`)**: `bitcoin-qt.exe`, `bitcoind.exe`, `bitcoin-cli.exe`,
  `bitcoin-tx.exe`, `bitcoin-util.exe`, `bitcoin-wallet.exe`, `bitcoin.exe`,
  `electrum.exe` (see `win/bin/README.md`)
- **Linux (`linux/bin/`)**: `bitcoin-qt`, `bitcoind`, `bitcoin-cli`,
  `bitcoin-tx`, `bitcoin-util`, `bitcoin-wallet`, `bitcoin`,
  `electrum.AppImage`

## Troubleshooting

### Common Issues

- **Script fails with "Binary not found"**: Ensure binaries are in
  `macos/bin/`, `win/bin/` or `linux/bin/`. Check permissions.
- **Permission denied on macOS**: The folder reached this disk through
  something that dropped the executable bit — a copy, or an archive
  unpacked by a tool that does not restore it. `chmod +x` the launcher you
  ran, or take the folder again by either route in *Getting the folder*,
  both of which keep it.
- **"The ... path uses exFAT" warning on macOS**: expected, from
  Bitcoin Core itself, not from a launcher here — see *Limitations, not
  vulnerabilities* below.
- **Disk space errors**: Free up space or use pruning in `bitcoin.conf`
  (`prune=550` for ~550MB blocks).
- **Sync issues**: Check logs in `bitcoin-datadir/debug.log` for mainnet,
  or `bitcoin-datadir/<network>/debug.log` for testnet3, testnet4 or
  regtest. For Electrum, check console output.
- **Regtest not connecting**: Ensure all regtest scripts are run (Alice, Bob,
  Carol) and ports are open.
- **Path errors**: If moved, use `PORTANODE_ROOT` or adjust scripts.

### Logs and Debugging

- Bitcoin: `bitcoin-datadir/debug.log` for mainnet, or
  `bitcoin-datadir/<network>/debug.log` for testnet3, testnet4 or
  regtest.
- Electrum: Check terminal output or `electrum-datadir/` for logs.
- Run scripts from terminal for verbose output: `bash
  macos/scripts/bitcoin/mainnet-8333-qt.command`,
  `win/scripts/bitcoin/mainnet-8333-qt.bat`, or
  `bash linux/scripts/bitcoin/mainnet-8333-qt.sh`.
- Rotate logs: `./macos/scripts/utilities/rotate-bitcoin-log.sh`,
  `win/scripts/utilities/rotate-bitcoin-log.bat`, or
  `./linux/scripts/utilities/rotate-bitcoin-log.sh`
- Monitor logs: `./macos/scripts/utilities/monitor-bitcoin-log.sh`,
  `win/scripts/utilities/monitor-bitcoin-log.bat`, or
  `./linux/scripts/utilities/monitor-bitcoin-log.sh` (run periodically to
  check for errors). Under `cron`, `launchd` or Task Scheduler, add
  `--no-notify` (or set `PORTANODE_NO_NOTIFY=1`) to suppress the desktop
  notification, which a headless or logged-out session cannot show and
  which blocks on Windows until someone dismisses it.
- Health check: `./macos/scripts/utilities/health-check.sh`,
  `win/scripts/utilities/health-check.bat`, or
  `./linux/scripts/utilities/health-check.sh`

### Getting Help

- Check [Bitcoin Wiki](https://en.bitcoin.it/wiki/Main_Page) or [Electrum
  Docs](https://electrum.readthedocs.io/).
- Search
  [the open issues](https://github.com/btclib-org/portanode/issues) before
  reporting: what is already known to be broken is there. What is not,
  [the bug form](https://github.com/btclib-org/portanode/issues/new/choose)
  asks for.

## Version Compatibility

- **Bitcoin Core**: Check `bitcoin-cli --version`.
- **Electrum**: Check `electrum --version`.
- Compatible with macOS 10.15+ and Windows 10+; the Linux measurements
  cited in this file and in `CLAUDE.md` were taken on Ubuntu 24.04
  (GitHub Actions' `ubuntu-latest`). Test on your setup.

## Contributing

This is an open-source project. `CONTRIBUTING.md` describes how a change
gets in and what `main` requires of it.

Everything known to be wrong or missing is an open issue:
[the issue tracker](https://github.com/btclib-org/portanode/issues) is the
list, and it is the only list.

## Security Notes

- **Binary Integrity**: Verify binaries with
  `macos/scripts/utilities/verify-binaries.sh` (macOS),
  `win/scripts/utilities/verify-binaries.bat` (Windows), or
  `linux/scripts/utilities/verify-binaries.sh` (Linux) after downloads.
    - Each verification script checks only its platform’s binaries.
- **Data Backups**: Regularly back up your Bitcoin Core wallets and
  `electrum-datadir/wallets/`. Bitcoin Core wallets are not all under one
  fixed path: mainnet keeps each wallet directly under
  `bitcoin-datadir/`, since that directory already exists before Bitcoin
  Core starts, while testnet3, testnet4 and regtest each get their own
  `bitcoin-datadir/<network>/wallets/` — see `bitcoin-datadir/README.md`.
  Use encrypted storage.
- **Network Security**: Bitcoin Core RPC is enabled in `bitcoin.conf`. Bind to
  localhost only and use strong passwords. Configure firewall to restrict
  access.
- **Permissions**: `./macos/scripts/utilities/set-permissions.sh`,
  `win/scripts/utilities/set-permissions.bat`, or
  `./linux/scripts/utilities/set-permissions.sh` restrict data-directory
  access to the owner, on a filesystem that stores permissions (APFS,
  NTFS, ext4). None of them restrict anything on exFAT or FAT32 — a
  filesystem this folder may be built on, per *Choosing a filesystem*
  above — and each script reports which case it found; see *The folder
  is unencrypted, and it is portable* under *Limitations, not
  vulnerabilities* for what actually protects data on that volume.
- **File Artifacts**: macOS creates `._*` and `.DS_Store` files; these are
  ignored by `.gitignore`. Run `./macos/scripts/utilities/clean-artifacts.sh` or
  `win/scripts/utilities/clean-artifacts.bat` to remove existing ones.
- **Linux File Artifacts**: Linux desktops leave their own trash
  directories and temporary save files on the volume; run
  `./linux/scripts/utilities/clean-artifacts.sh` to remove them, which
  empties the trash it finds.

## Limitations, not vulnerabilities

These are known and inherent. They are stated here rather than in a
security policy because they are a disclosure to whoever is about to run
this, and this is what that person reads; the policy for reporting
something that *is* a vulnerability is the organization's, shown on
[the Security tab](https://github.com/btclib-org/portanode/security/policy).

- **The trust root is the keys in your own GPG keyring**, and this
  repository cannot establish it for you. `keys/*.fingerprints` pins
  which signer is accepted once a key is imported; it does not say the
  key you imported is the publisher's. Verify a fingerprint against the
  publisher's own site before importing, which is what *Updating
  Binaries* above asks.
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
- **Wherever *Choosing a filesystem* above recommends exFAT, Bitcoin
  Core warns against it on macOS.** On every launch, Bitcoin Core's own
  startup check detects an exFAT data or blocks directory and warns
  that exFAT is known to have intermittent corruption problems there;
  Windows carries no equivalent check. The warning is upstream's and
  cannot be suppressed from a launcher here — there is no flag for it —
  and silencing it would mean either patching Bitcoin Core, which
  breaks the PGP-verified binary this repository depends on, or moving
  the data off exFAT, which breaks the interoperability exFAT was
  chosen for. Nothing in this repository mitigates the underlying risk
  beyond what a regular backup of the drive already would.
- **The launchers are not signed or notarized.** macOS Gatekeeper and
  Windows SmartScreen will treat a `.command` or a `.bat` from this
  folder as unrecognised, and the way past that is the same click an
  attacker's script would ask for. Read a launcher before running it;
  they are short and they are all in the tree.
