# PortaNode

## Portale (external disk) cross-platform Bitcoin full node.

PortaNode bundles scripts, binaries, and data for running Bitcoin Core and
Electrum on macOS and Windows.

## Folder structure

- `macos/`
  - `bin/`: macOS app bundles for Bitcoin Core and Electrum.
  - `scripts/`
    - `bitcoin/`: Bitcoin Core launch scripts (.command).
    - `electrum/`: Electrum launch scripts (.command).

- `win/`
  - `bin/`: Windows binaries (e.g., `electrum.exe`).
  - `scripts/`
    - `bitcoin/`: Bitcoin Core launch scripts (.bat).
    - `electrum/`: Electrum launch scripts (.bat).

- `bitcoin-datadir/`: Bitcoin Core configuration/data (e.g., `bitcoin.conf`).
- `electrum-datadir/`: Electrum data (wallets, regtest/testnet data).

## Notes

- Ensure the external disk is properly mounted and paths are adjusted as
  needed for portability.
- Scripts expect the bundled binaries in `macos/bin/` and `win/bin/`.
- Electrum includes a local-server-only launcher on both platforms
  (`mainnet-local-server-only` in each `electrum/` folder).
- Regtest peer connections (addnode targets):
  - Alice (18444) connects to Bob (18555) and Carol (18666).
  - Bob (18555) connects to Alice (18444) and Carol (18666).
  - Carol (18666) connects to Alice (18444) and Bob (18555).
