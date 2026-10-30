# shellcheck shell=bash
# Tests for the macOS and Linux updaters' downgrade refusal and HTTPS-only
# fetches.
#
# Needs no network: the updaters run in a copy of the tree, with curl,
# pgrep and uname replaced by stubs on PATH, and OSTYPE set to the
# platform each is for. The curl_https checks start local servers, so
# they need python3 and openssl, and are skipped without them.
# compare-versions.ps1 runs through pwsh against the same cases as
# refuse_downgrade, and is skipped where pwsh is not on PATH.
set -uo pipefail

# bash looks for a bare name in the current directory, then in PATH. Found
# through PATH, $0 has no directory, so the directory below would be wrong.
case "$0" in */*) ;; *) [ -f "$0" ] || { echo "$0: run this script by its path, not by a name found through PATH" >&2; exit 1; } ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/../lib.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/portanode-tests.XXXXXX")"
SERVER_PIDS=""
# shellcheck disable=SC2329 # invoked by the EXIT trap below
cleanup() {
    for pid in $SERVER_PIDS; do
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
    done
    rm -rf "$WORK"
}
trap cleanup EXIT

pass() { echo "ok - $1"; }
fail() { echo "not ok - $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
skip() { echo "ok - SKIP: $1"; }

# shellcheck source=shared/utilities/lib.sh
. "$ROOT/shared/utilities/lib.sh"

# --- refuse_downgrade, and compare-versions.ps1 on the same cases ---------
# installed requested expected (pass: installs, refuse: stops)
CASES="
28.1 27.0 refuse
28.1 28.0.1 refuse
28.1 28.1 pass
28 28.0 pass
28.1 29.0 pass
4.5.8 4.10.0 pass
4.10.0 4.5.8 refuse
29.08 29.9 pass
unknown 1.0 pass
28.1 28.0rc1 refuse
28.0rc1 28.1 refuse
28.1 27.0;x refuse
UNKNOWN 1.0 refuse
99999999999999999999999999999999 1 refuse
1 99999999999999999999999999999999 pass
28.1 18446744073709551643.0 pass
28.1 028.01 pass
28.10 28.9 refuse
"
PWSH="$(command -v pwsh || true)"
PS1="$ROOT/win/scripts/utilities/compare-versions.ps1"
while read -r installed requested expected; do
    [ -n "$installed" ] || continue
    got=pass
    refuse_downgrade "$installed" "$requested" 0 X > /dev/null || got=refuse
    if [ "$got" = "$expected" ]; then
        pass "refuse_downgrade $installed -> $requested: $got"
    else
        fail "refuse_downgrade $installed -> $requested: $got, want $expected"
    fi
    if [ -n "$PWSH" ]; then
        verdict="$("$PWSH" -NoProfile -File "$PS1" \
          -Installed "$installed" -Requested "$requested")"
        got=refuse
        [ "$verdict" != "OK" ] || got=pass
        if [ "$got" = "$expected" ]; then
            pass "compare-versions.ps1 $installed -> $requested: $verdict"
        else
            fail "compare-versions.ps1 $installed -> $requested: $got, want $expected"
        fi
    fi
done <<< "$CASES"
[ -n "$PWSH" ] || skip "compare-versions.ps1: pwsh not found"
if refuse_downgrade 28.1 27.0 1 X > /dev/null; then
    pass "refuse_downgrade with ALLOW=1 installs 27.0 over 28.1"
else
    fail "refuse_downgrade with ALLOW=1 refuses 27.0 over 28.1"
fi

# --- no updater calls curl but through curl_https -------------------------
# Every line where curl is a word, curl_https and curl_rc being other words,
# outside a comment, except the message naming the index fetch's bound.
# The control holds each shape of a call it must catch, and the two
# shapes it must let pass.
bare_curl() {
    grep -nwE 'curl' "$@" \
      | grep -vE ':[0-9]+:[[:space:]]*#' \
      | grep -vF '"(curl --max-time 300)."'
}
cat > "$WORK/shapes.sh" <<'EOF'
curl -fL x
    curl -fL x
V="$(curl -fsSL x)"
V="$( curl -fsSL x)"
a | curl -s x
if curl -s x; then :; fi
! curl -s x
command curl -s x
a && curl -s x
curl_https -fL x
curl_rc=0
EOF
control="$(bare_curl /dev/null "$WORK/shapes.sh" | wc -l | tr -d ' ')"
bare="$(bare_curl \
  "$ROOT"/macos/scripts/utilities/update-*.sh \
  "$ROOT"/linux/scripts/utilities/update-*.sh)"
if [ "$control" -eq 9 ] && [ -z "$bare" ]; then
    pass "updaters call curl only through curl_https"
else
    fail "updaters call curl directly (control $control of 9): $bare"
fi

# --- curl_https against local servers ------------------------------------
if command -v python3 > /dev/null && command -v openssl > /dev/null; then
    openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=127.0.0.1 \
      -keyout "$WORK/key.pem" -out "$WORK/cert.pem" > /dev/null 2>&1
    # One HTTP and one HTTPS server; the HTTPS one answers /ok with 200
    # and /redirect with a 302 to the HTTP one. Each writes its port.
    # socketserver.TCPServer, not http.server.HTTPServer, whose bind calls
    # socket.getfqdn: on the macos-latest runner the first such call is
    # quick, and a later one can outlast the wait for the port below, so
    # the second server misses that wait. This shows it there, in its later
    # calls, though not on every runner:
    # for _ in 1 2 3 4 5; do time python3 -c 'import socket; print(socket.getfqdn("127.0.0.1"))'; done
    cat > "$WORK/server.py" <<'EOF'
import http.server, socketserver, ssl, sys
tls, portfile, target = sys.argv[1] == "tls", sys.argv[2], sys.argv[3]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/redirect":
            self.send_response(302)
            self.send_header("Location", target)
            self.end_headers()
            return
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok\n")
    def log_message(self, *args):
        pass
s = socketserver.TCPServer(("127.0.0.1", 0), H)
if tls:
    c = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    c.load_cert_chain(sys.argv[4], sys.argv[5])
    s.socket = c.wrap_socket(s.socket, server_side=True)
open(portfile, "w").write(str(s.server_address[1]))
s.serve_forever()
EOF
    python3 -I "$WORK/server.py" plain "$WORK/http.port" none &
    SERVER_PIDS="$SERVER_PIDS $!"
    for _ in $(seq 50); do [ -s "$WORK/http.port" ] && break; sleep 0.1; done
    HTTP="http://127.0.0.1:$(cat "$WORK/http.port")"
    python3 -I "$WORK/server.py" tls "$WORK/https.port" "$HTTP/" \
      "$WORK/cert.pem" "$WORK/key.pem" &
    SERVER_PIDS="$SERVER_PIDS $!"
    for _ in $(seq 50); do [ -s "$WORK/https.port" ] && break; sleep 0.1; done
    HTTPS="https://127.0.0.1:$(cat "$WORK/https.port")"
    # Each refusal has its control: plain curl fetching the same URL.
    # --proto alone refuses the redirect to HTTP too, so these checks do
    # not show that --proto-redir is passed; the curl log of the updater
    # runs below does.
    # -k because the certificate is self-signed.
    fetch() {
        local want="$1" what="$2"
        shift 2
        if "$@" > /dev/null 2>&1; then got=fetches; else got=refuses; fi
        if [ "$got" = "$want" ]; then pass "$what $got"; else fail "$what $got"; fi
    }
    fetch fetches "curl, plain HTTP," curl -fsS "$HTTP/"
    fetch refuses "curl_https, plain HTTP," curl_https -fsS "$HTTP/"
    fetch fetches "curl_https, HTTPS," curl_https -fsSk "$HTTPS/ok"
    fetch fetches "curl -L, HTTPS redirected to HTTP," curl -fsSkL "$HTTPS/redirect"
    fetch refuses "curl_https -L, HTTPS redirected to HTTP," \
      curl_https -fsSkL "$HTTPS/redirect"
else
    skip "curl_https against local servers: python3 or openssl not found"
fi

# --- the updaters themselves, in a copy of the tree -----------------------
TREE="$WORK/tree"
mkdir -p "$TREE"
git -C "$ROOT" ls-files -z | tar -C "$ROOT" --null -T - -cf - | tar -C "$TREE" -xf -

STUBS="$WORK/stubs"
mkdir -p "$STUBS"
# curl: logs its arguments; a HEAD (-I) succeeds, and any other request
# prints an index listing one old release from each publisher.
cat > "$STUBS/curl" <<'EOF'
#!/bin/bash
echo "$*" >> "$CURL_LOG"
for a in "$@"; do [ "$a" = "-fsIL" ] && exit 0; done
echo '<a href="bitcoin-core-27.0/">bitcoin-core-27.0/</a>'
echo '<a href="4.0.0/">4.0.0/</a>'
EOF
printf '#!/bin/sh\nexit 1\n' > "$STUBS/pgrep"
cat > "$STUBS/uname" <<'EOF'
#!/bin/sh
echo "$STUB_ARCH"
EOF
chmod +x "$STUBS/curl" "$STUBS/pgrep" "$STUBS/uname"

sha() {
    if command -v shasum > /dev/null; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        sha256sum "$1" | awk '{print $1}'
    fi
}

# install_fake PLATFORM ENTRY_PATH VERSION -- a binary at ENTRY_PATH whose
# hash PLATFORM/checksums.sha256 records under VERSION.
install_fake() {
    mkdir -p "$(dirname "$TREE/$2")"
    echo "fake $2" > "$TREE/$2"
    echo "$(sha "$TREE/$2")  $2  version=$3" >> "$TREE/$1/checksums.sha256"
}
install_fake macos macos/bin/Bitcoin-Qt.app/Contents/MacOS/Bitcoin-Qt 28.1
install_fake macos macos/bin/Electrum.app/Contents/MacOS/run_electrum 4.5.8
install_fake linux linux/bin/bitcoin-qt 28.1
install_fake linux linux/bin/electrum.AppImage 4.5.8

# run_updater OSTYPE ARCH SCRIPT ARGS... -- output in $OUT, status in $RC
run_updater() {
    local ostype="$1" arch="$2" script="$3"
    shift 3
    RC=0
    OUT="$(env -u PORTANODE_ROOT PATH="$STUBS:$PATH" OSTYPE="$ostype" \
      STUB_ARCH="$arch" CURL_LOG="$WORK/curl.log" TMPDIR="$WORK" \
      GNUPGHOME="$WORK/gnupg" bash "$TREE/$script" "$@" 2>&1)" || RC=$?
}

# expect WHAT RC PATTERN -- the last run exited RC and printed PATTERN
expect() {
    if [ "$RC" -eq "$2" ] && grep -q -- "$3" <<< "$OUT"; then
        pass "$1"
    else
        fail "$1 (exit $RC)"
        while IFS= read -r line; do echo "     $line"; done <<< "$OUT"
    fi
}

mkdir -m 700 "$WORK/gnupg"
: > "$WORK/curl.log"
# script ostype arch old new
UPDATERS="
macos/scripts/utilities/update-bitcoin.sh darwin24 arm64 27.0 29.0
macos/scripts/utilities/update-electrum.sh darwin24 arm64 4.0.0 4.6.0
linux/scripts/utilities/update-bitcoin.sh linux-gnu x86_64 27.0 29.0
linux/scripts/utilities/update-electrum.sh linux-gnu x86_64 4.0.0 4.6.0
"
while read -r script ostype arch old new; do
    [ -n "$script" ] || continue
    run_updater "$ostype" "$arch" "$script" --version "$old"
    expect "$script --version $old refuses" 1 "Refusing to install"
    run_updater "$ostype" "$arch" "$script"
    expect "$script refuses the index's $old" 1 "Refusing to install"
    run_updater "$ostype" "$arch" "$script" --version "$old" \
      --allow-downgrade --dry-run
    expect "$script --version $old --allow-downgrade proceeds" 0 \
      "Would install"
    run_updater "$ostype" "$arch" "$script" --version "$new" --dry-run
    expect "$script --version $new proceeds" 0 "Would install"
done <<< "$UPDATERS"

# Every curl the updaters ran carried both flags.
if [ -s "$WORK/curl.log" ] \
  && ! grep -v -- "--proto =https --proto-redir =https" "$WORK/curl.log" \
    > /dev/null; then
    pass "every curl the updaters ran was HTTPS-only"
else
    fail "a curl the updaters ran was not HTTPS-only"
    cat "$WORK/curl.log"
fi

finish
