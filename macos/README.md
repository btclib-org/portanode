# OS-specific binaries and scripts for PortaNode.

## Binaries (`bin/`)

- `Bitcoin-Qt.app`: Bitcoin Core GUI.
- `Electrum.app`: Electrum wallet.

Ensure these are executable. If not, run
`chmod +x bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt bin/Electrum.app/Contents/MacOS/Electrum bin/Electrum.app/Contents/MacOS/run_electrum`.

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
2. `scripts/utilities/validate-setup.sh`
3. `scripts/utilities/health-check.sh`

## Data Folders

Data folders live at the repo root: `bitcoin-datadir/` and `electrum-datadir/`.

## Troubleshooting

- If scripts fail, check permissions: `chmod +x scripts/**/*.command`.
- For GUI issues, ensure XQuartz is installed if needed.
