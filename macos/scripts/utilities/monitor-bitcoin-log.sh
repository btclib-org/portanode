#!/bin/bash
# Monitor Bitcoin log for errors and send notifications

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOG_FILE="$ROOTDIR/bitcoin-datadir/debug.log"
LAST_CHECK_FILE="$ROOTDIR/.last_log_check"

if [ ! -f "$LOG_FILE" ]; then
    echo "Log file not found: $LOG_FILE"
    exit 0
fi

# Get last checked line
if [ -f "$LAST_CHECK_FILE" ]; then
    LAST_LINE=$(cat "$LAST_CHECK_FILE")
else
    LAST_LINE=0
fi

# Get current line count
CURRENT_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
if [ "$CURRENT_LINES" -lt "$LAST_LINE" ]; then
    LAST_LINE=0
    echo "0" > "$LAST_CHECK_FILE"
fi

if [ "$CURRENT_LINES" -gt "$LAST_LINE" ]; then
    # Check new lines for errors
    ERRORS=$(
      sed -n "$((LAST_LINE+1)),${CURRENT_LINES}p" "$LOG_FILE" \
        | grep -i "error\\|warning\\|failed" \
        | head -5
    )

    if [ -n "$ERRORS" ]; then
        echo "Bitcoin log errors detected:"
        echo "$ERRORS"
        # macOS notification
        if command -v osascript >/dev/null 2>&1; then
            NOTIFY_MSG="Bitcoin errors detected"
            NOTIFY_TITLE="PortaNode Alert"
            OSA_SCRIPT="display notification \"$NOTIFY_MSG\""
            OSA_SCRIPT="$OSA_SCRIPT with title \"$NOTIFY_TITLE\""
            osascript -e "$OSA_SCRIPT"
        fi
    fi

    # Update last check
    echo "$CURRENT_LINES" > "$LAST_CHECK_FILE"
fi
