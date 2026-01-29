# Suggested Fixes

- The update scripts are pinned to Bitcoin Core 30.2,
  while the docs say “download latest” and recommend the update scripts.
  Users will assume “latest” but won’t get it.
- validation enforces 100GB free, but the README says 700GB
  for a full mainnet sync. This can report “OK” on disks that
  are too small for the advertised use case.

# Possible Improvements

Add Electrum Personal Server
Add a --version argument to update scripts (still defaulting to pinned).
Add a --dry-run option for update/rollback.
Add --no-notify option to log monitors.
Switch log monitor to track byte offsets instead of line counts for big logs.
