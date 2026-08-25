# OS-specific binaries and scripts for PortaNode

## Binaries (`bin/`)

- `Bitcoin-Qt.app`: Bitcoin Core GUI.
- `Electrum.app`: Electrum wallet.

Ensure these are executable. If not, run:

```sh
chmod +x \
  bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt \
  bin/Electrum.app/Contents/MacOS/Electrum \
  bin/Electrum.app/Contents/MacOS/run_electrum
```

The Bitcoin updater also installs `bitcoind`, `bitcoin-cli`, `bitcoin-qt`,
`bitcoin-tx`, `bitcoin-util` and `bitcoin-wallet` here, which the `.app`
bundle does not ship, and sets their executable bit itself as part of
installing them; the root `README.md`'s *Permission denied on macOS* is
where a bit lost some other way is fixed.

## Scripts (`scripts/`)

- `bitcoin/`: Scripts to launch Bitcoin Core (e.g., `mainnet-8333-qt.command`
  for GUI).
- `electrum/`: Scripts to launch Electrum (e.g., `mainnet.command`).
- `utilities/`: Maintenance scripts (updates, verification, cleanup, logs).

Root launchers are available for specific areas: `Bitcoin-Launcher.*`,
`Electrum-Launcher.*`, and `Utilities-Launcher.*` (`.command` or `.sh`).

## Utilities Quickstart

Run these in order after updates:

1. `scripts/utilities/verify-binaries.sh`
1. `scripts/utilities/validate-setup.sh`
1. `scripts/utilities/health-check.sh`

## Data Folders

Data folders live at the repo root: `bitcoin-datadir/` and `electrum-datadir/`.

## Troubleshooting

- If a script fails to launch with a permission error, see the root
  `README.md`'s Troubleshooting section, under "Permission denied on
  macOS", for the one route by which that happens and what to do about
  it.
- For GUI issues, ensure XQuartz is installed if needed.
