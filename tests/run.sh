# shellcheck shell=bash
# Runs every test file under tests/sh/, each in a process of its own under
# the bash running this one, and exits 1 where any of them failed:
#
#   bash tests/run.sh
#   /bin/bash tests/run.sh    # the bash macOS starts a .command with

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"

echo "# bash $BASH_VERSION"
failed=""
for file in "$SCRIPT_DIR"/sh/*.sh; do
    echo "# ${file#"$SCRIPT_DIR"/}"
    "$BASH" "$file" || failed="$failed ${file#"$SCRIPT_DIR"/}"
done

if [ -n "$failed" ]; then
    echo "Failed:$failed"
    exit 1
fi
echo "Every test file passed."
