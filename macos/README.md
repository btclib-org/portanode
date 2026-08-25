# OS-specific binaries and scripts for PortaNode

## Binaries (`bin/`)

- `Bitcoin-Qt.app`: Bitcoin Core GUI.
- `bitcoind`, `bitcoin-cli`, `bitcoin-qt`, `bitcoin-tx`, `bitcoin-util`,
  `bitcoin-wallet`: Bitcoin Core command-line tools, installed alongside
  the GUI bundle.
- `Electrum.app`: Electrum wallet.

Ensure these are executable. If not, run:

```sh
chmod +x \
  bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt \
  bin/Electrum.app/Contents/MacOS/Electrum \
  bin/Electrum.app/Contents/MacOS/run_electrum
```

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
