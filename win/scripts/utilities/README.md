# Utilities

This directory contains maintenance and utility scripts for PortaNode.
These are designed for Command Prompt or PowerShell.

## Scripts Overview

### Update
- `update-bitcoin.bat`: Downloads and installs the latest Bitcoin Core (win64), backs up old binaries, verifies checksums, and updates the checksum file.
- `update-electrum.bat`: Fetches the latest Electrum version from electrum.org, backs up old binary, updates checksums.

### Verification and Validation

Usually run after setup or updates.

- `verify-binaries.bat`: Verifies all binaries against `win/checksums.sha256` (versioned entries supported).
- `validate-setup.bat`: Checks for binaries, verifies checksums, confirms data directories, and reports disk space.

### Rollback

Can be used if an update fails

- `rollback-bitcoin.bat`: Restores Bitcoin binaries from `win/bin/backup/bitcoin/`.
- `rollback-electrum.bat`: Restores Electrum binary from `win/bin/backup/electrum/`.

### Logging and Maintenance
- `rotate-bitcoin-log.bat`: Rotates `bitcoin-datadir/debug.log` by truncateing the current log, creating its backup (debug.log.1, etc.) and starting a new log file.
- `monitor-bitcoin-log.bat`: Scans the Bitcoin log for new errors/warnings.
- `health-check.bat`: Disk space + basic process checks.
- `clean-artifacts.bat`: Removes Windows artifact files from the repo.
- `set-permissions.bat`: Sets restrictive ACLs on `bitcoin-datadir/` and `electrum-datadir/` for security.

## Notes
- Run from repo root or double-click in Explorer; scripts resolve paths relative to the repo.
- Most scripts require internet for downloads; ensure connectivity.
- Update scripts place temporary downloads under `win/bin/.tmp-downloads/` and clean them on exit.
- If `gpg` is installed, update scripts verify PGP signatures for Bitcoin Core and Electrum downloads.
  - **Bitcoin Core signing keys**: obtain keys from the official Bitcoin Core repository (`contrib/builder-keys/keys.txt`) and import with `gpg --import`.
  - **Electrum signing key**: obtain the release signing key from electrum.org (Download page) and import with `gpg --import`.
- Backups are stored in `win/bin/backup/`; rollbacks depend on these.
- `win/checksums.sha256` is append-only: new verified hashes are added with `version=<x>` and exact duplicates are pruned.
- Log monitoring attempts to show a Windows toast notification; if unavailable, it falls back to a MessageBox or console warning.
- Cleanup scripts are OS-specific; Windows cleanup only targets Windows artifacts.
- Check script output for errors; refer to main README.md for troubleshooting.

## Smoke Check
Run these in order after updates:
1. `win/scripts/utilities/verify-binaries.bat`
2. `win/scripts/utilities/validate-setup.bat`
3. `win/scripts/utilities/health-check.bat`
