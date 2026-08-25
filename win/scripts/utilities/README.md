# Utilities

This directory contains maintenance and utility scripts for PortaNode.
These are designed for Command Prompt or PowerShell.

## Scripts Overview

### Update

- `update-bitcoin.bat`:
  Downloads and installs the latest Bitcoin Core (win64),
  backs up old binaries, verifies checksums, and updates the checksum file.
- `update-electrum.bat`:
  Fetches the latest Electrum version from electrum.org,
  backs up old binary, updates checksums.

### Verification and Validation

Usually run after setup or updates.

- `verify-binaries.bat`:
  Verifies all binaries against `win/checksums.sha256` (supported versions).
- `validate-setup.bat`:
  Checks for binaries, verifies checksums, confirms data directories,
  and reports disk space.

### Rollback

Can be used if an update fails

- `rollback-bitcoin.bat`:
  Restores `bitcoin-qt.exe` and the command-line tools from
  `win/bin/backup/bitcoin/`, moving each into place rather than copying it,
  so the restore consumes the backup and a second rollback has nothing
  left to restore. `update-bitcoin.bat` backs up the command-line tools
  alongside the app, unlike the macOS half, so all of them come back
  together.
- `rollback-electrum.bat`:
  Restores `electrum.exe` from `win/bin/backup/electrum/`, moving it into
  place and consuming the backup the same way.

### Logging and Maintenance

- `rotate-bitcoin-log.bat`: Rotates `bitcoin-datadir/debug.log` by copying to a
  backup (debug.log.1, etc.) and truncating the current log.
- `monitor-bitcoin-log.bat`: Scans the Bitcoin log for new errors/warnings,
  showing a toast (or a MessageBox where toast notifications are
  unavailable) if issues are detected. `--no-notify` (or
  `PORTANODE_NO_NOTIFY=1`) suppresses it for a scheduled run — needed under
  Task Scheduler, since the MessageBox fallback is modal and would block a
  scheduled run indefinitely.
- `health-check.bat`: Disk space + basic process checks.
- `clean-artifacts.bat`: Removes Windows artifact files from the repo.
- `set-permissions.bat`: Sets restrictive ACLs on `bitcoin-datadir/` and
  `electrum-datadir/` for security.

## Notes

- Run from repo root or double-click in Explorer; scripts resolve paths relative
  to the repo.
- Most scripts require internet for downloads; ensure connectivity.
- Update scripts download, verify and (for Bitcoin Core) extract on
  the local disk (`%TEMP%`), never on the removable volume, and clean up
  on exit.
- Update scripts verify PGP signatures for Bitcoin Core and Electrum
  downloads before installing, and fail closed: a bad signature, a missing
  signer key, or no `gpg` at all aborts the update rather than installing
  unverified binaries. Set `PORTANODE_ALLOW_UNVERIFIED=1` to bypass
  verification (not recommended). `README.md`'s *Updating Binaries*
  section has where to obtain each project's signing key, why a missing
  key rather than a missing signature is the usual cause of a validation
  failure, and how key pinning works.
- Backups are stored in `win/bin/backup/`; rollbacks depend on these.
- `win/checksums.sha256` is append-only: new verified hashes are added with
  `version=<x>` and exact duplicates are pruned.
- Log monitoring attempts to show a Windows toast notification; if unavailable,
  it falls back to a MessageBox or console warning.
- Cleanup scripts are OS-specific; Windows cleanup only targets Windows
  artifacts.
- Check script output for errors; refer to main README.md for troubleshooting.
- The Utilities launcher includes update and rollback options for Bitcoin and
  Electrum.

## Smoke Check

Run these in order after updates:

1. `win/scripts/utilities/verify-binaries.bat`
1. `win/scripts/utilities/validate-setup.bat`
1. `win/scripts/utilities/health-check.bat`
