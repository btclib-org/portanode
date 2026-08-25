# Utilities

This directory contains maintenance and utility scripts for PortaNode.

## Scripts Overview

### Updates

- `update-bitcoin.sh`: Downloads and installs the latest Bitcoin Core binaries.
  Detects architecture (x86_64/arm64), backs up old binaries, verifies
  checksums, and updates the checksum file.
- `update-electrum.sh`: Fetches the latest Electrum version from electrum.org,
  downloads the DMG, mounts it, replaces binaries, backs up old versions, and
  updates checksums.

### Verification and Validation

Usually run after setup or updates.

- `verify-binaries.sh`: Verifies all binaries against `macos/checksums.sha256`
  using `shasum`. Supports multiple acceptable hashes per file with version
  labels.
**Note**: `verify-binaries.sh` uses `bash` features (indexed arrays, not
associative arrays: macOS ships bash 3.2). Run it with `bash` if your
system's default `sh` is not bash.
- `validate-setup.sh`: Checks for binaries, verifies checksums, confirms data
  directories, and reports disk space.

### Rollback

Can be used if an update fails.

- `rollback-bitcoin.sh`: Restores Bitcoin binaries from
  `macos/bin/backup/bitcoin/`.
- `rollback-electrum.sh`: Restores Electrum binaries from
  `macos/bin/backup/electrum/`.

### Logging and Maintenance

- `rotate-bitcoin-log.sh`: Rotates `bitcoin-datadir/debug.log` by copying the
  current log file to a backup (debug.log.1, etc.) and starting a new log file.
- `monitor-bitcoin-log.sh`: Monitors the Bitcoin log for new errors/warnings,
  sending macOS notifications if issues are detected. Tracks progress by
  byte offset to avoid re-scanning or duplicating; `--no-notify` (or
  `PORTANODE_NO_NOTIFY=1`) suppresses the notification for a scheduled run.
- `health-check.sh`: Disk space + basic process checks.
- `clean-artifacts.sh`: Removes macOS artifact files (`._*`, `.DS_Store`) from
  the repo.
- `set-permissions.sh`: Sets restrictive permissions (700) on `bitcoin-datadir/`
  and `electrum-datadir/` for security.

## Notes

- Run scripts from the project root (e.g.,
  `./macos/scripts/utilities/script.sh`).
- Most scripts require internet for downloads; ensure connectivity.
- Update scripts download, verify and extract or mount on the local
  temp directory, never on the removable volume, and clean up on exit.
- Update scripts verify PGP signatures for Bitcoin Core and Electrum
  downloads before installing, and fail closed: a bad signature, a missing
  signer key, or no `gpg` at all aborts the update rather than installing
  unverified binaries. Set `PORTANODE_ALLOW_UNVERIFIED=1` to bypass
  verification (not recommended). `README.md`'s *Updating Binaries*
  section has where to obtain each project's signing key, why a missing
  key rather than a missing signature is the usual cause of a validation
  failure, and how key pinning works.
- Backups are stored in `macos/bin/backup/`; rollbacks depend on these.
- `macos/checksums.sha256` is append-only: new verified hashes are added with
  `version=<x>` and exact duplicates are pruned.
- Cleanup scripts are OS-specific; macOS cleanup only targets macOS artifacts.
- Health checks rely on process listing; some sandboxed environments may
  restrict this and reduce detection accuracy.
- Root launchers are available for specific areas: `Bitcoin-Launcher.*`,
  `Electrum-Launcher.*`, and `Utilities-Launcher.*` (choose `.command` or `.sh`
  for macOS).
- The Utilities launcher includes update and rollback options for Bitcoin and
  Electrum.
- Check script output for errors; refer to main README.md for troubleshooting.

## Smoke Check (macOS)

Run these in order after updates:

1. `macos/scripts/utilities/verify-binaries.sh`
1. `macos/scripts/utilities/validate-setup.sh`
1. `macos/scripts/utilities/health-check.sh`

## Dependencies

- macOS: `curl`, `shasum`, `hdiutil` (for DMG handling).
- General: Bash-compatible shell.
