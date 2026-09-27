#!/bin/bash
# Monitor Bitcoin log for errors and send notifications (Linux)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=linux/scripts/lib.sh
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
    echo "Log file not found: bitcoin-datadir/debug.log"
    exit 0
fi

# The desktop notification is an addition to the report on stdout, never the
# report itself. notify-send is libnotify's client and delivers nothing on
# its own: it calls org.freedesktop.Notifications on the session bus, and a
# machine with no notification daemon has no such name to call. Measured on
# a GitHub Actions ubuntu-latest runner with libnotify-bin installed and no
# session bus, "notify-send probe body" exits 1 and prints
# "GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown: The name
# org.freedesktop.Notifications was not provided by any .service files".
# That same image carries no notify-send at all until libnotify-bin is
# installed, so both halves -- absent binary and absent daemon -- are
# ordinary rather than corner cases, and a headless or cron run is exactly
# where this utility is most useful. Neither is treated as an error: the
# errors are already on stdout above the call, which is the whole of what
# such a run can deliver.
notify_desktop() {
    local title="$1" message="$2"
    if ! command -v notify-send >/dev/null 2>&1; then
        echo "Note: notify-send not found; the errors above are the report."
        return 0
    fi
    if ! notify-send "$title" "$message" 2>/dev/null; then
        echo "Note: notify-send reached no notification daemon; the errors" \
             "above are the report."
    fi
    return 0
}

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
# block download, and this runs every few minutes. "stat -c%s" is GNU stat's
# spelling of macOS's "stat -f%z".
# A read that fails exits before the offset is written, so the part of the
# log it could not read is read again on the next run rather than counted as
# checked.
CURRENT_SIZE=$(stat -c%s "$LOG_FILE") || {
    echo "Error: bitcoin-datadir/debug.log could not be read."
    exit 1
}
if [ "$CURRENT_SIZE" -lt "$LAST_OFFSET" ]; then
    LAST_OFFSET=0
    echo "0" > "$LAST_CHECK_FILE"
fi

if [ "$CURRENT_SIZE" -gt "$LAST_OFFSET" ]; then
    # Seek to the stored offset instead of reading the file from byte zero.
    # tail -c is 1-indexed, hence +1.
    # The subshell answers with tail's own status: grep exits 1 where nothing
    # matches, and a head inside the pipe would end it early and hand tail a
    # SIGPIPE, so the first five are taken after the matches are captured.
    MATCHES=$(
      tail -c "+$((LAST_OFFSET+1))" "$LOG_FILE" \
        | grep -i "error\\|warning\\|failed"
      exit "${PIPESTATUS[0]}"
    ) || {
        echo "Error: bitcoin-datadir/debug.log could not be read."
        exit 1
    }
    ERRORS=$(printf '%s\n' "$MATCHES" | head -5)

    if [ -n "$ERRORS" ]; then
        echo "Bitcoin log errors detected:"
        echo "$ERRORS"
        if [ "$NO_NOTIFY" -eq 0 ]; then
            notify_desktop "PortaNode Alert" "Bitcoin errors detected"
        fi
    fi

    # Update last check
    echo "$CURRENT_SIZE" > "$LAST_CHECK_FILE"
fi
