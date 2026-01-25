# Bitcoin Core Data

Configuration and data directory for Bitcoin Core.

## Files and Folders

- `bitcoin.conf`: Node configuration (e.g., dbcache, txindex).
- `blocks/`: Block data.
- `chainstate/`: Chain state database.
- `indexes/`: Indexes (e.g., txindex, coinstats).
- `wallets/`: Wallet files.
- `debug.log`: Logs.

## Configuration

Edit `bitcoin.conf` for settings like:
- `dbcache=4096`: Memory for database (MB).
- `maxmempool=4096`: Mempool size (MB).
- `prune=550`: Prune blocks to ~550MB.

## Backup

Backup `wallets/` regularly. For full node, consider external backups.

Set restrictive permissions: `chmod 700 .` (on Unix) or use folder properties (Windows).

## Troubleshooting

- Sync issues: Check `debug.log`.
- Disk space: Enable pruning or add more space.
