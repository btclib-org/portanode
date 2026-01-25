#!/bin/bash
# Rotate Bitcoin debug log

LOG_FILE="bitcoin-datadir/debug.log"
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

# Move current log
mv "$LOG_FILE" "${LOG_FILE}.1"

# Create new log file (Bitcoin will recreate it)
touch "$LOG_FILE"

echo "Log rotated: $LOG_FILE"