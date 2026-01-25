# Electrum Data

Data directory for Electrum, including wallets and network-specific data.

## Folders

- `wallets/`: Mainnet wallets (default and named).
- `testnet/`: Testnet wallets and data.
- `regtest/`: Regtest wallets and data.

## Usage

Wallets are auto-created or loaded by Electrum scripts. Backup `wallets/` folder.

Set restrictive permissions: `chmod 700 .` (on Unix) or use folder properties (Windows).

## Configuration

Electrum uses its own config; no manual edits needed. For local server, use `mainnet-local-server-only` scripts.

## Troubleshooting

- Wallet issues: Check file permissions.
- Connection problems: Ensure Bitcoin node is running for local server mode.
