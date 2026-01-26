# Windows

OS-specific binaries and scripts for PortaNode.

## Binaries (`bin/`)

- `bitcoin-*.exe`: Bitcoin Core executables (qt for GUI, cli for command-line, etc.).
- `electrum.exe`: Electrum wallet.

## Scripts (`scripts/`)

- `bitcoin/`: Scripts to launch Bitcoin Core (e.g., `mainnet-8333-qt.bat` for GUI).
- `electrum/`: Scripts to launch Electrum (e.g., `mainnet.bat`).
- `utilities/`: Maintenance scripts (updates, verification, cleanup, logs).

Root launchers are available for specific areas: `Bitcoin-Launcher.bat`, `Electrum-Launcher.bat`, and `Utilities-Launcher.bat`.

## Data Folders

Data folders live at the repo root: `bitcoin-datadir/` and `electrum-datadir/`.

## Troubleshooting

- If scripts fail, ensure antivirus isn't blocking executables.
- For path issues, run as administrator or check drive letters.
