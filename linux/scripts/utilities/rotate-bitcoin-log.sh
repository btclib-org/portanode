#!/bin/bash
# Rotate Bitcoin debug log (Linux)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=linux/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
LOG_FILE="$ROOTDIR/bitcoin-datadir/debug.log"
MAX_ROTATIONS=5

if [ ! -f "$LOG_FILE" ]; then
    echo "Log file not found: bitcoin-datadir/debug.log"
    exit 0
fi

# Rotate existing logs
for ((i=MAX_ROTATIONS-1; i>=1; i--)); do
    if [ -f "${LOG_FILE}.$i" ]; then
        mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i+1))"
    fi
done

# Copy and truncate current log to avoid losing the file handle
cp "$LOG_FILE" "${LOG_FILE}.1"
: > "$LOG_FILE"

# The monitor's stored offset is now past the end of the truncated file; clear
# it here rather than leaving the monitor to catch the mismatch on its next
# run, which is a race it can lose (see monitor-bitcoin-log.sh).
rm -f "$ROOTDIR/.last_log_offset"

echo "Log rotated: bitcoin-datadir/debug.log"
