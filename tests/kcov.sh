# Copyright (c) The btclib developers
# Distributed under the MIT software license, see the accompanying
# LICENSE file or https://opensource.org/license/mit for the full text.

# shellcheck shell=bash
# Started as root in the Debian container kcov.yml starts, it runs tests/run.sh
# under kcov as a user of its own, and exits as the suite does. It prints the
# share of lines covered, in total and per file, for the bash scripts outside
# tests/.
#
#   bash tests/kcov.sh

case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
set -euo pipefail
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

python3 -I - "$OUT/run.sh/coverage.json" "$TREE/" <<'EOF'
import json, sys

report = json.load(open(sys.argv[1]))
print(f"{report['percent_covered']}% of {report['total_lines']} lines")
for entry in sorted(report["files"], key=lambda entry: entry["file"]):
    name = entry["file"].removeprefix(sys.argv[2])
    print(f"{entry['percent_covered']:>7}% {entry['total_lines']:>5} {name}")
EOF
exit "$status"
