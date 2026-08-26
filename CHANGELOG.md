# Changelog

All notable changes to PortaNode will be documented in this file.

The format is based on [Calendar Versioning](https://calver.org/),
using YYYY.MM.DD format.

## [2026.01.29] - git main branch

- **`verify-binaries`'s checksum-file parser lives once, in
  `shared/utilities/lib.sh`'s `verify_binaries`, and an empty checksum
  file no longer reads as "Binaries verified."** (closes #143)
  (closes #152) (closes #139). `macos/scripts/utilities/
  verify-binaries.sh` and `linux/scripts/utilities/verify-binaries.sh`
  ran the identical parser inline, differing only in the checksum file
  and the path prefix each filtered on; both are now a call into the
  shared function, which takes both as required arguments rather than
  defaulting either the way `update_checksum` and its neighbours default
  to `macos/checksums.sha256`. Where the checksum file, once filtered to
  the caller's own prefix, has no entry at all — `linux/checksums.sha256`
  ships with none, so this is a fresh clone's actual state on Linux —
  the script now prints "Nothing to verify" and exits 0 instead of
  reporting a success that checked nothing; the PowerShell half gets the
  same distinction. `win/scripts/utilities/verify-binaries.ps1` also
  stops assigning its per-file hash matches to `$matches`, PowerShell's
  own automatic variable populated by `-match`/`-cmatch`, renaming the
  local to `$hashMatches`.
- **`README.md` recommends a filesystem per audience instead of exFAT
  alone** (closes #131): a table covering each of macOS, Windows and
  Ubuntu on its own, each pairing, and all three, with exFAT kept as
  the answer for a pairing or the whole three rather than presented as
  the tree's only choice. The single-platform rows name each platform's
  own filesystem; the pairings that are not exFAT's answer name
  Ubuntu's in-tree `ntfs3` driver instead. exFAT's own cost carries two
  different promises rather than one: macOS synthesises the execute bit
  as always-on, measured by mounting an exFAT image and running a
  script whose mode denies it, where Ubuntu's driver computes a mode
  from the mount's `fmask`/`umask` instead, documented by the driver
  and not measured in this repository — a restrictive mount can leave a
  script unexecutable on Ubuntu where macOS never would.
- **Every per-network bitcoin/electrum launcher under `macos/scripts/`
  and `linux/scripts/bitcoin/`, and the root-level
  `*-Launcher.command`/`*-Launcher.sh` pairs, source the shared
  `resolve_root` forwarder instead of repeating the root arithmetic
  inline, and resolve `ROOTDIR` through a symlink the same way they do
  when run directly** (closes #140) (closes #150). Each replaces its own
  `cd "$(dirname "$0")/../../.." && pwd -P` with
  `SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd -P)"`,
  followed by sourcing `../lib.sh` (or, for the root launchers,
  `macos/scripts/lib.sh` and `shared/lib.sh`) and calling `resolve_root
  "$SCRIPT_DIR"`, matching `linux/scripts/electrum/`'s own launchers.
  Measured on macOS: a launcher reached through a symlink in its own
  directory and through one two directories away both resolve the same
  `ROOTDIR` as running the file directly, and `PORTANODE_ROOT` still
  takes precedence through either symlink form; the inline form resolved
  `ROOTDIR` to `/` for the different-directory case before this fix.
  Opened through `open` -- the call Finder's own double-click makes on a
  `.command` file -- a symlinked launcher already receives its target's
  own path in `$0` rather than the link's, so `readlink -f` is a no-op
  there and the case it exists for is a direct shell invocation through
  the symlink. `win/scripts/**`'s `.bat` launchers already resolve their
  own path through `root.bat`'s `:resolve_root`, unchanged here.
- **`shared/lib.sh`'s header names `macos/scripts/lib.sh` and
  `linux/scripts/lib.sh` as the forwarders that exist, and
  `resolve_root`'s comment on accepting one platform directory no longer
  rests on `linux/` being absent** (closes #142).
- **`linux/scripts/README.md` gives that directory the entry point
  `macos/scripts/README.md` and `win/scripts/README.md` each already
  have** (closes #159): the `bitcoin/`, `electrum/` and `utilities/`
  folders and what each script under them does, and the `lib.sh` and
  `utilities/lib.sh` forwarders the scripts under `electrum/` and
  `utilities/` source. Its *Usage* section runs a script with `bash`
  rather than by double-clicking, and says that the root
  `Bitcoin-Launcher.sh`, `Electrum-Launcher.sh` and
  `Utilities-Launcher.sh` each currently refuse Linux rather than
  reaching this directory.
- **`macos/checksums.sha256` and `win/checksums.sha256`'s `Verify with:` lines
  are replaced with commands that actually verify the file, and all three
  `checksums.sha256` headers drop the `Generated with:` line that invited
  overwriting an append-only file** (closes #146, closes #147). `-c` reads an
  entry's `version=` field as part of the path it names, so
  `shasum -a 256 -c macos/checksums.sha256` failed every entry on a clean
  install; measured on macOS 26.6.2 (`shasum` 6.02) against a fixture whose
  recorded hashes matched: `FAILED open or read` on every entry, exit 1. The
  macOS header now strips the field first, the way `linux/checksums.sha256`
  already does for #134:
  `sed 's/  version=.*//' macos/checksums.sha256 | shasum -a 256 -c -`, measured
  on the same machine against the same fixture — `OK` and exit 0 on a match,
  `FAILED` and exit 1 on a modified binary, `FAILED open or read` and exit 1 on
  a missing one. `shasum` and `sha256sum` are not guaranteed on Windows, so
  `win/checksums.sha256`'s header instead names a PowerShell one-liner that
  filters to the 64-hex-character lines and compares each with `Get-FileHash`,
  measured on `windows-latest` (`actions/checkout@v5`, native PowerShell)
  against a fixture in the same format: `OK` on a match, `FAILED` on a modified
  binary, `FAILED (missing)` on a missing one. The
  `Generated with: shasum -a 256 <files> > <file>` line every header carried
  truncates a file `CLAUDE.md` states is append-only, and writes two fields
  where the `Format:` line documents three; `update_checksum` in
  `shared/utilities/lib.sh` is the only writer, which the
  `Integrity/rollback only` paragraph beside it already states, so the line is
  removed rather than corrected to name that function a second time.
- **`CLAUDE.md` states that a commit subject is one physical line, and
  names the read that shows one as it will land** (closes #130):
  `git show -s --format=%B <sha> | head -1`. `%s` takes everything up to
  the first blank line and joins it, so a subject wrapped across two
  physical lines reads as one whole sentence through it and through
  `git log --oneline`; the squash does not join, taking the first
  physical line as the title and moving the remainder into the body. The
  eighty-column wrap stated in the same section is named there as a rule
  for files in the tree, that being what a subject gets wrapped to match.
- **Every Windows regtest CLI launcher's `bitcoind.exe` now actually
  starts, and `win/scripts/bitcoin/lib.bat`'s `:require_deleted` comment
  cites a measurement instead of documentation** (closes #133). Measured
  on `windows-latest`: a `^` at the end of a line continues a batch
  file's line to the next only while cmd's quote state is closed, and is
  a literal character instead of a continuation inside an open quote.
  The doubled-quote argument `regtest-18444-Alice-cli.bat`,
  `regtest-18555-Bob-cli.bat`, `regtest-18666-Carol-cli.bat` and their
  `-clean` counterparts build for `bitcoind.exe` and for the
  `bitcoin-cli.exe`/`doskey` console leaves the quote state open partway
  through, so the `^` split these six files used was swallowed as
  literal text rather than read as a continuation, and no `bitcoind.exe`
  process started at all — confirmed end to end for Alice's `-clean`
  launcher with a stand-in binary, absent before the fix and present
  with every argument after it. The other five launchers build the
  identical argument, so the same fix applies to them; each now
  assembles it in a variable across single-line `set` statements
  instead of `^`. `rmdir /s /q` exits 0 for a directory that never
  existed, not the nonzero the comment had cited from documentation,
  and exits 0 as well when a file held open inside blocks the deletion,
  confirming the comment's other premise; `:require_deleted` already
  checked the directory's own resulting state rather than `rmdir`'s
  exit code, so its behavior is unchanged.
- **`linux/checksums.sha256`'s header names a verification command that
  exists on a bare Linux install and that reads this file's own entry
  format** (closes #134). It named `shasum -a 256 -c
  linux/checksums.sha256`, which fails on both counts. Measured on
  `ubuntu-latest` (Ubuntu 24.04.4, `sha256sum` GNU coreutils 9.4,
  `shasum` 6.04): with `/usr/bin/shasum` moved aside that command exits
  127 with `command not found`, `shasum` shipping from Perl's
  `Digest::SHA` rather than from coreutils. And `-c` does not read this
  file even where `shasum` is present — `update_checksum` writes
  `<sha256>  <path>  version=<semver>`, and `sha256sum -c` and
  `shasum -a 256 -c` alike take that third field as part of the path, so
  a file whose recorded hashes all match still exits 1 with `FAILED open
  or read`. The header now names
  `sed 's/  version=.*//' linux/checksums.sha256 | sha256sum -c -`, run
  on the same runner: exit 0 with `OK` against matching binaries, exit 1
  with `FAILED` against a modified one, exit 1 with `FAILED open or
  read` against a missing one. `macos/checksums.sha256` and
  `win/checksums.sha256` carry the same `-c` line and are left to their
  own platforms (issue #146); the `Generated with:` line all three carry
  is issue #147.
- **`linux/scripts/utilities/` carries the utilities the macOS tree
  carries, and `set-permissions` reads the mode back rather than
  reporting success** (closes #121). `clean-artifacts.sh`,
  `health-check.sh`, `monitor-bitcoin-log.sh`, `rotate-bitcoin-log.sh`,
  `set-permissions.sh`, `validate-setup.sh` and `verify-binaries.sh` join
  the updaters and the rollback pair, with the directory's own
  `README.md`; `verify-binaries.sh` reads `linux/checksums.sha256` and
  `health-check.sh` and `validate-setup.sh` expect `linux/bin`.
  `set-permissions.sh`'s subject is different from the macOS one's, and
  measured on a loopback exFAT image on a `ubuntu-latest` runner rather
  than derived from the driver: exFAT stores no Unix mode, a mount naming
  no mask reported `fmask=0022,dmask=0022` so every file read `rwxr-xr-x`
  and every directory `drwxr-xr-x`, and `chmod 700` exited 0 for the
  volume's owner while the directory went on reading `drwxr-xr-x` — and
  exited 1, "Operation not permitted", for anybody else. So the execute
  bit survives those masks, where macOS synthesises `rwx------` whatever
  `chmod` asked. `uid=<uid>,fmask=077,dmask=077` restricts such a volume
  and keeps the owner's execute bit; `fmask=133` is what removes it,
  a file then reading `rw-r--r--` and running it directly failing with
  exit 126. What a desktop automounter passes is not measured, a loopback
  image having none, which is why the script reads the mode and the mount
  options back rather than predicting either.
  `monitor-bitcoin-log.sh` degrades where a desktop notification cannot
  be delivered: that runner image carries no `notify-send` until
  `libnotify-bin` is installed, and with no notification daemon on the
  session bus it exits 1 with
  `org.freedesktop.DBus.Error.ServiceUnknown`, so the errors already on
  standard output are reported as the whole of the run.
  `health-check.sh` makes one `pgrep -f` pass where the macOS half makes
  a second over process names: a process name was truncated to fifteen
  characters there, so `electrum.AppImage` read back as
  `electrum.AppIma` and `pgrep -x` refused a pattern that long outright.
- **`claude-review.yml`'s `claude_args` comment named `gh pr comment`,
  which this workflow does not use, and left out `gh pr review`, which
  it does** (issue btclib-org/.github#398). The comment justifies
  keeping the flag folded rather than literal by the width of a line
  spelling the `gh pr` subcommands out, and it now spells out the ones
  the file uses: `diff` for the diff, `review` for the ack of record
  posted with `gh pr review --comment`, and `view` for the pull
  request's title and description.
- **`update-electrum` installs Electrum on Linux from the signed AppImage
  electrum.org publishes, unmodified, rather than extracting it**
  (closes #118). `linux/scripts/utilities/update-electrum.sh` scrapes
  `download.electrum.org` for the newest version the way the macOS
  updater already does, verifies `electrum-<version>-x86_64.AppImage`
  against its detached signature through `pgp_verify_or_fail` and the
  fingerprint already pinned in `keys/electrum.fingerprints`, and
  installs it as `linux/bin/electrum.AppImage` through `install_verified`.
  `linux/scripts/utilities/rollback-electrum.sh` restores the previous
  AppImage from `linux/bin/backup/electrum`, refusing unless its checksum
  is recognized. Measured on a `ubuntu-latest` runner against
  `electrum-4.8.1-x86_64.AppImage`: the AppImage runs without
  `libfuse2t64` installed, `ldd` reporting it "not a dynamic executable"
  and `strings` showing it statically links `squashfuse` rather than
  loading `libfuse.so.2` -- so the runtime dependency this issue was
  filed to work around does not hold for the artifact electrum.org ships
  today, and installing `libfuse2t64` changed nothing about how it ran.
  Extraction was rejected on its own measurement: two untouched
  extractions of the same AppImage hash identically with `tree_hash`, but
  the first real execution of the extracted tree writes
  `__pycache__/*.pyc` files into it as a side effect of Python merely
  importing its own standard library, which would silently invalidate a
  checksum recorded right after installation the first time Electrum
  actually runs.
- **`linux/scripts/bitcoin/` launches Bitcoin Core on Linux, at parity
  with the macOS launchers it is transliterated from** (closes #119).
  Every network and node `macos/scripts/bitcoin/` launches has a Linux
  counterpart: mainnet, testnet3, testnet4, and the three named regtest
  nodes each with a GUI, a CLI and a `-clean` variant. `linux/bin/`
  carries `bitcoin-qt` as a plain executable rather than an app bundle,
  so every launcher points at it directly instead of at a bundle's
  `Contents/MacOS/` path. `mainnet-8333-qt.sh`'s second-instance guard
  reads `ps -eo command=` — the GNU/procps form, `ps -ax -o command=`
  being BSD-specific — into the same `tolower()`-based `awk` match the
  macOS launcher already carries after #106; a Linux `bitcoin-qt`
  process is already lowercase, so the match does not depend on that
  fix the way the macOS one does. `-clean` launchers stop when their
  wipe fails, matching #114 on the other two platforms, and the
  regtest nodes keep the distinct `-rpcport` values (18443 default for
  Alice, 18554 for Bob, 18665 for Carol) that stop a later node from
  binding an earlier one's RPC port.
- **`claude-review.yml` converges with `btclib-org/.github`'s current
  copy: a `CLAUDE_REVIEW_ENABLED` job-level gate, the guard reading the
  SDK's `api_error_status` and `stop_reason`, and the verdict posted as
  a review of type `COMMENT`** (issue btclib-org/.github#364,
  btclib-org/.github#385, btclib-org/.github#340). Both jobs carry
  `if: vars.CLAUDE_REVIEW_ENABLED == 'true'`, an organization variable
  that is currently unset, so a skip replaces the `is_error: true`
  failure every `pull_request` run of this workflow has shown since
  2026-08-25. `Refuse to report a review that never ran` reads
  `api_error_status`, `stop_reason` and `.result` from the SDK's
  execution file rather than the action's own sanitized log. The
  verdict is posted with `gh pr review --comment`, never `--approve` or
  `--request-changes`, `NACK <sha>` joining `ACK <sha>` and `CHANGES
  REQUESTED <sha>`; `Refuse to report anything but an ack of this head`
  drops the approve/request-changes state cross-check a `COMMENT`
  review has no state for. The header's `main-self-merge` paragraph is
  corrected to match: a `COMMENT` review never supplies the ruleset's
  approving-review count, so this workflow was never a route to it.
- **`linux/scripts/electrum/` launches Electrum on Linux, at parity with
  the macOS and Windows halves** (closes #120). `mainnet.sh`,
  `testnet3.sh`, `testnet4.sh`, `regtest.sh` and
  `mainnet-local-server-only.sh` pass Electrum's own network flags,
  which are the same on every platform, and the shared
  `electrum-datadir/`: that directory is not per-platform, so a wallet
  made under one platform's launcher is the one the others open. What
  differs is the invocation — `linux/bin/electrum.AppImage` is run
  directly, where macOS goes through `open -n` on an app bundle — and
  `ROOTDIR`, resolved through `linux/scripts/lib.sh` rather than by
  repeating that file's path arithmetic, from `readlink -f "$0"` so that
  a launcher started through a symlink resolves from its own directory
  rather than the link's. A launcher that cannot find the
  AppImage says so and exits non-zero, and so does one that finds a file
  it cannot execute: a cleared executable bit and a volume mounted
  `noexec` both fail `test -x`, and the kernel refuses the exec with
  `Permission denied` and exit code 126 either way. Each launcher also
  requires read and write access to the kernel's `/dev/fuse`, which the
  AppImage mounts its own filesystem through; measured on a
  `ubuntu-latest` runner, the AppImage without it exits 127 with
  `fuse: device not found, try 'modprobe fuse' first`, or with
  `fuse: failed to open /dev/fuse: Permission denied` where the device is
  present and unreadable. Each of those goes on to offer
  `--appimage-extract` and then to link AppImageKit's FUSE page, whose
  remedy is installing `libfuse2t64`, a library this binary does not
  load. The launcher's message keeps the half that needs no privilege and
  drops the half that does not apply: it names
  `--appimage-extract-and-run`, measured on the same runner to reach
  Electrum's own code with `/dev/fuse` moved out of the way entirely, and
  prints the whole command with the arguments the launcher would have
  passed. It names that route rather than taking it, unpacking the
  AppImage on every start being the slower path and a launcher that chose
  it quietly leaving a broken FUSE setup looking intact.
  `linux/scripts/electrum/README.md` carries the measurements.
- **`update-bitcoin` installs Bitcoin Core on Linux, choosing the
  architecture from the machine, verifying the same multi-signed
  `SHA256SUMS` the other two platforms already check, and leaving a
  failed update recoverable** (closes #117).
  `linux/scripts/utilities/update-bitcoin.sh` downloads the single
  `x86_64-linux-gnu` or `aarch64-linux-gnu` tarball bitcoincore.org
  publishes for Linux, verifies it against `SHA256SUMS.asc` through
  `pgp_verify_or_fail`, and installs `bitcoind`, `bitcoin-cli`,
  `bitcoin-qt`, `bitcoin-tx`, `bitcoin-util`, `bitcoin-wallet` and
  `bitcoin` into `linux/bin/` through the same `install_verified` retry
  loop the other platforms use for a removable install target.
  `linux/scripts/utilities/rollback-bitcoin.sh` restores the previous
  binaries from `linux/bin/backup/bitcoin`, refusing to move any of
  them unless every backup binary present carries a checksum
  `linux/checksums.sha256` recognizes. `linux/scripts/lib.sh` and
  `linux/scripts/utilities/lib.sh` are Linux's own forwarders onto
  `shared/lib.sh` and `shared/utilities/lib.sh`, matching the macOS
  pair; `keys/bitcoin-core.fingerprints` is unchanged, this being no
  new trust decision. `shared/utilities/lib.sh` gains
  `verify_sha256sums`, the checksum-command choice both platforms'
  `update-bitcoin.sh` now call instead of each picking between
  `shasum` and `sha256sum` on its own, and `tree_hash` makes that same
  choice too rather than assuming `shasum`, which a Linux install
  without it would otherwise hit silently.
- **`CLAUDE.md`'s CI-evidence paragraph names GitHub Actions, not
  `ubuntu-latest`, as what its scratch-branch mechanism belongs to**
  (closes #132). A throwaway `on: push` workflow on a scratch branch,
  `gh run list` and `gh run view --log`, and `git push origin --delete`
  to clean up are properties of GitHub Actions and reach `windows-latest`
  exactly as they reach `ubuntu-latest`, confirmed by running the same
  mechanism on a `windows-latest` scratch job. What such a run cannot
  establish is now attributed to the runner rather than to Linux: neither
  `ubuntu-latest` nor `windows-latest` carries a desktop session, and a
  loopback image is not a plugged-in drive on either.
- **The shared shell library lives in platform-nameless `shared/`, so a
  Linux script can source it without a path component naming another
  platform** (closes #116). `shared/lib.sh` resolves the root and
  `shared/utilities/lib.sh` carries the download, PGP and checksum
  helpers. `macos/scripts/lib.sh` and `macos/scripts/utilities/lib.sh`
  are forwarders to them, kept at their old path so
  `Bitcoin-Launcher.command`, `Electrum-Launcher.command`,
  `Utilities-Launcher.command` and every script under
  `macos/scripts/utilities/` keep working unchanged. `resolve_root`'s
  root probe accepts `VERSION` plus any one of `macos/`, `win/` or
  `linux/`, so it matches once `linux/` exists without failing on a
  checkout that does not have it yet. `Bitcoin-Launcher.sh`,
  `Electrum-Launcher.sh` and `Utilities-Launcher.sh` refuse by name on
  Linux instead of falling through to the macOS `.command`, which runs a
  menu of Mach-O binaries that do not exist there. `linux/bin/.gitignore`
  and `linux/checksums.sha256` exist on the same terms as their macOS
  and Windows siblings, and `CLAUDE.md`'s parity check and
  executable-bit rule each read three platforms.
- **`Bitcoin-Launcher.*`'s menu now reaches every Bitcoin Core script,
  and `README.md` leads with the root launchers rather than mentioning
  them fourth** (closes #107). `Bitcoin-Launcher.command`, `.bat` and
  `.ps1` gain the `-clean` and `-cli` menu entries for Alice, Bob and
  Carol beside the GUI ones already there, so the menu reaches every
  script under `macos/scripts/bitcoin/` and `win/scripts/bitcoin/`;
  `Electrum-Launcher.*` already reached every script under
  `macos/scripts/electrum/` and `win/scripts/electrum/`. `README.md`'s
  *Quick Start* now double-clicks a root launcher as its first action on
  each platform instead of a per-network script, *Launcher Notes* names
  the three launchers before the four file extensions, and *Detailed
  Setup* names the per-network scripts as what a launcher's own menu
  runs rather than as the first way to reach them.
- **`README.md` and `bitcoin-datadir/README.md` back up wallets where
  Bitcoin Core actually keeps them** (closes #109). Bitcoin Core creates
  a `wallets/` subfolder only inside a network directory it creates
  itself; `bitcoin-datadir/` is tracked and so already exists before
  Bitcoin Core ever starts, and for mainnet the network directory *is*
  `bitcoin-datadir/` itself, so a mainnet wallet's own file or folder
  sits directly under `bitcoin-datadir/`, never under a `wallets/`
  subfolder there. Testnet3, testnet4 and regtest each get a network
  directory created fresh, `wallets/` created along with it, so their
  wallets stay under `bitcoin-datadir/<network>/wallets/`. Both files'
  backup instructions, and `bitcoin-datadir/README.md`'s own file
  listing, now say so; `README.md`'s Electrum backup instruction was
  already correct and is unchanged.
- **A testnet4 launcher joins testnet3 on Bitcoin Core and Electrum, both
  platforms** (closes #103), alongside Electrum's testnet3 launcher
  gaining a network-specific name of its own.
  `testnet4-48333-qt(.command|.bat)` starts Bitcoin-Qt on `-testnet4`
  (chain name `testnet4`, RPC port 48332, P2P port 48333), structured
  like `testnet3-18333-qt(.command|.bat)`; `bitcoin-datadir/bitcoin.conf`
  gains a `[testnet4]` section mirroring `[test]`'s
  `dbcache=4096` and `acceptnonstdtxn=1`, testnet4 sharing testnet3's own
  convention of relaying non-standard transactions on a public test
  network. On the Electrum side, `macos/scripts/electrum/testnet.command`
  and `win/scripts/electrum/testnet.bat` are renamed to
  `testnet3(.command|.bat)`, content unchanged, so the name says which
  network it launches now that `testnet4(.command|.bat)` exists beside
  it, running Electrum on `--testnet4`. Every README under
  `macos/scripts/`, `win/scripts/` and the root names the new and
  renamed launchers, and `electrum-datadir/README.md` names the
  `testnet4/` folder Electrum nests that network's wallets under.
  `Electrum-Launcher(.command|.bat|.ps1)` follow the rename, a menu entry
  still pointing at the old path having found no script at all; both
  launcher menus gain a testnet4 entry beside their testnet3 one, since a
  launcher the menu cannot reach is only half added.
  `testnet4-48333-qt(.command|.bat)` also echoes the datadir, the blocks
  directory and the wallet directory it is about to use. The wallet
  directory is the network directory's `wallets/` subfolder, except where
  that network directory already exists without one: Bitcoin Core creates
  the subfolder along with the network directory in `InitConfig`, and
  wallet code in `GetWalletDir` uses it where it exists but never creates
  it, so only a directory predating that behaviour holds wallets at its
  own root. The launchers that already exist echo none of these; #104 is
  that.
- **Every Bitcoin Core launcher echoes its datadir, blocks directory and
  wallet directory, alongside the `ROOTDIR` it already echoed** (closes
  #104), by the rule and in the shape
  `testnet4-48333-qt(.command|.bat)` already follows: the network
  subfolder nested inside that launcher's own datadir — none for
  mainnet, `testnet3` for testnet3, `regtest` for regtest — then
  `blocks/` under it, and `wallets/` under it except where that network
  directory already exists without one. Alice's launchers run on
  `bitcoin-datadir` itself, Bob's and Carol's on their own isolated
  datadirs, each nesting its own `regtest/` inside.
  The launchers that wipe their data before starting compute the three
  paths after the wipe rather than beside the `ROOTDIR` echo: a network
  directory standing there without a `wallets/` subfolder is the one
  state that answers with the directory itself, and the wipe is what
  takes that state away.
  Each launcher also passes `-datadir` from the variable it echoes, so
  the path it prints and the path it hands the binary cannot drift
  apart.
- **Bob and Carol get a CLI launcher pair each, on macOS and Windows**
  (closes #90), alongside their existing GUI ones:
  `regtest-18555-Bob-cli(.command|.bat)`,
  `regtest-18555-Bob-cli-clean(.command|.bat)`,
  `regtest-18666-Carol-cli(.command|.bat)` and
  `regtest-18666-Carol-cli-clean(.command|.bat)`, structured like
  `regtest-18444-Alice-cli(.command|.bat)` — a backgrounded `bitcoind`
  (or, on Windows, a second console) and a `bitcoin-cli` session on that
  node's own datadir. `win/scripts/bitcoin/` carries no `.ps1` launcher
  for any node, Alice's own `-cli` pair included, so none is added here.
  Bitcoin Core's regtest RPC port defaults to 18443 regardless of the
  P2P port passed with `-port` — confirmed from `src/chainparamsbase.cpp`
  and `src/httpserver.cpp` in Bitcoin Core's own source, `-rpcport`
  falling back to `BaseParams().RPCPort()`, which is 18443 for every
  regtest node — so Alice, Bob and Carol running at once would each try
  to bind RPC on the same port, and `AppInitServers` fails the node that
  loses the race. Bob and Carol now pass an explicit `-rpcport`, one
  less than their own P2P port, matching the spacing Bitcoin Core uses
  between a network's own P2P and RPC ports elsewhere (8333/8332,
  18333/18332, 18444/18443); Alice is unchanged, keeping the regtest
  default. `regtest-18555-Bob-qt(.command|.bat)`,
  `regtest-18555-Bob-qt-clean(.command|.bat)`,
  `regtest-18666-Carol-qt(.command|.bat)` and
  `regtest-18666-Carol-qt-clean(.command|.bat)` carry the same
  `-rpcport`, the collision reaching them as much as the new CLI pair.
  Both `bitcoin/README.md` files document the port assignment and the
  new launchers.
- **`claude-review.yml` posts the ack of record as a GitHub review, not
  a comment** (issue #95). `APPROVE` carries the `ACK <sha>` body,
  `REQUEST_CHANGES` carries the `CHANGES REQUESTED <sha>` one, and the
  workflow's own guard against running under an edited copy of itself
  means this is exactly the pull request that guard applies to: it gets
  no review from this workflow, and shows red rather than green, until
  the change is on `main` -- the honest shape of "no review happened"
  the file's own header names, not a defect in the change.
- **`README.md` carried no badges, and `REVIEWING.md`'s own account of
  what an ack is had gone one sentence stale** (issue #95). `README.md`
  now opens with one badge per property this tree has, in the fixed
  order `btclib-org/.github`'s standard gives — the licence, the `lint`
  workflow, then the sentinels this tree runs, `links` and the new
  `scorecard.yml`, which runs the OpenSSF Scorecard against this
  repository on every push to `main` and publishes its score; a weekly
  schedule follows once `btclib-org/.github#363` gives the sentinel a
  row on section 10's calendar. `REVIEWING.md`'s *The verdict* takes the
  converged wording from `btclib-org/.github`'s own copy: the sentence
  explaining why a forge approval is not an ack now says the refusal is
  to the pull request's own author, section 11 having made the ack of
  record an approving review from somebody else. `claude-review.yml`
  itself is untouched here and still posts a comment; that change is
  btclib-org/.github#340's, in a pull request of its own.

- **`git show origin/main:<path>` is current without being faithful for
  a path git filters on checkout**, where `CLAUDE.md` had named it the
  read that cannot go stale and said nothing of its content. `.bat`
  carries `text eol=crlf`, so the blob is LF and
  `git show` hands back line endings that are an artefact of the
  extraction, as do `git cat-file blob` and the contents API. A batch
  linter reported a tracked `.bat` as LF-only on exactly that basis,
  from a file that is CRLF wherever it is actually read. `git archive`
  applies the attribute, so it is current and faithful at once, and
  `CLAUDE.md` now names it in the bullet on those files, with a pointer
  from the rule it is the exception to, and `CONTRIBUTING.md`'s own
  instruction to measure a `.bat` points there rather than restating the
  mechanism and sending the reader to a checkout.

- **`verify-binaries.ps1` and `monitor-bitcoin-log.ps1` did not parse, so
  neither ran on Windows** (closes #93). `verify-binaries.ps1` wrote
  `"$path: MISSING"`, and PowerShell reads `$path:` inside a
  double-quoted string as a drive-qualified variable reference rather
  than as the variable followed by a colon; it now reads `"${path}:
  MISSING"` at every site. `monitor-bitcoin-log.ps1` split an
  assembly-qualified type literal across two lines, which PowerShell's
  tokenizer does not accept; it is now one line, however long, a type
  literal being unsplittable. PowerShell's own parser rejected both
  files before the fix and accepts every `.ps1` in the tree after it.
- **Nothing reads the `.ps1` and `.bat` launchers as a language, and
  that is now recorded as a decision rather than as an omission**
  (closes #54). The generic hooks read both as text — `mixed-line-ending`
  is the one that excludes `.bat`, for the reason its own comment gives —
  so what that half is short of is a parser rather than coverage, and
  `shellcheck` is that parser for the `.sh` and `.command` half.
  PSScriptAnalyzer is PowerShell's and is a PowerShell module, so a hook
  wrapping it needs `pwsh` on the PATH or a container runtime to supply
  one, and uv is the only prerequisite this tree asks of a machine that
  commits. `.pre-commit-config.yaml`'s header carries that reasoning
  beside the absences it already records, and `CONTRIBUTING.md`'s last
  section drops "no such hook at all" for the invocation that runs
  PSScriptAnalyzer by hand. `.bat` has Blinter, which installs under uv
  alone and so turns on a different question: not one of the findings
  the rules that set its exit code produce here is a defect, and it
  suppresses by rule code rather than by line, so the header records it
  as weighed and refused rather than as missing.
- **A binary that is not there passed verification, on both platforms**
  (issue #50). `verify-binaries.sh` and `verify-binaries.ps1` printed
  `MISSING` for an absent file and moved on without counting it against
  the run, so a fresh clone — which launches nothing until the updaters
  have run — verified clean and exited 0. Both now count a `MISSING`
  file the same as a checksum mismatch, converging on the behaviour
  `macos/scripts/utilities/lib.sh`'s `verify_checksum_entry` already had:
  a binary that is not there is a failure, not a silent pass.
  `update-bitcoin.bat`'s post-install gate has the same shape in
  `lib.bat`'s `:verify_checksum`, which is outside this change and
  leaves the issue open.
- **`validate-setup.sh` skipped the whole checksum check when
  `verify-binaries.sh` had lost its executable bit** (closes #58). The
  guard tested `-x`, so the one case it warned about — a copy, or an
  archive extraction, that drops the mode `README.md`'s *Troubleshooting*
  already documents as reachable — was also the only case under which
  `bash "$SCRIPT_DIR/verify-binaries.sh"` would have worked without it.
  The test is now `-f`, matching what the branch actually does and the
  Windows half's own `if exist`.
- **`debug_list_dir` died instead of listing when the directory was
  missing, under `set -euo pipefail`** (closes #71). `find` on a
  nonexistent directory exits 1, and `pipefail` carried that through
  `tr` and `sed` into the assignment, so every caller — the archive and
  mount-point diagnostics in `update-bitcoin.sh` and
  `update-electrum.sh` among them — died inside the helper before its
  own `Debug:` line printed, in exactly the case the helper exists for.
  The assignment now tolerates that exit with `|| true`.
- **`update-bitcoin.bat` compared a whole `SHA256SUMS` line against a
  bare hash, so a Windows update could never install** (closes #43). The split
  pattern is now written `\s+`. Doubled, it reached the .NET regex engine
  as a literal backslash followed by one or more `s`: cmd.exe passes a
  backslash through untouched, and powershell.exe splits its command
  line by the Windows argument rules, where a backslash is literal
  unless it precedes a double quote. No `SHA256SUMS` line holds a
  backslash, so the split returned the line unbroken and the comparison
  against `Get-FileHash` could not succeed.
- **`update-electrum.bat` could not find a version by itself** (closes #44).
  The scrape moves to `win/scripts/utilities/latest-electrum-version.ps1`,
  invoked with `-File` the way `update-bitcoin.bat` invokes
  `latest-bitcoin-version.ps1`, so PowerShell is the only reader of its
  regex; and the emptiness test after it is `if not defined VERSION`,
  which is evaluated when it runs rather than when the enclosing block
  is parsed. Either defect alone left `--version <v>` the only way to
  reach an install.
- **The Windows free-space checks read a word where the number is, and
  overflowed the arithmetic that followed** (closes #45). `validate-setup.bat`
  exited 1 with `ERROR: Less than 100GB free.` on a healthy volume:
  `findstr` without `/C:` is an OR search that matched every line
  `fsutil volume diskfree` prints, `tokens=3` named a word of the label
  rather than a figure, and `set /a` is 32-bit signed where a free-byte
  count is not. `validate-setup.bat`, `health-check.bat` and the
  `--dry-run` block of each updater now read
  `win/scripts/utilities/free-space-gb.ps1`, which asks
  `System.IO.DriveInfo` and divides in 64-bit arithmetic before the
  figure reaches cmd.exe.
- **A rollback now refuses to run while Bitcoin Core or Electrum is up**
  (closes #49). It replaces the files an update installs, and it is run
  when something has just gone wrong, which is when the node is most
  likely to still be running. The detection is the update scripts' own —
  the same `pgrep -f -i` pattern on macOS, the same `tasklist` filters on
  Windows — written out in each script rather than shared, so a change to
  one is owed to the other.
- **A rollback that could not restore now says so and exits non-zero**
  (closes #48), where `Rollback complete` and an exit of 0 followed a
  failed `mv` as readily as a successful one. `rollback-bitcoin.sh` and
  `rollback-electrum.sh` run under `set -euo pipefail` and rename the
  installed app aside rather than deleting it before the restore, so a
  move that fails leaves `macos/bin` holding the version that was
  installed instead of nothing at all; `rollback-bitcoin.bat` and
  `rollback-electrum.bat` check every `move` and leave its error text on
  stderr. Each of them also says, on the way out, that the backup is
  consumed and a second rollback has nothing to restore — that being the
  point of moving the backup rather than copying it, since a copy left
  behind would hold the version that is now installed and a slot that
  swapped its contents would make a second rollback move forward again.
  `rollback-bitcoin.sh` says too that the command-line tools beside the
  app are not rolled back: `update-bitcoin.sh` backs up the app alone,
  where `update-bitcoin.bat` copies the command-line tools too.
- **Documentation describing a tree that is not there is corrected** (closes
  #59, closes #60, closes #61, closes #62, closes #69). `README.md`,
  `macos/bin/README.md` and `win/bin/README.md` no longer place the updaters'
  downloads in a `.tmp-downloads/` directory nothing creates — both updaters
  download and verify on local temp storage instead, extracting or mounting
  there too where the download needs it, precisely to keep off the removable
  volume — and the two `bin/.gitignore` no longer list that directory.
  `macos/scripts/utilities/README.md` no longer tells `verify-binaries.sh` to
  use associative arrays it was written to avoid, macOS shipping bash 3.2. Both
  utilities `README.md` point at `README.md`'s own signing-key paragraph instead
  of restating it around a `contrib/builder-keys/keys.txt` path Bitcoin Core no
  longer has, and no longer duplicate between themselves the explanation of why
  a missing key fails a detached signature. `README.md` no longer names two
  `bin/backup/README.md` an ignored `backup/` can never hold, no longer offers a
  mainnet CLI script the tree has never shipped, and folds its own duplicated
  *Signing Keys* bullet into the paragraph above it. `README.md`'s *Expected
  Binaries by OS* now names the six CLI tools beside the two macOS app bundles,
  matching what `macos/bin/README.md` already said, and its *Folder Structure*
  macOS `bin/` line now describes the binaries generically instead of
  enumerating them by name. `macos/README.md`'s own *Binaries* section gains the
  same six tools in a paragraph of its own: the updater sets their executable
  bit itself, so the `chmod` block above still covers only the two app bundles.

- **`CONTRIBUTING.md`'s shared half matches `btclib-org/.github`'s copy
  byte for byte**, gaining *The landing queue* under *Pull requests* and
  a rewritten paragraph on what a commit message becomes once it lands
  (closes #39, issue btclib-org/.github#281).
- **The Windows regtest clean launchers refuse to delete a data directory
  a node is using, and `mainnet-8333-qt.bat` refuses to start a second
  mainnet node** (closes #47). `win/scripts/bitcoin/lib.bat` carries both
  guards, which read the data directory from the running process's command
  line where the macOS half reads it with `pgrep`. Windows refuses to
  delete a file another process holds open rather than deleting it, so what
  an unguarded clean start leaves under a live node is a data directory
  emptied of everything except that node's own open files, with the node
  writing on into what is left; on macOS `rm -rf` deletes them instead. A
  check that cannot run counts as a node for the clean launchers and not
  for the mainnet one: deleting on a question nothing answered is what the
  first guard is for, and starting a node deletes nothing.
- **The Windows network launchers open with `@echo off` and `setlocal`,
  and resolve the root through `win/scripts/root.bat`** (closes #63).
  Double-clicked, they print what they are doing rather than themselves;
  `ROOTDIR` stays inside the launcher that set it, and it reaches the user
  as a resolved path rather than one carrying `..\..\..`.
- **`win/scripts/root.bat` returns the root with no trailing separator,
  and says so where it returns it** (closes #65). That is the shape
  `resolve_root` in `macos/scripts/lib.sh` and `Resolve-PortaNodeRoot` in
  `win/scripts/root.ps1` return, and the shape every caller under
  `win/scripts/utilities/` is written for; the three root `.bat` launchers
  concatenated `%ROOTDIR%win\scripts\...` with no separator, and now write
  one. `PORTANODE_ROOT=D:\PortaNode`, the form `README.md`'s *Environment
  Overrides* shows, sent every menu entry of those launchers to `Script not
  found:`. A drive root keeps its backslash, `E:` alone naming the current
  directory of that drive rather than its root.

- **Every hook with a fix mode now runs with it turned on.**
  `markdownlint-cli2` gains `--fix` and `codespell` gains
  `--write-changes`; `typos` already fixes in place through its own
  upstream default, now stated so a later `args:` cannot silently turn
  it off; `yamllint` is noted where it is configured as having no fix
  mode to turn on.
- **With `markdownlint-cli2` fixing in place, this file's own directive
  disabling MD022 and MD032 no longer has anything to absorb: a rebase
  joining two entries under `merge=union` and dropping the blank line
  between them is repaired on the next hook run instead of failing a
  gate with nothing to fix it.** The two-comment directive at the head
  of this file is gone, and the two rules apply to it again (closes
  #40).

- **`shellcheck` is now in `.pre-commit-config.yaml`** (#13), against
  every `.sh` and `.command` launcher. Landing it needed the findings it
  had been left out for answered first: a `rm -rf` in `update-bitcoin.sh`
  that two empty variables would turn into `rm -rf /` now guards both
  with `${var:?}`; the regtest clean launchers' confirmation `read`
  now takes `-r`; `lib.sh`'s `debug_list_dir` lists a directory with
  `find` rather than parsing `ls`; and a handful of variables set and
  never read are gone. The two findings shellcheck is wrong about — an
  intentionally unquoted expansion in `update-bitcoin.sh` that hands
  `tar` several members, and a line continuation building one URL rather
  than concatenating three — are disabled at their own line, with the
  reasoning beside them, rather than asserted away for the whole tree.
  Every launcher that sources `lib.sh` through a dynamic
  `$SCRIPT_DIR`-built path now also carries a `shellcheck source=` at
  that line, so `-x` can follow it.
- **`check-shebang-scripts-are-executable` is now in
  `.pre-commit-config.yaml`** (#17), excluding the two `lib.sh` that are
  sourced rather than run. Every tracked file with a shebang already
  carried the executable bit the hook asks for, so it lands with no
  further change. `macos/README.md`'s Troubleshooting section no longer
  offers `chmod +x scripts/**/*.command` for a state the repository does
  not produce; it points instead at the root `README.md`'s own
  "Permission denied on macOS" bullet, which names the one route by
  which the bit can actually go missing and what to do about it (#18).

- **`detect-secrets` now runs against a committed `.secrets.baseline`**
  (#16), rather than with nothing to record a finding against. Generated
  with every plugin at its default: `keys/*.fingerprints` and
  `*/checksums.sha256` are the hex this tree carries, and none of it
  reaches `HexHighEntropyString`'s threshold, so the baseline's own
  `results` is empty.
- **`.gitattributes` now checks out `*.command` and `*.ps1` as LF**
  (#15), joining `*.sh`. Both were unspecified before, which travels
  fine until a checkout on a machine with `core.autocrlf=true` takes
  them in CRLF — a `.command` in CRLF not running on macOS at all, the
  one failure this tree exists to avoid. `.ps1` takes LF rather than
  `.bat`'s CRLF because PowerShell, unlike cmd.exe, reads either.
- **The two utilities `README.md` describe PGP verification as failing
  open** (#14). `macos/scripts/utilities/README.md` and
  `win/scripts/utilities/README.md` said a missing `gpg` or missing keys
  let an update continue with checksums left unwritten; `lib.sh` and
  `lib.bat` both abort the update on exactly that condition, unless
  `PORTANODE_ALLOW_UNVERIFIED=1` is set. Both files now say so.
- **`validate-setup` required only 100GB free, where an unpruned mainnet
  full sync needs 700GB** (#4). It now reads `prune=` from
  `bitcoin-datadir/bitcoin.conf`: unpruned and below 700GB free warns
  rather than passing silently, and below 100GB still fails outright
  either way. README.md's Prerequisites is the one place both figures
  are stated.

- **`CLAUDE.md`'s primary-checkout paragraph names the read that cannot
  go stale** (btclib-org/.github#255). It said reading the checkout was
  fine and so was `git fetch`, without saying `git fetch` moves
  `refs/remotes/origin/main` and leaves the work tree where it was, so a
  `grep` or a `Read` against the checkout answered for whenever it was
  last brought forward. The paragraph now names `git show
  origin/main:<path>` as the read that does not go stale, and gives the
  fast-forward that brings a clean checkout forward without working in
  it.

- **`CLAUDE.md`'s worktree recipe named the worktree after the issue
  alone, `wt<issue>`.** A worktree's administrative directory lives in
  the `.git` of the repository `git worktree add` was run from, one per
  repository, so two repositories cannot collide there; what the recipe
  left uncovered was a same-repository collision, between two worktrees
  of different work sharing a generic basename, and a *path* collision
  across repositories, since the workers of one session share one
  scratchpad directory and a session carrying one issue into several
  repositories computed the same target path for each. The recipe now
  names the worktree `wt-<tracker>-<issue>-<repo>-<role>`, most general
  part first: `tracker` because an issue number is unique only within
  one tracker, `issue` against the same-repository collision, `repo`
  against the cross-repository path collision, and `role` against a
  coder and its reviewer holding a worktree at once
  (btclib-org/.github#292).

- **`.gitattributes`'s shared half carries the paragraph saying both
  `merge=union` lines are in every repository's copy, a tree with no
  `RELEASE_NOTES.md` included.** The organization's copy, shared half
  byte for byte (section 14): an attribute on a path the tree does not
  hold matches nothing, which is the reason the two lines need no
  per-repository condition (btclib-org/.github#192).

- **`REVIEWING.md`'s *The gates are the evidence* excepts no gate from
  the run a reviewer may rely on, the test suite included.** The
  organization's copy, shared half byte for byte (section 14): a run is
  whole whoever makes it — never a module on its own, a `-k`, a `--lf`,
  a deselect or a marker in its place — and one that was narrowed or cut
  short is reported as no run (btclib-org/.github#168).

- **`REVIEWING.md` is the organization's copy.** A review reads the prose
  that stays in the tree, treats a commit message or a pull request's
  body as a finding only where it decides something, and asks a stated
  count, a measurement nothing re-derives, or the history of the code
  told in a comment to go — section 14 of the standard, the shared half
  byte for byte.

- Aligned the repository to the btclib-org standard. The files it copies
  byte for byte arrived: `.markdownlint.jsonc`, `.yamllint.yaml`,
  `.taplo.toml`, `COPYRIGHT`, `CODE_OF_CONDUCT.md`, `LICENSE` and
  `.claude/commands/review.md`. `CONTRIBUTING.md` and a new `REVIEWING.md`
  are that file's shared half up to `## This repository in particular`,
  with this tree's own facts under it. `AUTHORS.md`, `SECURITY.md`,
  `REPOSITORY.md`, `RELEASING.md` and `RELEASE_NOTES.md` are new, and
  `REPOSITORY.md` is read back from the GitHub endpoints rather than
  copied from a sibling.
- `CLAUDE.md` keeps only what no document for humans can hold: the shape
  of the tree, the worktree rule, the model, the conventions, and the
  facts that otherwise cost a session. The environment and the gates
  moved to `CONTRIBUTING.md`'s last section, where a contributor does not
  have to open an agent's file to find them.
- Added a lint gate: `.pre-commit-config.yaml` with the hooks that have a
  subject in this tree, `uvx pre-commit run --all-files` being the whole
  of it. `shellcheck` is deliberately not among the hooks; the file says
  why and carries the command that answers for the bash scripts.
- The lint gate runs on the forge. `.github/workflows/lint.yml` runs `uvx
  pre-commit run --all-files` on every pull request and on every push to
  `main` — the command `CONTRIBUTING.md` gives an author, rather than a
  second list of the same tools — so a branch that skipped it locally is
  no longer a branch nothing looked at. Nothing waits for its answer yet:
  `REPOSITORY.md`'s *What gates a merge* carries the ruleset rule that
  would make `Lint` a required context, and why that follows a green run
  instead of arriving with the workflow.
- `.github/workflows/links.yml` reads every link in the markdown, weekly
  and on demand. It gates nothing by design — a link rots without anybody
  touching the tree, and a host answering 502 would be a red merge with
  nothing to fix.
- `.github/dependabot.yml` watches the one ecosystem this tree has, the
  action pins in `.github/workflows`, grouped and weekly with a seven-day
  cooldown. Without it a SHA pin is frozen for good.
- `.pre-commit-config.yaml` gained `actionlint`, `zizmor` and
  `check-dependabot`, which is the rule it already stated: a hook lands
  the day the tree grows the file it reads. `actionlint` is given
  `shellcheck-py` so that the shell a workflow inlines is read too, which
  is a different subject from the launchers that file argues about.
- There is somewhere private to report a flaw (#10). Private
  vulnerability reporting is on, so `.github/ISSUE_TEMPLATE/config.yml`
  links `/security/advisories/new` as its first contact link and
  `SECURITY.md` names that button rather than describing why it is
  missing. The email address stays beside it: it needs no GitHub account
  and no repository setting, which is what makes it the fallback rather
  than a second-best.
- `.github/workflows/claude-review.yml` reads a pull request against
  `REVIEWING.md` and posts the ack of record that file describes, which a
  solo-maintainer repository has no other way to get. It gates nothing
  and must not: what it produces is an opinion, and a branch rule waiting
  on one would make a model's judgement a merge condition. It refuses to
  report a review it did not run — the action skips, green, when this
  file differs from the copy on the default branch, so the pull request
  that lands or edits it is red by construction.
- `claude-review.yml` is red unless the last verdict `claude[bot]`
  posted is an ack naming the head under review, the step being
  `btclib-org/.github`'s (btclib-org/.github#146). The earlier guard
  answers whether the action started; a run that starts, finishes green
  and posts nothing walks through it — measured on btclib-org/.github#139
  — and so would an ack naming a sha the branch has moved past. Still
  not a required check.
- Deleted `CODE_OF_CONDUCT.md` (btclib-org/.github#123): the standard
  keeps one copy, in `btclib-org/.github`, and GitHub shows it here. No
  file in this tree linked it.
- Deleted `SECURITY.md` (btclib-org/.github#116). Nothing is published
  from this repository, so the policy is the one the organization's
  `.github` shows on the Security tab; what that policy cannot state —
  the trust root, `PORTANODE_ALLOW_UNVERIFIED=1`, what `checksums.sha256`
  does and does not say, the unencrypted volume, the unsigned launchers —
  is `README.md`'s *Limitations, not vulnerabilities*, where whoever is
  about to run this reads. `.github/ISSUE_TEMPLATE/config.yml` and
  `REPOSITORY.md` name the inherited policy where they named the file.
- The executable bit says what macOS runs, in both directions. The root
  `*.command` and `*.sh` launchers and the scripts under
  `macos/scripts/utilities/` carry it; `bitcoin-datadir/bitcoin.conf` and
  `macos/scripts/electrum/README.md` no longer do. It stays off the
  `.bat` and `.ps1` halves, Windows not reading a POSIX mode, and off the
  two `lib.sh`, which are sourced rather than run. No line of any of them
  changed: what moved is the mode alone.
- `README.md`'s *Prerequisites* no longer asks a reader to `chmod +x` the
  launchers. The bit ships set, GitHub's source zip carries it through
  `unzip` unchanged, and an exFAT volume — which is what this is built
  for — reports every file as executable whatever its mode. Under
  *Troubleshooting* the `chmod +x` stays, narrowed to the case those three
  leave open: a folder that arrived by some route which dropped the bit.
- `.pre-commit-config.yaml` refuses every case of the operating system's
  name but Apple's and the all-lower-case directory. `typos` and
  `codespell` read a known word in another case as a known word, so
  `bitcoin-datadir/README.md` had carried a wrong one past both; that
  line is fixed and the hook is what says it stays fixed.
- The markdown in the tree was brought to the shared markdownlint
  configuration: list indentation, blank lines around headings and lists,
  ordered-list prefixes and headings ending in a full stop. No wording
  changed. Trailing whitespace and missing final newlines were fixed in
  the `.bat` launchers, which keep their CRLF line endings — the
  line-ending hook excludes them for that reason.
- `.gitattributes` marks `CHANGELOG.md` and `RELEASE_NOTES.md`
  `merge=union`, so two branches each appending an entry no longer
  conflict on the insertion point.
- `.gitattributes` is the organization's copy down to
  `## This repository in particular`, with this tree's own lines — the
  `binary` ones, and the `text` and `eol` ones the launchers need —
  under that heading with their reasoning beside them, where they used
  to sit above the shared part (btclib-org/.github#102). What git
  resolves for every tracked file is the same before and after, which
  `git check-attr -a` over `git ls-files` measures.
- The gate runs `check-toml` and `pretty-format-json`, the two of
  section 4's syntax hooks it lacked over files it tracks
  (btclib-org/.github#153, btclib-org/.github#130). taplo formatted
  `.taplo.toml` and `.typos.toml` without the gate parsing either, and
  `.claude/settings.json` — json written by hand, which is the
  formatter's subject — had `check-json` asking whether it parses and
  nothing asking how it is written.
- `links.yml` no longer passes `--cache` (btclib-org/.github#111). No
  step restored the cache file between runs, so the flag decided nothing
  across them, and it would decide nothing with the step added: the run
  is weekly and the cache age passed beside it was a day. Within one run
  lychee asks each URL once whatever the flag says.
- Deleted `TODO.md` and `BUG.md`; their contents are issues #3 through #9,
  and the bug report template they carried is now a GitHub issue form at
  `.github/ISSUE_TEMPLATE/bug_report.yml`. README.md and CONTRIBUTING.md
  point at the tracker.
- Updaters now download/unzip/verify on the local disk (macOS: an APFS
  `mktemp` dir; Windows: `%TEMP%`) instead of on the removable install volume,
  then copy only the final binaries onto it. On macOS each copy goes through
  `install_verified`, which re-reads the destination and retries until it
  matches the source byte-for-byte. This defends against the macOS fskit exFAT
  driver silently corrupting files during extraction (observed: a full update
  wrote corrupted, then vanishing, binaries to an exFAT volume).
- Updaters run a post-install integrity check of the binaries they just
  installed (against checksums.sha256) and abort if it fails.
- Security: PGP verification now FAILS CLOSED on both platforms. Updaters abort
  the install unless the download carries a valid signature (gpg present + key
  imported); previously a missing gpg/key only warned and installed anyway. Set
  `PORTANODE_ALLOW_UNVERIFIED=1` to bypass. Added optional signer-fingerprint
  pinning via `keys/electrum.fingerprints` (pinned to the Electrum release key)
  and `keys/bitcoin-core.fingerprints` (template). Renamed the bash helper to
  `pgp_verify_or_fail`.
- Fixed a pre-existing Windows bug where `lib.bat`'s PGP check set and read
  `%STATUS_FILE%` inside the same block without delayed expansion, so the gpg
  status file path was empty and verification never worked. Rewritten flat.
- `validate-setup.bat`: fixed the disk-space guard (`%FREE_GB%` read inside a
  block was stale; the "100 GB free" check never fired). Now uses `!FREE_GB!`.
- Regtest clean launchers: `Bob`/`Carol` Windows scripts deleted data without
  waiting (`<nul set /p`); `Alice-cli-clean.bat` deleted with no prompt at all.
  All now `pause` for confirmation. macOS clean launchers now refuse to wipe a
  datadir a running node is using (Unix `rm -rf` would corrupt a live node).
- `update-electrum.sh` downloads now use `curl -fL` (fail on HTTP error) instead
  of saving an error page; matches `update-bitcoin.sh`.
- macOS regtest Bob/Carol launchers use `mkdir -p` (no error on relaunch).
- Documented that `checksums.sha256` provides integrity/rollback, not
  authenticity (PGP is the authenticity control).
- Windows Bitcoin updater now auto-detects the latest version from
  bitcoincore.org (via `latest-bitcoin-version.ps1`, probing newest-first and
  skipping releases with no win64 build) instead of a pinned version, matching
  the macOS updater. Recorded the win64 31.0 binary checksums alongside 30.2.
- Windows health check fixes: stop flagging the datadir `.lock` file (left in
  place after a clean shutdown) as a leftover; confirm the `bitcoind.pid`
  process is actually Bitcoin before reporting running; and fix pervasive
  delayed-expansion bugs (`%var%` read inside `( )` blocks returned stale
  parse-time values, breaking process/disk/sync detection) by using `!var!`.
- Bitcoin updater now also installs the command-line tools (`bitcoind`,
  `bitcoin-cli`, `bitcoin-qt`, `bitcoin-tx`, `bitcoin-util`, `bitcoin-wallet`)
  into `macos/bin/`, extracted from the official `.tar.gz` and checksum-verified
  alongside the app, since the `.app` GUI `.zip` ships without them. The health
  check uses `bitcoin-cli` to report Bitcoin sync progress instead of always
  showing "unknown".
- Health check no longer flags the datadir `.lock` file as a leftover artifact.
  Bitcoin Core leaves that empty advisory-lock file in place after a clean
  shutdown, so it was producing a false "Bitcoin running: maybe" every time.
- Fixed the Bitcoin `pgrep` patterns in the health check and the updater's
  "already running" guard: they used GNU-BRE alternation (`\|`), which macOS's
  ERE-based `pgrep` treats as a literal pipe, so they never matched a running
  Bitcoin. The guard could have let an update run while Bitcoin was open.
- Health check now confirms the `bitcoind.pid` process is actually Bitcoin
  (not just that some process with that PID exists) before reporting running.
- Bitcoin macOS updater now downloads the official notarized release archive
  (`bitcoin-<ver>-<arch>-apple-darwin.zip`) instead of the unsigned
  `-codesigning` tarball. The unsigned binary was killed by the kernel with
  SIGKILL ("Killed: 9") on Apple Silicon; the notarized app runs and passes
  Gatekeeper.
- Bitcoin macOS updater now auto-detects the latest version from
  bitcoincore.org (like the Electrum updater) instead of a pinned version,
  probing newest-first and skipping releases that ship no macOS archive (e.g.
  an index entry for a not-yet-published version). Downloads now use `curl -f`
  so an HTTP error fails immediately instead of saving an error page.
- `verify-binaries.sh` no longer uses associative arrays (`declare -A`), so it
  runs on the stock macOS bash 3.2 instead of erroring out before verifying.
- Bitcoin macOS launchers now distinguish missing vs non-executable binaries
  and add checks to testnet launcher.
- Windows regtest Bitcoin launchers now include full binary paths
  in missing-binary errors.
- Added macOS smoke test for Bitcoin launcher error paths.
- Launcher menus: blank input maps to exit, utilities menu reordered,
  and update binaries added.
- Utilities launchers now include rollback options for Bitcoin and Electrum.
- Utilities README now notes the rollback options in the launcher menus.
- Standardized launcher parity: consistent missing-script checks, error messages,
  and spacing across .command/.bat/.ps1/.sh.
- Update scripts now update local checksums after successful PGP verification.
- Rollback scripts now verify the backup binary checksum before restoring.
- Update/rollback scripts now emit one-line directory listings when expected
  files are missing.
- Update scripts now continue when PGP verification cannot be performed due to
  missing `gpg` or signer keys; bad signatures still fail, and checksums are
  only updated after successful verification.
- Utilities READMEs now document the signature verification behavior.
- Utilities READMEs now clarify that detached signatures require local signer
  keys to validate; without them, signatures cannot be checked locally.
- Factored shared update/rollback verification helpers into macOS/Windows
  utility libraries and rewired the scripts to use them.
- Windows Electrum updater now restores the full update flow using shared
  verification and checksum helpers.
- Verify-binaries scripts now treat missing binaries as informational and only
  fail on checksum mismatches.
- Verify-binaries scripts now include expected versions when binaries are
  missing or mismatched.
- Validate-setup scripts now warn on missing binaries instead of failing.
- Validate-setup scripts now delegate binary verification to verify-binaries
  to avoid duplicated checks.
- Verify-binaries now announces the checksum file path; validate-setup no longer
  prints it.
- Verify/validate scripts now use matching status text and failure summaries
  across macOS and Windows.
- Verify-binaries output now aligns the start/end status lines across macOS and
  Windows.
- Verify-binaries now prints the checksum file path as a repo-relative path.
- Windows checksum entries now use forward slashes, and verification normalizes
  and resolves paths against the repo root.
- Windows checksum helpers now normalize paths before PowerShell, and PS1
  normalizes checksum paths on ingestion.
- Update and rollback scripts no longer run verify-binaries automatically.
- Bitcoin updater now hashes the extracted binary (not the app bundle directory)
  when updating checksums.
- Bitcoin updater now validates and locates the extracted app bundle before
  checksum updates and install.
- Bitcoin updater now uses the codesigning tarball to obtain Bitcoin-Qt.app.
- Bitcoin updater now checks the extracted top-level dist/ folder for
  Bitcoin-Qt.app.
- Windows regtest Alice CLI launcher now sets -datadir in the doskey alias.
- Log monitor now resets its state when debug.log shrinks on macOS and Windows.
- Electrum updaters now derive the latest version from download.electrum.org
  instead of scraping electrum.org HTML.
- Root resolution is now centralized per OS, and utilities/launchers honor
  PORTANODE_ROOT overrides on macOS and Windows.
- **`update-bitcoin`, `update-electrum`, `rollback-bitcoin` and
  `rollback-electrum` take `--dry-run` on macOS and Windows** (#7), and
  the updaters also take `--version <v>` to install a specific release
  instead of the latest one (#6). An updater's `--dry-run` runs before
  any download begins: it reports the requested version against the one
  `checksums.sha256` recognizes as currently installed, the URL it would
  fetch, whether a signing key is present in the local keyring, the
  archive's size from a `HEAD` request, and free space at the mount
  point, without fetching, verifying or writing anything. A rollback's
  `--dry-run` runs the real checksum check against the backup, since
  that step is already read-only, and only skips the file replacement
  itself.
- **`README.md`'s "Updating Binaries" led with a hand-replace procedure
  and named a tested Bitcoin Core and Electrum version in prose** (#3).
  The section now leads with the update scripts, which back up, verify
  and record a checksum that hand-replacing does not; the hand-replace
  steps remain as what to do when an updater cannot run. The intro no
  longer states a tested version — one had already drifted twice from
  what `checksums.sha256` records, since nothing re-derives a number
  written into prose.
- **The log monitor's rotation-detection was a race, and it read the whole
  log to find its own end** (#9). `rotate-bitcoin-log` now clears the
  monitor's stored state as part of rotating, rather than leaving the
  monitor to notice on its next run — a run that lands after the node has
  already written past the pre-rotation length otherwise scans from the
  stale offset and silently skips the start of the new log, exactly where
  a restart records why it restarted. The monitor also tracks a byte
  offset and seeks to it, rather than a line count read by walking the
  file from byte zero every run; the state file is renamed
  `.last_log_offset` so an old line-count file is never read as one.
- **The log monitor's desktop notification has no way to turn off** (#8),
  which is wrong under a scheduler with no desktop to draw on, and on
  Windows the MessageBox fallback is modal and blocks a scheduled run
  indefinitely. `--no-notify` (or `PORTANODE_NO_NOTIFY=1`, easier to set
  than an argument list from `launchd` or Task Scheduler) suppresses only
  the notification; findings still go to stdout and the exit status is
  unchanged.
- **The two utilities `README.md` now say what a rollback restores and
  that it consumes the backup** (closes #67). On macOS a rollback moves
  back `Bitcoin-Qt.app` alone, the command-line tools staying at whatever
  `update-bitcoin.sh` last installed, since that script backs up the app
  alone; on Windows `rollback-bitcoin.bat` restores the command-line
  tools too, `update-bitcoin.bat` backing them up alongside the app. Both
  platforms move the backup into place rather than copying it, so a
  second rollback has nothing left to restore.
- **`CONTRIBUTING.md` and `REPOSITORY.md` say `Lint` holds the merge**
  (closes #72), `branches/main/protection` now answering `true` to
  `has("required_status_checks")` where both files still read `false`.
  `REPOSITORY.md` also drops its account of the requirement as a
  `main-integrity` ruleset rule: `rules/branches/main` lists no
  `required_status_checks` rule on any active ruleset, so the requirement
  is classic branch protection, coexisting with the rulesets rather than
  folded into one, and its `strict` flag is what asks for a rebase before
  every landing.
- **`clean-artifacts.sh` no longer walks `bitcoin-datadir/` or
  `electrum-datadir/` to find a `.DS_Store`** (closes #56). Both can hold
  a synced chain's blocks, chainstate and indexes, so an unqualified
  `find` rooted at `$ROOTDIR` read a whole mainnet node, every run, to
  find a handful of Finder sidecars that never appear inside either. The
  four `find`s now `-prune` both directories, and delete through
  `-exec rm -f {} +` rather than `-delete`, which implies `-depth` and
  makes `-prune` a no-op when the two are combined. `clean-artifacts.bat`
  gets the same exclusion, built from `$root`'s own children rather than
  a name filter that would still have to read both directories to apply
  one, and no longer walks `$root` and `Join-Path $root 'win'` as two
  separate targets when the second was already inside the first.
- **`update-electrum.sh` no longer names its scratch directory
  `TMPDIR`** (closes #57). `TMPDIR` is the variable every child process
  here — `gpg`, `hdiutil`, `curl`, the `mktemp` inside
  `pgp_verify_or_fail` — reads to decide where its own temporary files
  go, so the assignment redirected all of them into the directory the
  script's own `trap` removes on exit. It is `TMP_DIR` now, matching
  `update-bitcoin.sh`.
- **`update-electrum.sh`'s backup `rm -rf` now guards against an empty
  `BACKUP_DIR`** (closes #66), with the same `${BACKUP_DIR:?}` expansion
  `update-bitcoin.sh` carries on the same operation since #13.
  `BACKUP_DIR` is derived from `resolve_root` and is never empty today,
  so there was no live defect; `install_verified` in `lib.sh` holds a
  third `rm -rf` of this shape, already safe because an empty
  destination there makes the command a no-op error rather than a
  delete.
- **`bitcoin-datadir/bitcoin.conf`'s global section no longer sets
  `daemon=1`/`daemonwait=1`** (closes #46). `bitcoind` refuses `-daemon`
  on Windows before any initialisation, which stopped both regtest CLI
  launchers there; every other launcher in the tree starts `bitcoin-qt`
  instead, which never reads the option. No launcher benefited from the
  pair.
- **`set-permissions.sh` and `set-permissions.bat` now say whether the
  `chmod`/`icacls` they just ran actually restricted anything** (closes
  #51). macOS synthesises a fixed `u=rwx,go=` mode for exFAT and FAT32
  rather than storing what `chmod` is asked for, and exFAT/FAT32 hold no
  ACL at all for `icacls` to write, so both scripts ran and reported
  success on a volume they did not restrict. Each now reads back the
  data directory's own filesystem (`diskutil info`, a new
  `filesystem-type.ps1` DriveInfo helper) and reports which case it
  found, instead of an unconditional "Permissions set." `icacls`'s
  grantee is now `%USERDOMAIN%\%USERNAME%`, qualifying the account
  rather than the bare `%USERNAME%` the two calls used before.
  `README.md`'s *Permissions* bullet and both utilities `README.md`
  describe the same two cases instead of presenting the call as the
  answer to a portable, unencrypted volume.
- **`lib.bat`'s `:verify_checksum` passed a binary that is not there**
  (closes #50), the Windows half of the same defect
  `verify-binaries.sh` and `verify-binaries.ps1` had. It now fails
  closed on a missing file, converging on
  `macos/scripts/utilities/lib.sh`'s `verify_checksum_entry`, which
  already does. This is what `update-bitcoin.bat`'s post-install gate
  and every rollback script's pre-restore check call, so a copy or an
  extraction that never landed a file now stops the caller instead of
  reading as verified.
- **`lib.bat`'s `:update_checksum` rewrote all of `win/checksums.sha256`
  with `Set-Content`, and `Select-Object -Unique` dropped any repeated
  line, comments included** (closes #53). It now appends the one new
  entry with `Add-Content` instead, matching what `README.md` documents
  as append-only. `macos/scripts/utilities/lib.sh`'s `update_checksum`
  also rewrites the whole file after appending to it, on every call; that
  half of the same defect is issue #85, outside this change's region.
  `.gitattributes` also gains `eol=lf` for `*/checksums.sha256` and
  `keys/*.fingerprints`, neither previously attributed, so a write from
  either platform normalizes to the same line ending instead of git
  storing whichever last touched the file.
- **`win/scripts/utilities/validate-setup.ps1` had no caller** (closes
  #55). It printed a per-file installed-version listing and always
  exited 0, which had drifted from `verify-binaries.ps1`'s `OK`/
  `FAILED`/`MISSING` verdict and non-zero exit on a mismatch — the file
  `validate-setup.bat` actually calls, through `verify-binaries.bat`. It
  is removed rather than wired in, `validate-setup.bat` already
  delegating the checksum check the same way `verify-binaries.bat` does.
- **A trailing backslash in `ROOTDIR` escaped the closing quote of every
  `powershell -File` argument under `win/scripts/utilities/`** (closes
  #68), the case left open once #65 settled `ROOTDIR` as carrying no
  trailing separator except at a drive root. `lib.bat` gains
  `:rootdir_arg`, which doubles that one trailing backslash so an even
  count survives Windows' argv splitting rather than escaping the
  closing quote; every `-RootDir`/`-Path "%ROOTDIR%"` argument in this
  directory now reads the doubled form instead.
- **`verify-binaries.bat` left `SCRIPT_DIR`, `ROOTDIR`, `ROOTDIR_ARG` and
  `CHECKSUM_FILE` in the environment of whatever ran it** (closes #75),
  the one utility script under `win/scripts/utilities/` opening with no
  `setlocal`. It now opens with one, like every sibling but `lib.bat`,
  which is called for its side effects on the caller rather than run
  directly.
- **The two Alice CLI regtest launchers built their nested `cmd /k`
  command line with backslash-escaped quotes** (closes #76), which
  cmd.exe does not read as escapes: a backslash before a quote is an
  ordinary character to it, only the quote itself toggles quoting, so
  the daemon window's command began `\"C:\...\bitcoind.exe\"`, a token
  naming no file. Both now wrap the nested command in a single pair of
  quotes, doubled where the wrapped text itself opens with one — the
  idiom `cmd /k` documents for exactly this case — which is also what
  lets the `cd`/`title`/`doskey` chain in the second window use a plain
  `&` instead of the `^&` that, once outside the stripped quotes, was
  escaping the separator into a literal character and running the three
  as one `cd` command instead of three.
- **Every `.bat` under `win/scripts/bitcoin/` and `win/scripts/electrum/`
  wrote an error to a console that a double-click closes on exit, before
  the user could read it** (closes #79). `win/scripts/root.bat` gains
  `:pause_if_own_console`, called with the script's own `%~nx0` right
  before each `exit /b 1`: it pauses only where `%CMDCMDLINE%` names that
  script, which is true of a console a double-click opened to run it and
  false of one already open before the script started — a typed
  invocation, or `Bitcoin-Launcher.bat`'s own `call`, which runs in the
  launcher's own console and returns to its menu rather than closing.
- **`macos/scripts/utilities/lib.sh`'s `update_checksum` rewrote and
  deduped the whole `macos/checksums.sha256` on every call** (closes
  #85), an `awk '!seen[$0]++' | mv` pair run after the append regardless
  of whether a duplicate existed, dropping any exact repeated line,
  comments included. It is the macOS counterpart of the
  `Set-Content`/`Select-Object -Unique` defect #50/#53/#55/#68/#75
  already fixed in `lib.bat`'s `:update_checksum`. It now only appends,
  matching what `macos/scripts/utilities/README.md` documents this file
  as; that file's own "exact duplicates are pruned" clause goes too, no
  longer being true either.
- **`update-bitcoin.sh` installed six CLI tools and not the `bitcoin`
  multi-call wrapper the loose-binary tarball also ships** (closes #52),
  confirmed against the published `bitcoin-31.0-arm64-apple-darwin.tar.gz`
  with `tar -tzf`; `win/scripts/utilities/update-bitcoin.bat` already
  installs its Windows counterpart, `bitcoin.exe`, through its
  `bin\*.exe` wildcard copy. `BIN_NAMES` now names `bitcoin` too, and
  `macos/bin/.gitignore` gains an entry for it. Adding it makes
  `macos/bin/bitcoin` a prefix of `macos/bin/bitcoin-cli`, so
  `verify_checksum_entry` and `installed_version` in `lib.sh` now match
  a checksum entry on its own path field (`$2 == p`) rather than with
  `index($0, p)`, under which a `bitcoin` lookup would have matched the
  `bitcoin-cli` entry's own line too -- the reverse cannot happen, the
  longer path never occurring inside a line that only carries the
  shorter one. Naming the new binary also falsified every other place
  naming the six by hand, in `README.md`, `macos/bin/README.md` and
  `macos/README.md`; each now points at `macos/bin/README.md`'s own
  list, or drops the count entirely, rather than keeping its own copy
  in sync.

- **`win/scripts/utilities/*.bat` had the same unpaused-console defect
  #79 fixed for `win/scripts/bitcoin/` and `win/scripts/electrum/`**
  (closes #86), and `win/scripts/utilities/README.md` documents
  double-click as a supported way to run them too. Every echoed error
  exit now calls `win/scripts/root.bat`'s `:pause_if_own_console`
  first, `lib.bat`'s own PGP and checksum guards included where a
  caller funnels their failure into its own echoed message before
  exiting.
- **The two regtest CLI launchers existed on Windows and nowhere
  else** (closes #64). `macos/bin/` has held `bitcoind` and
  `bitcoin-cli` since the updater started installing them, so
  `macos/scripts/bitcoin/regtest-18444-Alice-cli.command` and its
  `-clean` variant now start Alice's daemon and a `btc` CLI session
  the same way the `.bat` pair does, for Alice alone: Bob
  and Carol stay GUI-only on both platforms, unchanged by this.
  Unix `bitcoind` supports `-daemon`, unlike `bitcoind.exe`, so the
  daemon forks into the background and the launcher's own window
  becomes the CLI session directly, with no second console to open;
  `btc` is a shell function rather than an alias, an alias being
  flat text re-split on every space when expanded, which breaks
  under a `ROOTDIR` containing one. Exercised on this machine with
  stand-in `bitcoind`/`bitcoin-cli` scripts, daemon start, the `btc`
  function, and a `ROOTDIR` containing a space all passing.
- **`scorecard.yml`'s opening comment stated how many checks Scorecard
  runs** (closes #108), a total two authoritative sources disagree on:
  Scorecard's own check-definition file and the dataset its published
  badge reads from report different counts for a repository of this
  shape. The comment now says the sentinel checks this repository's
  supply-chain posture without naming a total.
- **`mainnet-8333-qt.command`'s second-instance guard never matched the
  process it exists to catch** (closes #106). Its `awk` `BEGIN` block set
  `IGNORECASE=1`, a `gawk` extension that macOS's system `awk` -- BWK
  awk, not gawk -- silently ignores, so `/bitcoin-qt|bitcoind/` matched
  case-sensitively against the unlowercased `$0` while the block's own
  `tolower($0)` ran only after that match, on the process name
  `Bitcoin-Qt` this same launcher starts. The match now runs against
  `cmd`, computed before it: `{ cmd = tolower($0) } cmd ~
  /bitcoin-qt|bitcoind/ { ... }`. Verified against a real running
  mainnet `Bitcoin-Qt` process on this machine: the guard as it stood
  read `ps -ax -o command=` piped through it as exit 1 (no mainnet
  process found), the fixed guard as exit 0. The Windows counterpart,
  `lib.bat`'s `:require_no_mainnet_node`, matches with PowerShell's
  `-in`, case-insensitive already, and needed no change.
- **A `-clean` regtest launcher whose wipe failed started the node
  anyway, on the data it was asked to delete** (closes #114), with no
  sign beyond a line of `rm` or `rmdir` output above the launcher's own
  banner. Every macOS `-clean` launcher under `macos/scripts/bitcoin/`
  now stops, naming the directory, where its `rm -rf` does not succeed;
  every Windows counterpart calls a new `lib.bat` label,
  `:require_deleted`, which runs `rmdir /s /q`
  and then checks the directory is actually gone rather than trusting
  `rmdir`'s own exit code -- that code is nonzero already on the
  ordinary first clean start, where the directory does not exist yet
  to be removed, so what decides success is the state left behind, not
  the attempt. Reproduced end to end on macOS with a permission-denied
  regtest directory: the launcher as it stood printed the `rm` error and
  started `Bitcoin-Qt` on the old data anyway; the fixed launcher stops
  with the directory it could not delete named in its own error.
- **`README.md`'s badge row gains the pre-commit.ci badge the repository
  earns** (closes #115), between the lint workflow badge and the
  sentinels, the position `btclib-org/.github`'s README.md section 2
  fixes for it; the head comment enumerating that order now names it
  too.

## [2026.01.27] - Initial Release

- Portable Bitcoin Core and Electrum setup for macOS and Windows.
- Cross-platform launchers (root launchers + per-network scripts).
- Regtest multi-node setups (Alice/Bob/Carol) with clean-start variants.
- Update, verify, rollback, and validation utilities for both OSes.
- Checksums and PGP verification support in update workflows.
- Health checks, log rotation, and monitoring scripts.
