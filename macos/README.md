# PortaNode on macOS

This page holds what is true on macOS only. The root
[`README.md`](./../README.md) has the rest: getting the folder, the
launchers, updating, troubleshooting and the limitations.

## Binaries (`bin/`)

- `Bitcoin-Qt.app` and `Electrum.app`.
- `bitcoind`, `bitcoin-cli`, `bitcoin-qt`, `bitcoin-tx`, `bitcoin-util`,
  `bitcoin-wallet` and `bitcoin`, which the `.app` bundle does not ship.
  `update-bitcoin.sh` installs them beside it. The regtest `-cli`
  launchers need `bitcoind` and `bitcoin-cli`, and `health-check.sh`
  reads the sync status with `bitcoin-cli`.
- `backup/`: what the updaters replaced.

Some Electrum builds ship `run_electrum` instead of `Electrum` inside the
app bundle; the launchers accept either.

If an app does not start because it is not executable, run, from this
directory:

```sh
chmod +x \
  bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt \
  bin/Electrum.app/Contents/MacOS/Electrum \
  bin/Electrum.app/Contents/MacOS/run_electrum
```

`update-bitcoin.sh` sets the command-line tools' executable bit when it
installs them. They are in no clone or source archive, so running the
updater again, not taking the folder again, restores it.

## Scripts (`scripts/`)

- `bitcoin/` and `electrum/` hold the `.command` launchers, which run
  when double-clicked in Finder. From Terminal, run one with `bash`:
  `bash scripts/bitcoin/mainnet-8333-qt.command`.
- `utilities/` holds the `.sh` maintenance scripts, run from Terminal.
- The root launchers are the `.command` or `.sh` ones.

## Electrum on exFAT

The Electrum launchers refuse an `electrum-datadir` on exFAT, which
cannot hold the daemon's socket. Their message says how to start
Electrum with `--dir` on APFS instead.

## Utilities

- `update-bitcoin.sh` downloads the build for this Mac's architecture,
  `x86_64` or `arm64`. `update-electrum.sh` mounts Electrum's DMG to
  install from it.
- `verify-binaries.sh` checks with `shasum`, and needs `bash`: run it
  with `bash` where your default `sh` is not bash.
- `rollback-bitcoin.sh` restores `Bitcoin-Qt.app` only.
  `update-bitcoin.sh` overwrites the command-line tools with no backup,
  so they stay at the version the last update installed, and running
  it again brings the app back to that version.
- `monitor-bitcoin-log.sh` sends a macOS notification when it finds an
  error or a warning.
- `health-check.sh` relies on the process list, which some sandboxed
  environments restrict.
- `clean-artifacts.sh` removes the `._*` and `.DS_Store` files macOS
  leaves, and only those.
- `set-permissions.sh` restricts `bitcoin-datadir/` and
  `electrum-datadir/` to the owner with `chmod 700`, and drops any ACL,
  since an ACL entry, inherited ones included, can grant another account
  access that `chmod` does not revoke. On exFAT or FAT32 macOS reports a
  fixed mode whatever `chmod` asks, and holds no ACL, so the script
  restricts nothing there and says so.
- The utilities need `curl`, `shasum`, `hdiutil` and `bash`, and the
  updaters `gpg`.

## Troubleshooting

- For GUI issues, ensure XQuartz is installed if needed.
