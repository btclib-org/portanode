# Binaries

Place the app bundles here:

- `Bitcoin-Qt.app`
- `Electrum.app`

These apps are launched by the scripts in `macos/scripts/`.
Update scripts store backups in `backup/` and temporary downloads in
`.tmp-downloads/`.

The Bitcoin updater also installs `bitcoin-cli` here (the `.app` GUI bundle
ships without it); the health check uses it to read sync status.
