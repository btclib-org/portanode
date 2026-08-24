# PortaNode

## Portable (external‑disk‑friendly) cross-platform Bitcoin node

PortaNode bundles scripts, binaries, and data for running Bitcoin Core
(and Electrum) on macOS and Windows.

If you’ve ever tried running an indexed full Bitcoin node
on a portable external disk shared between Windows and macOS,
you know the kinds of problems this is meant to address.

It works best on an exFAT-formatted NVMe drive
in a portable USB 3 / Thunderbolt enclosure.

## Prerequisites

- **Operating System**: fairly recent macOS or Windows versions.
- **Disk Space**: At least 700GB free for Bitcoin Core data (mainnet) full sync.
  Regtest/testnet require less.
- **Permissions**: Ensure the external disk is mounted and writable. A folder
  taken with `git clone`, or unzipped from a release's source archive, needs
  nothing made runnable by hand: the launchers carry the executable bit in the
  repository and both of those routes keep it, and an exFAT volume reports every
  file as executable whatever its mode. A folder that reached the disk some
  other way is under *Troubleshooting*.
- **Dependencies**: None required beyond standard OS tools. For advanced use,
  ensure Python (for Electrum) and command-line tools are available.

## Quick Start

1. Mount your external disk and navigate to the PortaNode folder.
1. For macOS: Double-click a script in `macos/scripts/bitcoin/` or
   `macos/scripts/electrum/` (e.g., `mainnet-8333-qt.command`).
1. For Windows: Double-click a script in `win/scripts/bitcoin/` or
   `win/scripts/electrum/` (e.g., `mainnet-8333-qt.bat`).
1. Root launchers: `Bitcoin-Launcher.*`, `Electrum-Launcher.*`, and
   `Utilities-Launcher.*` (choose `.command`, `.bat`, `.ps1`, or `.sh` for your
   OS).
1. Follow on-screen prompts (e.g., confirm data deletion for clean scripts).

## Launcher Notes

- `.command` files are intended for double‑clicking in Finder on macOS.
- `.sh` files are intended for running from a shell (macOS/Linux or Windows
  MSYS/Cygwin).
- `.bat` files are intended for Command Prompt/PowerShell on Windows.
- `.ps1` files are intended for PowerShell on Windows (menu-based, same options
  as `.bat`).

## Folder Structure

- `macos/`
    - `bin/`: macOS app bundles for Bitcoin Core and Electrum.
        - `Bitcoin-Qt.app/`: Bitcoin Core app bundle.
        - `Electrum.app/`: Electrum app bundle.
        - `.tmp-downloads/`: Temporary downloads used by update scripts.
    - `bin/backup/`: macOS backups created by update scripts (see
      `macos/bin/backup/README.md`).
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
        - `.tmp-downloads/`: Temporary downloads used by update scripts.
    - `bin/backup/`: Windows backups created by update scripts (see
      `win/bin/backup/README.md`).
    - `checksums.sha256`: Windows checksums (versioned) at `win/checksums.sha256`.
    - `scripts/`
        - `bitcoin/`: Bitcoin Core launch scripts (.bat). See
          `win/scripts/bitcoin/README.md`.
        - `electrum/`: Electrum launch scripts (.bat). See
          `win/scripts/electrum/README.md`.
        - `utilities/`: Windows maintenance scripts (updates, verification, cleanup,
          logs).

- `bitcoin-datadir/`: Bitcoin Core configuration/data (e.g., `bitcoin.conf`).
- `electrum-datadir/`: Electrum data (wallets, regtest/testnet data).

## Detailed Setup

### Bitcoin Core

- **Mainnet**: Use `mainnet-8333-qt` scripts for GUI or CLI.
- **Testnet**: Use `testnet3-18333-qt` for testnet.
- **Regtest**: Use `regtest-*` scripts for local testing. Clean scripts reset
  data.
- Data is stored in `bitcoin-datadir/`. Configure via `bitcoin.conf`.

### Electrum

- **Mainnet**: Use `mainnet` or `mainnet-local-server-only` (connects to local
  server).
- **Testnet/Regtest**: Use respective scripts.
- Data in `electrum-datadir/`. Wallets are in `wallets/`.

### Environment Overrides

Set `PORTANODE_ROOT` to customize the root path (e.g., if moving the folder):

- macOS: `export PORTANODE_ROOT=/path/to/portanode`
- Windows: `set PORTANODE_ROOT=C:\path\to\portanode`

## Updating Binaries

- On macOS, update using `./macos/scripts/utilities/update-bitcoin.sh` or
  `./macos/scripts/utilities/update-electrum.sh`; on Windows, use
  `win/scripts/utilities/update-bitcoin.bat` or
  `win/scripts/utilities/update-electrum.bat`. Both platforms' updaters
  back up the version they replace, verify the download's PGP signature,
  and record the new binary's checksum.
- Rollback with `./macos/scripts/utilities/rollback-bitcoin.sh` or
  `./macos/scripts/utilities/rollback-electrum.sh` on macOS, or
  `win/scripts/utilities/rollback-bitcoin.bat` and
  `win/scripts/utilities/rollback-electrum.bat` on Windows, if an update
  causes issues. Rollback needs the backup an update created, so it is
  only available after one has run.
- Validate setup with `./macos/scripts/utilities/validate-setup.sh` or
  `win/scripts/utilities/validate-setup.bat` after updating, and test
  with the regtest scripts.
- **PGP verification fails closed.** Update scripts abort the install unless the
  download carries a valid PGP signature. This requires `gpg` to be installed
  and the signer's key imported. To bypass (installs UNAUTHENTICATED binaries —
  not recommended), set `PORTANODE_ALLOW_UNVERIFIED=1` in the environment.
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
  (`Bitcoin-Qt.app`, or `bitcoind`, `bitcoin-cli`, `bitcoin-tx`,
  `bitcoin-util`, `bitcoin-wallet`, `bitcoin-qt`) or `win/bin/`
  (`bitcoin-qt.exe`, `bitcoind.exe`, `bitcoin-cli.exe`, `bitcoin-tx.exe`,
  `bitcoin-util.exe`, `bitcoin-wallet.exe`, `bitcoin.exe`) for Bitcoin
  Core, or `macos/bin/Electrum.app/` or `win/bin/electrum.exe` for
  Electrum. A hand-replaced binary carries no updater backup and no
  checksum entry, so rollback and `validate-setup`'s checksum check do
  not see it until an updater run records one.
- **Checksums**: `macos/checksums.sha256` and `win/checksums.sha256` keep
  ever-growing lists of acceptable hashes labeled by version; update scripts
  append new entries (only after a successful PGP verification) and deduplicate
  exact duplicates. These files provide **integrity and rollback** checks
  (detecting corruption/tampering of an already-installed binary), not
  authenticity — authenticity comes from the PGP step above.
- **Signing Keys**:
    - Bitcoin Core: import builder keys from
      [bitcoin-core/guix.sigs](https://github.com/bitcoin-core/guix.sigs/tree/main/builder-keys).
      Verify fingerprints before trust; pin trusted ones in
      `keys/bitcoin-core.fingerprints`.
    - Electrum: import the release signing key from electrum.org Download page.
      Verify the fingerprint published there (pinned in
      `keys/electrum.fingerprints`).

### Expected Binaries by OS

- **macOS (`macos/bin/`)**: `Bitcoin-Qt.app/`, `Electrum.app/` (see
  `macos/bin/README.md`)
- **Windows (`win/bin/`)**: `bitcoin-qt.exe`, `bitcoind.exe`, `bitcoin-cli.exe`,
  `bitcoin-tx.exe`, `bitcoin-util.exe`, `bitcoin-wallet.exe`, `bitcoin.exe`,
  `electrum.exe` (see `win/bin/README.md`)

## Troubleshooting

### Common Issues

- **Script fails with "Binary not found"**: Ensure binaries are in `macos/bin/`
  or `win/bin/`. Check permissions.
- **Permission denied on macOS**: The folder reached this disk through
  something that dropped the executable bit — a copy, or an archive
  unpacked by a tool that does not restore it. `chmod +x` the launcher you
  ran, or take the folder again with `git clone` or by unzipping the
  release's source archive, both of which keep it.
- **Disk space errors**: Free up space or use pruning in `bitcoin.conf`
  (`prune=550` for ~550MB blocks).
- **Sync issues**: Check logs in `bitcoin-datadir/debug.log`. For Electrum,
  check console output.
- **Regtest not connecting**: Ensure all regtest scripts are run (Alice, Bob,
  Carol) and ports are open.
- **Path errors**: If moved, use `PORTANODE_ROOT` or adjust scripts.

### Logs and Debugging

- Bitcoin: `bitcoin-datadir/debug.log`
- Electrum: Check terminal output or `electrum-datadir/` for logs.
- Run scripts from terminal for verbose output: `bash
  macos/scripts/bitcoin/mainnet-8333-qt.command` or
  `win/scripts/bitcoin/mainnet-8333-qt.bat`.
- Rotate logs: `./macos/scripts/utilities/rotate-bitcoin-log.sh` or
  `win/scripts/utilities/rotate-bitcoin-log.bat`
- Monitor logs: `./macos/scripts/utilities/monitor-bitcoin-log.sh` or
  `win/scripts/utilities/monitor-bitcoin-log.bat` (run periodically to check for
  errors). Under `cron`, `launchd` or Task Scheduler, add `--no-notify` (or
  set `PORTANODE_NO_NOTIFY=1`) to suppress the desktop notification, which a
  headless or logged-out session cannot show and which blocks on Windows
  until someone dismisses it.
- Health check: `./macos/scripts/utilities/health-check.sh` or
  `win/scripts/utilities/health-check.bat`

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
- Compatible with macOS 10.15+, Windows 10+. Test on your setup.

## Contributing

This is an open-source project. `CONTRIBUTING.md` describes how a change
gets in and what `main` requires of it.

Everything known to be wrong or missing is an open issue:
[the issue tracker](https://github.com/btclib-org/portanode/issues) is the
list, and it is the only list.

## Security Notes

- **Binary Integrity**: Verify binaries with
  `macos/scripts/utilities/verify-binaries.sh` (macOS) or
  `win/scripts/utilities/verify-binaries.bat` (Windows) after downloads.
    - Each verification script checks only its platform’s binaries.
- **Data Backups**: Regularly backup `bitcoin-datadir/wallets/` and
  `electrum-datadir/wallets/`. Use encrypted storage.
- **Network Security**: Bitcoin Core RPC is enabled in `bitcoin.conf`. Bind to
  localhost only and use strong passwords. Configure firewall to restrict
  access.
- **Permissions**: Set restrictive permissions on data directories:
  `./macos/scripts/utilities/set-permissions.sh` or
  `win/scripts/utilities/set-permissions.bat`.
- **File Artifacts**: macOS creates `._*` and `.DS_Store` files; these are
  ignored by `.gitignore`. Run `./macos/scripts/utilities/clean-artifacts.sh` or
  `win/scripts/utilities/clean-artifacts.bat` to remove existing ones.

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
- **The launchers are not signed or notarized.** macOS Gatekeeper and
  Windows SmartScreen will treat a `.command` or a `.bat` from this
  folder as unrecognised, and the way past that is the same click an
  attacker's script would ask for. Read a launcher before running it;
  they are short and they are all in the tree.
