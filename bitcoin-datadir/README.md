# Bitcoin Core Data

Configuration and data directory for Bitcoin Core.

For local installation this folder is typically in:

- `~/Library/Application Support/Bitcoin/` (macOS)
- `%LOCALAPPDATA%\Bitcoin` (Windows)
- `C:\Users\<YourUsername>\AppData\Local\Bitcoin` (Windows)

## Files and Folders

- `bitcoin.conf`: Node configuration (e.g., dbcache, txindex).
- `blocks/`: Block data (mainnet).
- `chainstate/`: Chain state database (mainnet).
- `indexes/`: Indexes (e.g., txindex, coinstats) (mainnet).
- `debug.log`: Logs (mainnet).
- `testnet3/`, `testnet4/`, `regtest/`: the same per-network files, each
  network keeping its own, wallets included.
- Mainnet wallets: this directory is already present before Bitcoin
  Core ever starts, so Bitcoin Core does not create a `wallets/`
  subfolder inside it. A named wallet gets its own subfolder directly
  under this directory, named after the wallet; the default (unnamed)
  wallet's own `wallet.dat` sits at this directory's own top level,
  separate from `blocks/`, `chainstate/`, `indexes/` and `debug.log`.
  Testnet3, testnet4 and regtest each get their own network directory
  created fresh, so a `wallets/` subfolder is created along with it and
  their wallets go there. A launcher echoes `WALLETDIR` at startup with
  the path it resolved.

## Configuration

Edit `bitcoin.conf` for settings like:

- `dbcache=4096`: Memory for database (MB).
- `maxmempool=4096`: Mempool size (MB).
- `prune=550`: Prune blocks to ~550MB.

## Wallets

Back up a named mainnet wallet's own subfolder, or the default wallet's
own `wallet.dat`, directly under this directory. Back up testnet3,
testnet4 or regtest wallets by backing up the corresponding
`testnet3/wallets/`, `testnet4/wallets/` or `regtest/wallets/`.

Set restrictive permissions: `chmod 700 .` (on Unix)
or use folder properties (Windows).

## Troubleshooting

- Sync issues: Check `debug.log`, in this directory for mainnet or in
  the network's own subfolder for testnet3, testnet4 or regtest.
- Disk space: Enable pruning or add more space.
