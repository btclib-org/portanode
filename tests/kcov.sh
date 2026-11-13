# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# Started as root in the Debian container coverage.yml starts, it runs
# tests/run.sh under kcov as a user of its own. It prints the share of lines
# covered, in total and per file, for the bash scripts outside tests/. It
# exits as the suite does, and 1 where the suite passed and the share is under
# the floor it is given, a percentage:
#
#   bash tests/kcov.sh <floor>

case "$0" in */*) ;; *) [ -f "$0" ] || {
    echo "$0: run this script by its path, not by a name found through PATH" >&2
    exit 1
} ;; esac
set -euo pipefail
FLOOR="${1:?usage: bash tests/kcov.sh <floor, a percentage>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"

apt-get update -qq
apt-get install -y -qq kcov bash git gnupg curl coreutils procps python3 file openssl > /dev/null

# A user of its own, because the suite skips the cases root reads past.
useradd -m suite
TREE=/home/suite/tree
OUT=/home/suite/kcov
cp -a "$SCRIPT_DIR/.." "$TREE"
mkdir "$OUT"
chown -R suite /home/suite

# --bash-parse-files-in-dir counts the lines of scripts the suite never
# starts. It also counts files bash never runs, among them a .bat, so those are
# excluded here.
status=0
su suite -c "kcov --bash-parse-files-in-dir=$TREE --include-path=$TREE \
    --exclude-path=$TREE/tests,$TREE/.git,$TREE/.github,$TREE/win,$TREE/.gitattributes,$TREE/.pre-commit-config.yaml \
    $OUT $TREE/tests/run.sh" || status=$?

under=0
python3 -I - "$OUT/run.sh/coverage.json" "$TREE/" "$FLOOR" << 'EOF' || under=1
import json, sys

report = json.load(open(sys.argv[1]))
covered, total = report["covered_lines"], report["total_lines"]
# Cut at two decimals rather than rounded, so that it never reads above the
# share: tests/README.md raises a floor to the whole percent at or under it.
cut = 10000 * covered // total
print(f"{cut // 100}.{cut % 100:02d}% of {total} lines")
for entry in sorted(report["files"], key=lambda entry: entry["file"]):
    name = entry["file"].removeprefix(sys.argv[2])
    print(f"{entry['percent_covered']:>7}% {entry['total_lines']:>5} {name}")
floor = float(sys.argv[3])
if 100 * covered < floor * total:
    sys.exit(f"under the floor of {floor:g}%")
print(f"at or over the floor of {floor:g}%")
EOF
[ "$status" -ne 0 ] || status=$under
exit "$status"
