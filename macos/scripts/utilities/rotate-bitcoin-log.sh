#!/bin/bash
# Rotate Bitcoin debug log

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOG_FILE="$ROOTDIR/bitcoin-datadir/debug.log"
MAX_ROTATIONS=5

if [ ! -f "$LOG_FILE" ]; then
    echo "Log file not found: $LOG_FILE"
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

echo "Log rotated: $LOG_FILE"
