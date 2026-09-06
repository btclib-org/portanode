# Utilities

This directory contains maintenance and utility scripts for PortaNode on
Linux.

## Scripts Overview

### Updates

- `update-bitcoin.sh`: Downloads and installs the latest Bitcoin Core
  binaries from the `linux-gnu` tarball, choosing `x86_64` or `aarch64`
  from `uname -m` and refusing anything else, backs up the binaries it
  replaces, verifies the multi-signed `SHA256SUMS`, and records the new
  hashes.
- `update-electrum.sh`: Fetches the latest Electrum version from
  electrum.org and installs the published AppImage unmodified as
  `linux/bin/electrum.AppImage`, backing up the previous one and
  recording its hash. That script's own comment carries the measurement
  behind installing the artifact rather than extracting it.

### Verification and Validation

Usually run after setup or updates.

- `verify-binaries.sh`: Verifies the binaries against
  `linux/checksums.sha256`, using whichever of `shasum` and `sha256sum`
  is on the PATH. Supports multiple acceptable hashes per file with
  version labels.
- `validate-setup.sh`: Checks for binaries, verifies checksums, confirms
  data directories, and reports disk space.

### Rollback

Can be used if an update fails.

- `rollback-bitcoin.sh`: Restores the binaries from
  `linux/bin/backup/bitcoin/`, moving them into place rather than copying
  them, so the restore consumes the backup and a second rollback has
  nothing left to restore. It moves none of them unless every backup
  binary present carries a checksum `linux/checksums.sha256` recognizes.
- `rollback-electrum.sh`: Restores `electrum.AppImage` from
  `linux/bin/backup/electrum/`, moving it into place and consuming the
  backup the same way.

### Logging and Maintenance

- `rotate-bitcoin-log.sh`: Rotates `bitcoin-datadir/debug.log` by copying
  the current log file to a backup (`debug.log.1`, etc.) and starting a
  new log file.
- `monitor-bitcoin-log.sh`: Monitors the Bitcoin log for new
  errors/warnings and reports them on standard output, tracking progress
  by byte offset to avoid re-scanning or duplicating. A desktop
  notification is sent through `notify-send` where one can be delivered;
  a machine with no `notify-send` installed, or with no notification
  daemon on its session bus, gets a note instead of an error, the report
  on standard output being the whole of what such a run can deliver.
  `--no-notify` (or `PORTANODE_NO_NOTIFY=1`) suppresses the notification
  for a scheduled run.
- `health-check.sh`: Disk space + basic process checks.
- `clean-artifacts.sh`: Removes what a Linux desktop leaves on this
  folder: the trash directories the freedesktop.org Trash specification
  defines for a volume other than the one holding the user's home, and
  the temporary files a killed GLib save leaves beside the file it was
  replacing. Emptying the trash discards whatever was deleted into it.
- `set-permissions.sh`: Restricts `bitcoin-datadir/` and
  `electrum-datadir/` to the owner (`chmod 700`) on a filesystem that
  stores a Unix mode. exFAT stores none: the mode every file and
  directory reads is computed from the mount's `fmask` and `dmask`, so
  the `chmod` calls change nothing there. The script reads the mode back
  and reports which case it found, names `uid=<your uid>,fmask=077,
  dmask=077` as the mount options that restrict such a volume, and names
  `fmask=133` as the setting that removes the execute bit the launchers
  and the `linux/bin` binaries need. Its own comment carries the
  measurement, and `README.md`'s *Permissions* bullet under *Security
  Notes* has the exit statuses.

## Notes

- Each script above may be run from any working directory,
  `./linux/scripts/utilities/health-check.sh` from the folder's root among
  them. Each resolves that root from its own location, or from
  `PORTANODE_ROOT`, and reads the working directory for nothing.
- Most scripts require internet for downloads; ensure connectivity.
- Update scripts download, verify and unpack on the local temp
  directory, never on the removable volume, and clean up on exit.
- Update scripts verify PGP signatures for Bitcoin Core and Electrum
  downloads before installing, and fail closed: a bad signature, a
  missing signer key, or no `gpg` at all aborts the update rather than
  installing unverified binaries. Set `PORTANODE_ALLOW_UNVERIFIED=1` to
  bypass verification (not recommended). `README.md`'s *Updating
  Binaries* section has where to obtain each project's signing key, why a
  missing key rather than a missing signature is the usual cause of a
  validation failure, and how key pinning works.
- Backups are stored in `linux/bin/backup/`; rollbacks depend on these.
- `linux/checksums.sha256` is append-only: a new verified hash is added
  with `version=<x>`, and an entry already present is left as it is
  rather than being added again.
- Cleanup scripts are OS-specific; Linux cleanup only targets Linux
  artifacts, so a volume shared with macOS or Windows is cleaned of
  theirs by those platforms' own scripts.
- Health checks rely on process listing; a restricted `/proc` reduces
  detection accuracy, and the Bitcoin check falls back to `bitcoin-cli`
  and to the datadir's own artifacts.
- These scripts are run by their own path. The root `Bitcoin-Launcher.sh`,
  `Electrum-Launcher.sh` and `Utilities-Launcher.sh` each refuse Linux
  with "Linux is not supported yet", so none of them reaches this
  directory.
- Check script output for errors; refer to main README.md for
  troubleshooting.

## Smoke Check (Linux)

Run these in order after updates:

1. `linux/scripts/utilities/verify-binaries.sh`
1. `linux/scripts/utilities/validate-setup.sh`
1. `linux/scripts/utilities/health-check.sh`

## Dependencies

- Linux: `curl`, `gpg`, and either `sha256sum` (coreutils) or `shasum`.
- `set-permissions.sh` reads the filesystem through `findmnt`
  (util-linux), falling back to `stat -f` where it is absent.
- `monitor-bitcoin-log.sh` sends a desktop notification through
  `notify-send` (libnotify) where it is installed, and reports on
  standard output where it is not.
- General: Bash-compatible shell.
