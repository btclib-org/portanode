# PortaNode on Linux

This page holds what is true on Linux only. The root
[`README.md`](./../README.md) has the rest: getting the folder, the
launchers, updating, troubleshooting and the limitations.

## Binaries (`bin/`)

- `bitcoind`, `bitcoin-cli`, `bitcoin-qt`, `bitcoin-tx`, `bitcoin-util`,
  `bitcoin-wallet` and `bitcoin`. Bitcoin Core ships them for Linux in
  one archive, and `update-bitcoin.sh` installs them all from it.
- `electrum.AppImage`: the AppImage Electrum publishes, which
  `update-electrum.sh` installs unmodified under this fixed name.
- `backup/`: what the updaters replaced.

## Scripts (`scripts/`)

- The root `Bitcoin-Launcher.sh`, `Electrum-Launcher.sh` and
  `Utilities-Launcher.sh` open the menus of `Bitcoin-Launcher.sh`,
  `Electrum-Launcher.sh` and `Utilities-Launcher.sh` here.
- Every script under `scripts/bitcoin/`, `scripts/electrum/` and
  `scripts/utilities/` also runs by its own path, with `bash`:
  `bash scripts/bitcoin/mainnet-8333-qt.sh`.

## What Electrum needs from the machine

- **Read and write access to `/dev/fuse`**, through which the AppImage
  mounts itself. Without it the launchers stop and print the command
  that runs Electrum with `--appimage-extract-and-run`, which needs no
  privilege. Installing `libfuse2t64` does not help: this AppImage loads
  no FUSE library.
- **An executable AppImage on a mount without `noexec`.** The launchers
  stop where either fails; the root `README.md`'s *Troubleshooting* has
  the remedy.
- **The machine's own graphics libraries**, such as `libegl1` and Qt's.
  The launchers do not check them: Electrum exits naming the one that is
  missing.
- **An `electrum-datadir` that is not on exFAT.** It cannot hold the
  daemon's socket there, so the launchers stop and print the command
  that runs Electrum with `--dir` on another filesystem.

## Utilities

- `update-bitcoin.sh` installs the `linux-gnu` build for `x86_64` or
  `aarch64`, read from `uname -m`, and refuses any other architecture.
- `verify-binaries.sh` checks with `sha256sum` or `shasum`, whichever is
  installed.
- `rollback-bitcoin.sh` restores nothing unless every backup binary
  carries a checksum `linux/checksums.sha256` recognizes.
- `monitor-bitcoin-log.sh` reports on standard output, and sends a
  desktop notification through `notify-send` where one can be delivered.
- `health-check.sh` asks `bitcoin-cli` first, then the process list,
  then the datadir's `.cookie` and `bitcoind.pid`. Its Electrum check
  reads the process list alone, so a restricted `/proc` can hide a
  running Electrum.
- `clean-artifacts.sh` removes the trash directories a Linux desktop
  makes on a volume other than the home one, emptying that trash, and
  the temporary files a killed GLib save leaves. It removes nothing
  macOS or Windows leaves.
- `set-permissions.sh` restricts `bitcoin-datadir/` and
  `electrum-datadir/` to the owner with `chmod 700`, then reads the mode
  back. On exFAT the mode comes from the mount, so the script restricts
  nothing there. It names `uid=<your uid>,fmask=077,dmask=077` as the
  mount options that restrict the volume, and `fmask=133` as the one
  that stops the launchers and the binaries from running.
- The utilities need `bash`, `curl`, `gpg`, and `sha256sum` or `shasum`.
  `set-permissions.sh` reads the filesystem with `findmnt`, or `stat -f`
  without it. `monitor-bitcoin-log.sh` uses `notify-send` where it is
  installed.
