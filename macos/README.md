# macOS

macOS-specific binaries and scripts for PortaNode.

## Binaries (`bin/`)

- `Bitcoin-Qt.app`: Bitcoin Core GUI.
- `Electrum.app`: Electrum wallet.

Ensure these are executable. If not, run `chmod +x bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt bin/Electrum.app/Contents/MacOS/Electrum`.

## Scripts (`scripts/`)

- `bitcoin/`: Scripts to launch Bitcoin Core (e.g., `mainnet-8333-qt.command` for GUI).
- `electrum/`: Scripts to launch Electrum (e.g., `mainnet.command`).

Run by double-clicking or via terminal: `bash scripts/bitcoin/mainnet-8333-qt.command`.

## Data Folders

Data folders live at the repo root: `bitcoin-datadir/` and `electrum-datadir/`.

## Troubleshooting

- If scripts fail, check permissions: `chmod +x scripts/**/*.command`.
- For GUI issues, ensure XQuartz is installed if needed.
