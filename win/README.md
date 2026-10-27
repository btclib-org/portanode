# PortaNode on Windows

This page holds what is true on Windows only. The root
[`README.md`](./../README.md) has the rest: getting the folder, the
launchers, updating, troubleshooting and the limitations.

## Binaries (`bin/`)

- `bitcoin-qt.exe`, `bitcoind.exe`, `bitcoin-cli.exe`, `bitcoin-tx.exe`,
  `bitcoin-util.exe`, `bitcoin-wallet.exe` and `bitcoin.exe`. Several
  scripts and health checks expect the helpers beside `bitcoind.exe` and
  `bitcoin-qt.exe`.
- `electrum.exe`: the standalone build, which `update-electrum.bat`
  installs. The launchers refuse the portable build of the same
  release, which keeps its data in `electrum_data` under the directory
  the launcher was started from and discards the `--dir` they pass.
- `backup/`: what the updaters replaced.

## Scripts (`scripts/`)

- `bitcoin/`, `electrum/` and `utilities/` hold `.bat` files, which run
  when double-clicked in Explorer, or from Command Prompt:
  `scripts\bitcoin\mainnet-8333-qt.bat`.
- The `.ps1` files under `utilities/` are not entry points: a `.bat`
  calls each with what it needs.
- The root launchers are the `.bat` or `.ps1` ones.

## Utilities

- `update-bitcoin.bat` installs the `win64` build, and unpacks it in
  `%TEMP%`.
- `rollback-bitcoin.bat` restores `bitcoin-qt.exe` and the command-line
  tools together, since `update-bitcoin.bat` backs them all up.
- `monitor-bitcoin-log.bat` shows a toast, or a MessageBox where toasts
  are unavailable, or else a console warning. The MessageBox waits until
  someone dismisses it.
- `clean-artifacts.bat` removes the files Windows leaves, and only those.
- `set-permissions.bat` restricts `bitcoin-datadir/` and
  `electrum-datadir/` to `%USERDOMAIN%\%USERNAME%`, then reads each
  directory's ACL back and reports what it found. exFAT, FAT32 and FAT
  hold no ACL, and are reported by name.

## Troubleshooting

- If scripts fail, ensure antivirus isn't blocking executables.
- For path issues, run as administrator or check drive letters.
