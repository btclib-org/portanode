#!/bin/bash
# Monitor Bitcoin log for errors and send notifications

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=macos/scripts/lib.sh
. "$SCRIPT_DIR/../lib.sh"
ROOTDIR="$(resolve_root "$SCRIPT_DIR")"
LOG_FILE="$ROOTDIR/bitcoin-datadir/debug.log"
LAST_CHECK_FILE="$ROOTDIR/.last_log_offset"

NO_NOTIFY=0
if [ "${PORTANODE_NO_NOTIFY:-}" = "1" ]; then
    NO_NOTIFY=1
fi
while [ $# -gt 0 ]; do
    case "$1" in
        --no-notify)
            NO_NOTIFY=1
            shift
            ;;
        *)
            echo "Usage: $(basename "$0") [--no-notify]" >&2
            exit 1
            ;;
    esac
done

if [ ! -f "$LOG_FILE" ]; then
    echo "Log file not found: $LOG_FILE"
    exit 0
fi

# Get last checked byte offset
if [ -f "$LAST_CHECK_FILE" ]; then
    LAST_OFFSET=$(cat "$LAST_CHECK_FILE")
else
    LAST_OFFSET=0
fi
case "$LAST_OFFSET" in
    ''|*[!0-9]*) LAST_OFFSET=0 ;;
esac

# Current size in bytes, from the filesystem's own metadata rather than by
# reading the file -- debug.log reaches hundreds of megabytes during initial
# block download, and this runs every few minutes.
CURRENT_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
if [ "$CURRENT_SIZE" -lt "$LAST_OFFSET" ]; then
    LAST_OFFSET=0
    echo "0" > "$LAST_CHECK_FILE"
fi

if [ "$CURRENT_SIZE" -gt "$LAST_OFFSET" ]; then
    # Seek to the stored offset instead of reading the file from byte zero.
    # tail -c is 1-indexed, hence +1.
    ERRORS=$(
      tail -c "+$((LAST_OFFSET+1))" "$LOG_FILE" \
        | grep -i "error\\|warning\\|failed" \
        | head -5
    )

    if [ -n "$ERRORS" ]; then
        echo "Bitcoin log errors detected:"
        echo "$ERRORS"
        # macOS notification
        if [ "$NO_NOTIFY" -eq 0 ] && command -v osascript >/dev/null 2>&1; then
            NOTIFY_MSG="Bitcoin errors detected"
            NOTIFY_TITLE="PortaNode Alert"
            OSA_SCRIPT="display notification \"$NOTIFY_MSG\""
            OSA_SCRIPT="$OSA_SCRIPT with title \"$NOTIFY_TITLE\""
            osascript -e "$OSA_SCRIPT"
        fi
    fi

    # Update last check
    echo "$CURRENT_SIZE" > "$LAST_CHECK_FILE"
fi
