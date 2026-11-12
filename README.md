# PortaNode

<!-- Section 2 of the organization's standard says which badges sit here. -->
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/15649/badge)](https://www.bestpractices.dev/projects/15649)
[![OpenSSF Baseline](https://www.bestpractices.dev/projects/15649/baseline)](https://www.bestpractices.dev/projects/15649)

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

- **A drive on APFS or ext4** serves only its own operating system, and
  one on NTFS does not serve macOS: serving one more means reformatting
  it.
- **On exFAT, a file's mode is not stored**: macOS reports every file
  executable, and on Linux the mount's `fmask` decides
  (*Troubleshooting*). `set-permissions` restricts nothing there.
- **On exFAT, Electrum runs only on Windows**: on macOS and Linux its
  launchers refuse an `electrum-datadir` that cannot hold the daemon's
  socket.
- **On exFAT, Bitcoin Core warns on macOS** (*Limitations, not
  vulnerabilities*).

`ASSURANCE_CASE.md`'s *Why each filesystem is recommended* says why.

## Prerequisites

- **Operating System**: fairly recent macOS, Windows or Linux versions.
- **Disk Space**: At least 700GB free for Bitcoin Core data (mainnet) full sync.
  Pruned mainnet, regtest and testnet require less. Below 100GB free
  `validate-setup` fails outright, whatever the network and whether or not
  pruning is on.
- **Permissions**: Ensure the external disk is mounted and writable. A
  folder taken by either route in *Getting the folder* below needs
  nothing made runnable by hand, except on a Linux mount whose `fmask`
  clears the owner's execute bit or which carries `noexec`:
  *Troubleshooting* below has the remedy for both, and for a folder that
  reached the disk some other way.
- **Dependencies**: [`dependencies.yaml`](./dependencies.yaml) lists the
  programs the launchers and utilities start that this folder does not
  hold, what each is for and which ones are required. Bitcoin Core and
  Electrum come through the updaters, which need `gpg` (*PGP verification
  fails closed* below).
  `tests/sh/dependencies.sh` fails where this list and that file differ:
    - macOS: Bitcoin Core, Electrum, `bash`, `env`, `gpg`, `curl`, `tar`,
      `unzip`, `hdiutil`, `open`, `diskutil`, `sysctl`, `stat`, `ps`, `pgrep`,
      `shasum`, `sha256sum`, `jq`, `bc`, `perl`, `osascript`, `locale`,
      `find`, `awk`, `basename`, `cat`, `chmod`, `cp`, `cut`, `df`,
      `dirname`, `grep`, `head`, `ls`, `mkdir`, `mktemp`, `mv`, `readlink`,
      `rm`, `rmdir`, `sed`, `sort`, `sync`, `tail`, `tr`, `uname`, `wc`,
      `xargs`.
    - Windows: Bitcoin Core, Electrum, `cmd`, `powershell`, `gpg`, `find`,
      `findstr`, `where`, `tasklist`, `taskkill`, `icacls`, `timeout`, `doskey`.
    - Linux: Bitcoin Core, Electrum, `bash`, `env`, `gpg`, `curl`, `tar`,
      `stat`, `ps`, `pgrep`, `shasum`, `sha256sum`, `jq`, `bc`, `python3`,
      `findmnt`, `getfacl`, `notify-send`, `locale`, `find`, `awk`, `basename`,
      `cat`, `chmod`, `cp`, `cut`, `df`, `dirname`, `grep`, `head`, `mkdir`,
      `mktemp`, `mv`, `readlink`, `rm`, `rmdir`, `sed`, `sort`, `sync`, `tail`,
      `tr`, `uname`, `wc`, `xargs`.

## Getting the folder

Take it onto the disk it will run from, by either route:

```shell
git clone https://github.com/btclib-org/portanode.git
```

or unzip the ZIP of `main` the repository page offers. Both keep the
executable bit the launchers carry in the repository, which is what
*Prerequisites*' **Permissions** bullet above is about; a folder that
reached the disk any other way is under *Troubleshooting*.

Each release has a signed tag. [`VERIFYING.md`](./VERIFYING.md) shows
how to check it in a clone before running anything from it.

Where on the disk it sits is free. A launcher walks up from its own
location to the directory holding `VERSION` beside `macos/`, `win/` or
`linux/`, and reads `PORTANODE_ROOT` before it walks at all —
*Environment Overrides* below.

## Quick Start

1. Mount your external disk and navigate to the PortaNode folder.
1. For macOS: Double-click `Bitcoin-Launcher.command`,
   `Electrum-Launcher.command`, or `Utilities-Launcher.command`.
1. For Windows: Double-click `Bitcoin-Launcher.bat`,
   `Electrum-Launcher.bat`, or `Utilities-Launcher.bat` (or the matching
   `.ps1` from PowerShell).
1. For Linux: run `./Bitcoin-Launcher.sh`, `./Electrum-Launcher.sh` or
   `./Utilities-Launcher.sh` from a shell.
1. Pick the numbered menu entry for the network and mode you want.
1. Follow on-screen prompts (e.g., confirm data deletion for clean scripts).

## Launcher Notes

- `Bitcoin-Launcher.*`, `Electrum-Launcher.*` and `Utilities-Launcher.*`
  are the entry points: one file per task, with a numbered menu reaching
  every per-network script under `macos/scripts/`, `win/scripts/` and
  `linux/scripts/`.
- `.command` files are intended for double‑clicking in Finder on macOS.
- The root `.sh` files dispatch to the menu of whichever platform they
  detect, run from a shell: macOS's `.command` directly, Windows' `.bat`
  through MSYS/Cygwin, and on Linux `linux/Bitcoin-Launcher.sh`,
  `linux/Electrum-Launcher.sh` or `linux/Utilities-Launcher.sh`. A script
  under `linux/scripts/` also runs by its own path.
- `.bat` files are intended for Command Prompt/PowerShell on Windows.
- `.ps1` files are intended for PowerShell on Windows (menu-based, same options
  as `.bat`).
- `Utilities-Launcher.*` includes update and rollback options for Bitcoin
  Core and Electrum.
- `macos/README.md`, `win/README.md` and `linux/README.md` say what holds
  on one platform only.

## Folder Structure

- `macos/`
    - `README.md`: what holds on macOS only.
    - `bin/`: macOS binaries for Bitcoin Core and Electrum (e.g.,
      `Bitcoin-Qt.app/`).
    - `bin/backup/`: macOS backups created by update scripts.
    - `checksums.sha256`: macOS checksums (versioned).
    - `scripts/`
        - `bitcoin/`: Bitcoin Core launch scripts (.command).
        - `electrum/`: Electrum launch scripts (.command).
        - `utilities/`: macOS maintenance scripts (updates, verification, cleanup,
          logs).

- `win/`
    - `README.md`: what holds on Windows only.
    - `bin/`: Windows binaries (e.g., `electrum.exe`).
    - `bin/backup/`: Windows backups created by update scripts.
    - `checksums.sha256`: Windows checksums (versioned) at `win/checksums.sha256`.
    - `scripts/`
        - `bitcoin/`: Bitcoin Core launch scripts (.bat).
        - `electrum/`: Electrum launch scripts (.bat).
        - `utilities/`: Windows maintenance scripts (updates, verification, cleanup,
          logs).

- `linux/`
    - `README.md`: what holds on Linux only.
    - `Bitcoin-Launcher.sh`, `Electrum-Launcher.sh`,
      `Utilities-Launcher.sh`: the numbered menus the root launchers of
      those names reach on Linux.
    - `bin/`: Linux binaries for Bitcoin Core and Electrum (e.g.,
      `electrum.AppImage`).
    - `bin/backup/`: Linux backups created by update scripts.
    - `checksums.sha256`: Linux checksums (versioned) at
      `linux/checksums.sha256`.
    - `scripts/`
        - `bitcoin/`: Bitcoin Core launch scripts (.sh).
        - `electrum/`: Electrum launch scripts (.sh).
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
  GUI or CLI, for Alice, Bob and Carol. A clean entry refuses while a
  node uses that node's regtest data; otherwise it asks, then deletes the
  data before starting. The three can run at once on one machine, each
  connecting to the other two on localhost:

  | Node  | P2P port | RPC port | Data under `bitcoin-datadir/` |
  |-------|----------|----------|-------------------------------|
  | Alice | 18444    | 18443    | `regtest/`                    |
  | Bob   | 18555    | 18554    | `regtest_bob/`                |
  | Carol | 18666    | 18665    | `regtest_carol/`              |

- Data is stored in `bitcoin-datadir/`. Configure via `bitcoin.conf`.
- On Linux, the same script names are under `linux/scripts/bitcoin/`
  with a `.sh` extension, and each also runs by its own path.

### Electrum

- **Mainnet**: `Electrum-Launcher.*`'s menu runs `mainnet` or
  `mainnet-local-server-only`.
    - `mainnet` leaves the choice of server to Electrum, which by default
      connects to several public servers. The one it picks as its
      history server learns every address of your wallet, as Electrum's
      own description of its `oneserver` setting says, and every
      transaction you broadcast goes through it. Every server it
      connects to sees the IP address you connect from. Network settings
      you change in Electrum are kept in `electrum-datadir/`, which both
      mainnet entries share.
    - `mainnet-local-server-only` passes `--oneserver` and
      `--server localhost:50002:s`, so Electrum connects to an Electrum
      server on this machine and to no other. Use it where your
      addresses must stay private. Nothing in this folder installs or
      starts that server.
- **Testnet3**: `Electrum-Launcher.*`'s menu runs `testnet3`.
- **Testnet4**: `Electrum-Launcher.*`'s menu runs `testnet4`.
- **Regtest**: `Electrum-Launcher.*`'s menu runs `regtest`.
- Data in `electrum-datadir/`. Wallets are in `wallets/`. Every platform's
  launchers use this one directory, so a wallet created on one is the
  wallet the others open.
- `mainnet` and `mainnet-local-server-only` open the same state, and
  neither checks for the other: stop one before starting the other.
- On Linux, the same script names are under `linux/scripts/electrum/`
  with a `.sh` extension, and each also runs by its own path.

### Environment Overrides

Set `PORTANODE_ROOT` to the folder holding `VERSION` to skip the walk up
from the script. A value that is not that folder stops the script with a
message naming it:

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
  signature, and records the new binary's checksum. It needs network
  access, and downloads and unpacks in the local temporary directory,
  never on the removable volume.
- **An updater refuses a version older than the installed one**, since an
  old release still carries valid signatures, and any version where the
  installed one is not digits and dots. `--allow-downgrade` installs it
  anyway. The installed version is the one the platform's
  `checksums.sha256` records for the installed binary's hash; where it
  records none, no version is refused as older. A requested version that
  is not digits and dots is refused whatever else is passed, since it is
  built into a URL and a file name.
- Rollback with `./macos/scripts/utilities/rollback-bitcoin.sh` or
  `./macos/scripts/utilities/rollback-electrum.sh` on macOS,
  `win/scripts/utilities/rollback-bitcoin.bat` and
  `win/scripts/utilities/rollback-electrum.bat` on Windows, or
  `linux/scripts/utilities/rollback-bitcoin.sh` and
  `linux/scripts/utilities/rollback-electrum.sh` on Linux, if an update causes
  issues. Rollback needs the backup an update created, so it is only available
  after one has run. It moves the backup into place, so a second rollback has
  nothing left to restore. On macOS, the first rollback after upgrading to the
  whole-bundle checks is refused, because the entries recorded before them cover
  the executable only; rollbacks work from the second update on.
- After updating, run the platform's `verify-binaries`,
  `validate-setup` and `health-check`, in that order: for example
  `./macos/scripts/utilities/validate-setup.sh`,
  `win/scripts/utilities/validate-setup.bat` or
  `linux/scripts/utilities/validate-setup.sh`. Then test with the
  regtest scripts.
- **PGP verification fails closed.** Update scripts abort the install unless the
  download carries good PGP signatures from enough of the keys `keys/` ships.
  This requires `gpg` to be installed. No key has to be imported, and a key
  in your own keyring does not count: `gpg` runs in a home of its own, made
  empty for the run, with the keyring from `keys/` as its only keyring.
  Nothing skips the check: where it fails, fix what the error names and run
  the update again.
    - **Bitcoin Core**: `keys/bitcoin-core.gpg` holds the keys of the
      builders who sign its releases regularly, chosen in
      [ISS 783](https://github.com/btclib-org/portanode/issues/783), and an
      update needs good signatures from 3 of them.
    - **Electrum**: `keys/electrum.gpg` holds its release key, and a download
      needs its signature.
    - An expired or revoked key does not count, so a key that expires stops
      counting until the tree changes. Nor does a signature made with MD5,
      SHA-1 or RIPEMD-160, which RFC 9580 says not to rely on. The number of
      signatures asked for is in `shared/utilities/lib.sh` and in the Windows
      updaters.
    - **How a key changes**: a key that is added, dropped, rotated or renewed
      is a pull request that rewrites the keyring. Take Bitcoin Core's keys
      from the `builder-keys/` folder of
      [bitcoin-core/guix.sigs](https://github.com/bitcoin-core/guix.sigs) and
      Electrum's from the `pubkeys/` folder of
      [spesmilo/electrum](https://github.com/spesmilo/electrum), at a commit
      the pull request names. Put the key files the keyring is to hold, and
      nothing else, in one folder, and write the keyring from them in a
      scratch home:

      ```shell
      h=$(mktemp -d)
      printf '%s\0' <folder>/* | LC_ALL=C sort -z |
        xargs -0 gpg --homedir "$h" --batch --import
      gpg --homedir "$h" --export --export-options export-minimal \
        > keys/bitcoin-core.gpg
      gpgconf --homedir "$h" --kill all
      rm -rf "$h"
      ```

      `gpg` writes the keys in the order it imported them, so the files are
      imported sorted by name. A reviewer can then rebuild the keyring from
      the same files and compare it byte for byte: with gpg 2.5.24 these
      commands write the same bytes each time. This lists what a keyring
      holds:

      ```shell
      h=$(mktemp -d)
      gpg --homedir "$h" --no-default-keyring \
        --keyring "$PWD/keys/bitcoin-core.gpg" --list-keys
      gpgconf --homedir "$h" --kill all
      rm -rf "$h"
      ```

- **If an updater cannot run** — no network access to bitcoincore.org or
  electrum.org, or a release the updater's scraper does not find — download
  the binary by hand from
  [bitcoincore.org](https://bitcoincore.org/en/download/) or
  [electrum.org](https://electrum.org/#download) and verify its checksum
  against the official source yourself, then replace `macos/bin/`
  (`Bitcoin-Qt.app`, or the command-line tools `macos/README.md` lists),
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
  `linux/checksums.sha256` keep lists of acceptable hashes labeled by version;
  update scripts append a new entry (only after a successful PGP verification),
  never add one twice, and never rewrite an existing one. In the repository,
  their Bitcoin Core entries, where a file has any, are those of the supported
  majors (*Version Compatibility* below); a rollback refuses a backup no entry
  matches. These files provide **integrity and rollback** checks (detecting
  corruption/tampering of an already-installed binary), not authenticity —
  authenticity comes from the PGP step above. The *PGP verification fails
  closed* bullet above says which keys `keys/` ships and where they come from.

### Expected Binaries by OS

- **macOS (`macos/bin/`)**: `Bitcoin-Qt.app/`, `Electrum.app/`, and the Bitcoin
  Core command-line tools (see `macos/README.md`)
- **Windows (`win/bin/`)**: `bitcoin-qt.exe`, `bitcoind.exe`, `bitcoin-cli.exe`,
  `bitcoin-tx.exe`, `bitcoin-util.exe`, `bitcoin-wallet.exe`, `bitcoin.exe`,
  `electrum.exe`
- **Linux (`linux/bin/`)**: `bitcoin-qt`, `bitcoind`, `bitcoin-cli`,
  `bitcoin-tx`, `bitcoin-util`, `bitcoin-wallet`, `bitcoin`,
  `electrum.AppImage`

## Troubleshooting

### Common Issues

- **Script fails with "Binary not found"**: Ensure binaries are in
  `macos/bin/`, `win/bin/` or `linux/bin/`. Check permissions.
- **Permission denied, on a volume that stores a Unix mode** (APFS or
  ext4): the folder reached this disk through something that dropped the
  executable bit — a copy, or an archive unpacked by a tool that does
  not restore it. `chmod +x` the launcher you ran, or take the folder
  again by either route in *Getting the folder*, both of which keep it.
- **Permission denied on Linux, with the folder on exFAT**: the mode a
  file reads there comes from the mount's `fmask`, so a mask with `1` in
  its owner digit, such as `fmask=133`, leaves the launchers unrunnable
  however they reached the volume. Neither `chmod +x` nor a
  `mount -o remount` naming another mask changes it.
  `findmnt -no OPTIONS <mount point>` prints the mask. Unmount the
  volume and mount it again with one that keeps the owner's execute bit:
  `fmask=022`, or `fmask=077,dmask=077` to keep the volume owner-only.
- **Permission denied, though the mode reads executable**: the mount
  carries `noexec`, which refuses the exec whatever the file's mode, and
  `test -x` answers false. The two entries above change nothing here.
  `findmnt -no OPTIONS <mount point>` shows `noexec`. Unmount the volume
  and mount it again without it.
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
  `./linux/scripts/utilities/rotate-bitcoin-log.sh` copy `debug.log` to a
  backup (`debug.log.1`, etc.) and start it afresh.
- Monitor logs: `./macos/scripts/utilities/monitor-bitcoin-log.sh`,
  `win/scripts/utilities/monitor-bitcoin-log.bat`, or
  `./linux/scripts/utilities/monitor-bitcoin-log.sh` (run periodically to
  check for errors) report the errors and warnings logged since the last
  run. In a reported line, C0 and DEL print as `\xHH`, such as `\x1b`,
  and C1 in its UTF-8 form as `\u00HH`, rather than reaching the
  terminal. A carriage return before a newline is dropped. On macOS and
  Linux a byte 0x80 to 0x9F that is not part of a UTF-8 character prints
  as `\xHH`. Under `cron`, `launchd` or Task Scheduler, add `--no-notify`
  (or set `PORTANODE_NO_NOTIFY=1`) to suppress the desktop notification,
  which a headless or logged-out session cannot show and which blocks on
  Windows until someone dismisses it.
- Health check: `./macos/scripts/utilities/health-check.sh`,
  `win/scripts/utilities/health-check.bat`, or
  `./linux/scripts/utilities/health-check.sh` check disk space and
  whether the processes are running. For Bitcoin Core they ask
  `bitcoin-cli` first, then the process list, then the datadir's
  `.cookie` and `bitcoind.pid`. For Electrum they read the process list
  alone, so where it is restricted a running Electrum can go unseen. On
  macOS and Linux, where `pgrep` is missing, or where `pgrep` or `ps`
  fails, they print `unknown` in place of `no`.

### Getting Help

- Check [Bitcoin Wiki](https://en.bitcoin.it/wiki/Main_Page) or [Electrum
  Docs](https://electrum.readthedocs.io/).
- Search
  [the open issues](https://github.com/btclib-org/portanode/issues) before
  reporting: what is already known to be broken is there. What is not,
  [the bug form](https://github.com/btclib-org/portanode/issues/new/choose)
  asks for.

## Version Compatibility

- **Bitcoin Core**: the latest major release and the one before it are
  supported. Check `bitcoin-cli --version`.
- **Electrum**: Check `electrum --version`.
- Compatible with macOS 10.15+ and Windows 10+; the Linux measurements
  cited in this file were taken on Ubuntu 24.04
  (GitHub Actions' `ubuntu-latest`). Test on your setup.

## Contributing

Development is LLM-based: humans are welcome, as long as they are
comfortable with agentic development ;-). A contribution must have been
read and understood by the person who submits it.
[`CONTRIBUTING.md`](./CONTRIBUTING.md#working-with-an-llm) has the rules.

[`CONTRIBUTING.md`](./CONTRIBUTING.md) describes how a change gets in and
what `main` requires of it; [`REVIEWING.md`](./REVIEWING.md) is the
standard a review is written against.

How the organization decides, and who holds which role, is its
[GOVERNANCE.md](https://github.com/btclib-org/.github/blob/main/GOVERNANCE.md);
what it intends to do, and what it deliberately does not, is its
[ROADMAP.md](https://github.com/btclib-org/.github/blob/main/ROADMAP.md).

Everything known to be wrong or missing is an open issue:
[the issue tracker](https://github.com/btclib-org/portanode/issues) is the
list, and it is the only list.

## Security Notes

- **Threat model**: [`ASSURANCE_CASE.md`](./ASSURANCE_CASE.md) names what
  is defended and against whom, where input enters, and how each threat
  is countered or why it is accepted.
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
- **Network Security**: see the `[rpc]` and `[secrets]` comments in
  `bitcoin-datadir/bitcoin.conf` for where RPC is open and where passwords
  go; where RPC is on, bind to localhost and restrict it with the firewall.
- **Permissions**: `./macos/scripts/utilities/set-permissions.sh`,
  `win/scripts/utilities/set-permissions.bat`, or
  `./linux/scripts/utilities/set-permissions.sh` restrict data-directory
  access to the owner, on a filesystem that stores permissions (APFS,
  NTFS, ext4). None of them restrict anything on exFAT or FAT32 — a
  filesystem this folder may be built on, per *Choosing a filesystem*
  above — and each script reports which case it found; see *The folder
  is unencrypted, and it is portable* under *Limitations, not
  vulnerabilities* for what actually protects data on that volume.

    Each answers in the exit status as well as in the text, with the
    same values on every platform: `0` where the data directories are
    restricted to the owner, read back off the directory rather than
    assumed from the write; `1` where the run fell short of that and
    acting on what the message names is what would reach it — an account
    that does not resolve, a path `chmod` was refused, an entry granting
    somebody else access; `2` where the volume stores no permissions at
    all, so no run of these scripts restricts anything and encryption or
    physical control of the device is the remedy. A run covering both
    data directories exits with the higher of their two statuses, which
    is the outcome the reader has least recourse against; each
    directory's own message is printed either way.
- **File Artifacts**: macOS creates `._*` and `.DS_Store` files; these are
  ignored by `.gitignore`. Run `./macos/scripts/utilities/clean-artifacts.sh`
  to remove existing ones. Windows leaves `Thumbs.db`, `ehthumbs.db` and
  `*.stackdump` files, which `win/scripts/utilities/clean-artifacts.bat`
  removes.
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

- **The trust root is the keyrings in `keys/`**, which come with this
  repository: a copy whose release tag verifies (`VERIFYING.md`) ships the
  keys its pull requests reviewed. They are taken from the publishers'
  repositories, as *Updating Binaries* above says, and whether a key there
  is its signer's own is what those repositories establish, not this one.
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

## Status

<!-- Section 2 of the organization's standard says which badges sit here. -->
[![pre-commit.ci status](https://results.pre-commit.ci/badge/github/btclib-org/portanode/main.svg)](https://results.pre-commit.ci/latest/github/btclib-org/portanode/main)
[![lint workflow status](https://github.com/btclib-org/portanode/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/btclib-org/portanode/actions/workflows/lint.yml?query=branch%3Amain)
[![test workflow status](https://github.com/btclib-org/portanode/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/btclib-org/portanode/actions/workflows/test.yml?query=branch%3Amain)
[![os-macos workflow status](https://github.com/btclib-org/portanode/actions/workflows/os-macos.yml/badge.svg?branch=main)](https://github.com/btclib-org/portanode/actions/workflows/os-macos.yml?query=branch%3Amain)
[![os-windows workflow status](https://github.com/btclib-org/portanode/actions/workflows/os-windows.yml/badge.svg?branch=main)](https://github.com/btclib-org/portanode/actions/workflows/os-windows.yml?query=branch%3Amain)
[![links workflow status](https://github.com/btclib-org/portanode/actions/workflows/links.yml/badge.svg?branch=main)](https://github.com/btclib-org/portanode/actions/workflows/links.yml?query=branch%3Amain)
[![codeql workflow status](https://github.com/btclib-org/portanode/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/btclib-org/portanode/actions/workflows/codeql.yml?query=branch%3Amain)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/btclib-org/portanode/badge)](https://scorecard.dev/viewer/?uri=github.com/btclib-org/portanode)
