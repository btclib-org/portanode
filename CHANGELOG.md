# Changelog

All notable changes to PortaNode will be documented in this file.

The format is based on [Calendar Versioning](https://calver.org/),
using YYYY.MM.DD format.

Whether a release carries a version named here is not this file's to
say: the check at the top of `RELEASING.md` reads that off the forge.

## [2026.01.29] - git main branch

- **`CONTRIBUTING.md`'s Blinter paragraph names the two shapes `E010`
  covers, and `REVIEWING.md`'s ROOTDIR bullet gains a control that
  crosses a continuation line and follows a path into a variable**
  (closes #207, #224). A caret before a `for /f`'s own parenthesis
  breaks the loop and a caret inside a backquoted command does not, both
  under one rule code; the echo-anchored grep read only the physical
  line an `echo` sits on, which neither shape guarantees.
- **`REPOSITORY.md`'s topics section reads back what the forge holds
  instead of filing topics under a heading that calls the list empty,
  and `RELEASING.md` states its release-asset claim as a rule about how
  a release is cut rather than as a fact about a release that exists**
  (closes #230, #234). Both passages argued from forge state neither had
  re-derived: the repository carries topics, and carries no release.
- **`.github/workflows/scorecard.yml` is gone** (issue
  btclib-org/.github#492). Section 10 of the organization standard
  records which trees carry which sentinel, and the badge and the
  workflow are one membership rather than two: the `scorecard` entry
  does not name this repository, and `README.md` carries no Scorecard
  badge.
- **`README.md`'s badge comment gives section 2's three groups, and
  which sentinels this tree carries is read off section 10's record**
  (issue btclib-org/.github#492). Section 2 fixes the order and the
  calendar fixes where the sentinels sit inside it, so the row and the
  schedule are one decision.
- **`.github/workflows/links.yml` carries the day and the hour section
  10 gives `links`, at this repository's own minute** (issue
  btclib-org/.github#480).
- **`.github/workflows/scorecard.yml` carries a `schedule:` block,
  Saturday, hour 03, minute 28 from section 10 of the organization
  standard, and `README.md`'s badge comment states the badge order's
  reason without pointing at a closed issue** (closes #227). Both sites
  argued from section 10's calendar having no row for the sentinel; the
  calendar has one now, and Scorecard's position after `links` is what
  the calendar's own weekly order already gives.
- **`shared/utilities/lib.sh`'s `verify_binaries` comment states what an
  empty checksum file prints without contrasting it against what it used
  to print** (closes #213).
- **`win/scripts/utilities/lib.bat`'s `:update_checksum` and
  `:verify_checksum` comments give their reasoning in the present tense,
  and the `verify_checksum_entry` cross-reference names
  `shared/utilities/lib.sh`, where the function is defined, rather than
  the `macos/scripts/utilities/lib.sh` forwarder** (closes #214).
- **`README.md`'s badge row drops the link to the repository.** Section 2
  of the organization standard refuses it: the badge renders the
  repository's name because the URL says so, and the row is an audit, so
  the item that measures nothing is the one that does not belong in it.
  This tree carries no `pyproject.toml` and publishes nothing, so the
  standard's usual replacement — a `repository` line in a sdist's
  `PKG-INFO` — has no file here to hold it; a reader of this `README.md`
  has already reached it by cloning the repository or by unzipping a
  release's source archive, both of which start from GitHub already.
  The badge row's own HTML comment loses its appeal to a site with it:
  this repository serves none — `has_pages` is false and the `pages`
  endpoint answers 404 — so the kramdown `hard_wrap` that comment named
  renders nothing here (issue btclib-org/.github#381).
- **`README.md`'s Linux exFAT bullet narrows "no wallet can be kept" to
  the RPC channel, on a kernel-driver measurement of its own**
  (closes #197). The wallet-emptiness that sentence carried was measured
  under `exfat-fuse`, alongside an `os.chmod` failure out of
  `electrum/util.py`'s `make_dir` that the kernel driver does not have.
  Measured now on `ubuntu-latest`, Ubuntu 24.04.4, kernel
  `6.17.0-1022-azure`, against a loopback exFAT image made with
  `exfatprogs` and mounted `-t exfat` under the in-kernel `exfat` module
  from `linux-modules-extra-$(uname -r)`, which `findmnt` reports as
  `exfat` rather than `fuseblk`, with an ext4 loopback control on the
  same runner and Electrum 4.8.1's AppImage run off the runner's own
  root so that the datadir's filesystem is the only variable:
  `--dir <datadir> --regtest --offline create --password ''` exits 0 on
  exFAT and leaves `regtest/wallets/default_wallet`, parsing as JSON with
  the same key set and the same `keystore` keys as the control's. Against
  that same datadir `daemon -d` answers `timed out waiting for daemon to
  get ready`, `getinfo` and `stop` answer `Daemon not running`, all three
  exiting 1, and `regtest/` holds no `daemon_rpc_socket`; the control
  answers 0 to all three and holds one. An `AF_UNIX` bind on the exFAT
  mount answers `EPERM` where the control answers OK, and an ordinary
  file write succeeds on both, so the wallet file is not there by the
  filesystem accepting every call. `os.chmod(d, 0o700)` returns on the
  kernel driver leaving the mode the mount's `fmask` gives, where the
  control moves it — the silent no-op macOS's driver has, and the reason
  the `exfat-fuse` result does not carry over. What a loopback image
  cannot answer is how a drive plugged into a running machine behaves,
  and no launcher changes here: the same over-reaching sentence sits in
  `linux/scripts/electrum/`'s own refusal message (issue #216).
- **`win/scripts/utilities/health-check.bat` reports Bitcoin and Electrum
  rather than stopping at its first line of output with a cmd.exe parse
  error** (closes #188). Two constructs stop it, each measured on
  `windows-latest`. A literal `)` in
  `echo Disk free: !FREE_GB! GB (%MOUNT_PATH%)` closes the
  `if defined MOUNT_PATH (` block it sits in, so the line prints without
  its closing parenthesis and the `else` branch runs as well; `^(` and
  `^)` are cmd.exe's escape, and every `echo` writing a parenthesis
  inside a block takes them. A caret between `in` and a `for`'s own
  opening parenthesis is not a continuation: cmd.exe reads the `for`
  without a file set, answers `was unexpected at this time` and exits
  255, inside a parenthesised block and outside one alike, so that `for`
  is one physical line. `set ARTIFACT_NOTE= (stale pid)` loses its
  closing parenthesis to the first cause and takes the quoted
  `set "ARTIFACT_NOTE= (stale pid)"` form, which keeps it. Outside a
  block an `echo` needs no escape — `Bitcoin-Launcher.bat`'s
  `echo Command failed (exit %errorlevel%).` prints intact — so the bare
  parentheses at that depth stay. `update-bitcoin.bat` and
  `update-electrum.bat` write `Warning: PGP signature(s) not verified`
  inside an `else` block and are escaped with the rest. The `.command`
  and `.sh` halves are bash, where a parenthesis inside a double-quoted
  string is text, and PowerShell's parser reads one inside a string
  literal the same way, so neither they nor the `.ps1` half changes.
- **`shared/utilities/lib.sh`'s `update_checksum` gives the reason it
  appends in the present tense** (closes #198). The comment justified the
  append by a whole-file rewrite that deduped with `awk`, which the same
  commit that wrote the clause removed, so it explained current behaviour
  by code no longer in the file. The reason it gives now is one the tree
  makes checkable: a rollback verifies its backup binary against an entry
  a previous install recorded under the installed path, and
  `verify_checksum_entry` and `installed_version` both select on hash and
  path together, so rewriting that path's entry to the current hash would
  leave the backup unrecognized. Section 9 of the standard states *No
  history in the prose* with no exception beside it, and `REVIEWING.md`'s
  checklist asks such a comment for the history to go rather than to be
  shortened; the rejected alternative section 9 also asks for states in
  the present tense, so nothing is lost by dropping the past tense. No
  line of the function changes.
- **`win/scripts/root.bat`'s `:pause_if_own_console` read the console
  command line by expanding `%CMDCMDLINE%` into a command, so an operator
  that command line carried was parsed rather than compared** (closes
  #203). Measured on `windows-latest` through
  `win/scripts/electrum/mainnet.bat`'s binary-not-found path, one of the
  label's own call sites: a console started as
  `cd /d C:\ && <that launcher>` printed its own command line as far as
  the `&&` and returned without pausing, leaving the error on a console
  that closes on exit -- which is the outcome the label exists to
  prevent -- and `&` alone, or a `| ... >nul` earlier in the same command
  line, did the same. The text after the operator runs as a command of
  its own, starting the script again, which a console command line
  carrying no operator does not. The decision goes wrong the other way
  too, where the console command line reaches the script through a `%`
  reference rather than by name: the pipe's own child `cmd.exe` expands
  that reference a second time and finds the name in the result, so a
  console that was not opened for the script pauses, where one reaching
  the same script through a wrapper carrying no such reference does not.
  The label now reads the value through delayed expansion, which
  substitutes after the line has been parsed, and tests it with a
  substring replacement rather than a pipe into `find`; the value's own
  quotes come out first, the comparison being a quoted one they would
  otherwise end early. Each of those was measured against its
  alternative: keeping the pipe under delayed expansion answers `The
  input line is too long`, each side of a pipe being a new `cmd.exe` that
  parses what it is handed, and leaving the quotes in reads every console
  as somebody else's, so nothing pauses at all. Every `.bat` calling the
  label gets this, the console being a property of how the script was
  started rather than of the caller. The case the label exists for is the
  one a runner cannot show: a double-click through Explorer needs a
  desktop session, and `windows-latest` has none.
- **A launcher message and a network script's refusal name a path the
  folder carries relative to `ROOTDIR` rather than from the volume root**
  (closes #192) (closes #194). The folder is mounted at a different point
  on every machine it is plugged into, so a message naming the mount
  point tells the reader where that run happened rather than which file
  or directory in the folder is meant, and names a path the reader of a
  bug report does not have. Where the path is a constant the message
  carries it literally; where it is a value the script computed — the
  data directory a regtest clean script wipes for Bob or for Carol — the
  `ROOTDIR` prefix is stripped from it. A root launcher's menu holds each
  choice's relative name and joins `ROOTDIR` to it where it runs the
  script, and `win/scripts/bitcoin/lib.bat`'s guards take their data
  directory relative and join it the same way; neither reaches the
  `:rootdir_relative` that `win/scripts/utilities/lib.bat` carries, that
  helper rendering a value a script computed and there being none of
  those on the Windows side here. The header a `.command` launcher prints
  with the resolved root in it, and every network script's opening
  `ROOTDIR is ...` line, are unchanged: those name the mount point
  itself. The Electrum launchers' note that a unix domain socket address
  cannot hold a path as long as `electrum-datadir/daemon_rpc_socket`
  keeps the absolute path: that message reports the length a relative
  rendering would understate (issue #219). A Bitcoin launcher's opening
  `DATADIR is ...`, `BLOCKCHAINDIR is ...` and `WALLETDIR is ...` keep
  theirs, sitting under `ROOTDIR is ...` where whether the mount-point
  carve-out reaches them is undecided (issue #206). The `Binary not
  found at` messages keep theirs (issue #205).
- **`.gitattributes` gives the configuration formats a `text` line, and
  `VERSION` an `eol=lf` one** (closes #185). `*.yml`, `*.yaml`, `*.toml`,
  `*.jsonc`, `.gitattributes`, `.gitignore`, `.secrets.baseline`,
  `COPYRIGHT` and `LICENSE` are `text`, which stores them LF in the index
  whatever an editor saved, so that guarantee is the repository's rather
  than `mixed-line-ending --fix=lf`'s, which a clone gets only once it
  runs `pre-commit`. `VERSION` carries `eol=lf` on top because
  `RELEASING.md` cuts a release tag with `git tag -s "v$(cat VERSION)"`,
  command substitution strips the trailing newline and keeps the carriage
  return in front of it, and `git check-ref-format` refuses the ref name
  that results. No path takes `eol=crlf`: `root.bat` and `root.ps1` reach
  `VERSION` through `if exist` and `Test-Path`, so cmd.exe reads the
  contents of none of these files. No file's content changes —
  `git ls-files --eol` reports every path the new patterns reach as
  already LF in the index and in the working tree.
- **`electrum-datadir/.gitignore` covers the daemon's RPC socket, the
  launchers' own socket probe and `testnet4/`** (closes #186). Electrum's
  `get_rpcsock_defaultpath` joins `daemon_rpc_socket` to the same
  `config.path` that `get_lockfile` joins `daemon` to, so the socket sits
  beside a name the file already listed; `get_rpcsock_default_type`
  answers `tcp` on `win32`, so the socket is what macOS and Linux get by
  default and the entry is inert on Windows. `config.path` is the datadir
  root only for mainnet — `BitcoinMainnet.datadir_subdir()` returns `None`
  where the default returns the network's own name — so the testnet4
  launchers' whole datadir, that socket included, lands in `testnet4/`,
  which had no entry beside `testnet/` and `regtest/`. The probe is
  `.portanode-socket-probe.<pid>`, which `linux/scripts/electrum/`'s
  launchers bind and remove around the test of whether the filesystem can
  hold a socket at all, and which the launcher dying between the bind and
  the removal leaves behind. `bitcoin-datadir/.gitignore` is unchanged:
  `-ipcbind` — the option that puts a socket in Bitcoin Core's datadir,
  and which does not listen unless it is given — appears nowhere in this
  tree, and no launcher writes a probe there.
- **`win/scripts/utilities/update-electrum.bat` installs Electrum's
  standalone Windows build, and `win/scripts/electrum/`'s launchers refuse
  the portable one** (closes #190). The portable build assigns its own data
  directory — `electrum_data` under the working directory — after the
  command line has been parsed, so the `--dir electrum-datadir` every
  launcher passes is discarded. A `.bat` opened from Explorer runs with its
  own directory as the working directory, which puts the wallet under
  `win\scripts\electrum`; a launcher started from a console sitting
  elsewhere puts it off this volume altogether, with nothing said. Measured
  on windows-latest through `mainnet.bat` itself: with the portable build
  installed the launcher left `electrum-datadir` holding only its tracked
  files and wrote the data directory under the console's own directory,
  and with the standalone build of the same release in its place and
  nothing else changed, it wrote the data directory into
  `electrum-datadir`. Dropping `--dir` from the portable build's command
  line changed nothing, and `ELECTRUMDIR` in the environment does not reach
  it either. The new `win/scripts/electrum/lib.bat` is what an installation
  that already carries the portable build meets, the updater's own change
  reaching only the install after it; it tells the portable build from the
  standalone one by pyinstaller's `is_portable` archive entry, whose name
  is stored uncompressed. The `.asc` beside the standalone file carries a
  signature from the key `keys/electrum.fingerprints` pins, as the portable
  one's does, so the updater's verification is unchanged.
- **`README.md`'s *Prerequisites* carries the 100GB figure each
  platform's `validate-setup` enforces** (closes #153). The disk-space
  comment in those scripts routes a change to either threshold through
  *Prerequisites* first, and only the 700GB one was written there — the
  undocumented one being the threshold that stops validation with an
  error, where falling below 700GB warns and lets it finish.
  *Prerequisites* now states both, says the 100GB floor applies whatever
  the network and whether or not pruning is on, and counts pruned
  mainnet alongside regtest and testnet among the configurations needing
  less than 700GB. The comment is unchanged.
- **`.gitattributes` names macOS, Windows and Linux as what the launchers
  ship to, and gives `*.sh text eol=lf` the shell's own reason rather than
  a macOS one** (closes #180). A carriage return where a line ending is
  expected makes `#!/bin/bash` name an interpreter that does not exist and
  a `fi` not `fi` — measured on macOS 26.6.2 and on `ubuntu-latest`
  running bash 5.2.21, exit 127 and a syntax error on each, against an LF
  control that runs — so the attribute serves whatever
  `git ls-files '*.sh' '*.command'` names rather than `macos/`'s share of
  it. The `*/checksums.sha256` comment below the patterns now says that
  macOS's and Linux's updaters reach that file through the one appender in
  `shared/utilities/lib.sh`, which writes an LF line. Only comment lines
  changed: no pattern and no `eol` value is different, so no file is
  checked out differently.
- **`shared/utilities/lib.sh`'s header stops calling
  `linux/scripts/utilities/update-bitcoin.sh` a future file, and stops
  giving "every caller today is macOS's own and omits the argument" as
  the reason `update_checksum`, `verify_checksum_entry` and
  `installed_version` default `checksum_file` to
  `macos/checksums.sha256`** (closes #184). Every
  `linux/scripts/utilities/` call to those three passes
  `linux/checksums.sha256`, and the `verify_binaries` paragraph in the
  same header already named the Linux caller as one that exists. The
  header now records what the default is and that omitting the argument
  raises nothing, leaving who passes it to `update_checksum`'s own
  comment beside the default. The enumeration of the helpers that read
  no platform-specific path is dropped rather than corrected, and
  `verify_binaries`'s naming of its own callers with it: both are the
  shape [ISS 164](https://github.com/btclib-org/portanode/issues/164)
  landed to remove from two library headers, and each
  `verify-binaries.sh` already names its counterpart in its own comment.
  Comments only; no script behaviour changes.
- **A utility message names a path the folder carries relative to
  `ROOTDIR` rather than from the volume root** (closes #141). The folder
  is mounted at a different point on every machine it is plugged into,
  so a message printing a variable built as `$ROOTDIR/...` told the
  reader where that run happened rather than which file in the folder
  was meant, and named a path the reader of a bug report does not have.
  Where the path is fixed the message now carries it literally; where it
  is not — the data directory a permission report is about, the
  `bitcoin-cli` a health check found, the file a checksum helper could
  not open — the `ROOTDIR` prefix is stripped from the value, which
  leaves a path outside the folder absolute, that being the convention's
  one exception. `Validating setup at $ROOTDIR` and the `ROOTDIR is ...`
  line a launcher prints are unchanged, naming the mount point itself;
  `CLAUDE.md` and `REVIEWING.md` now carry that distinction beside the
  convention they each state.
- **`shared/utilities/lib.sh`'s comments on `tree_hash`,
  `verify_sha256sums` and `verify_binaries` stop counting callsites and
  stop describing the file as it used to be** (closes #191).
  `tree_hash`'s comment gave the run-time choice between `shasum` and
  `sha256sum` as "made once so `tree_hash`'s two callsites do not each
  repeat it", and named `update_checksum`, `verify_checksum_entry` and
  `installed_version` below it as already making the same choice — a
  list short of `verify_sha256sums` and `verify_binaries`, which make
  the same choice too. The comment now says the helper picks the command
  itself rather than taking one as an argument, and names no caller.
  `verify_sha256sums`'s comment explained its `sha256sum` branch by when
  that branch first ran; it now points at `tree_hash`'s paragraph for
  the pick and says the branch is what a Linux install without `shasum`
  runs. `verify_binaries`'s sentence naming both `verify-binaries.sh`
  scripts as having run the parser inline is dropped rather than
  rewritten: the header's own `verify_binaries` paragraph gives the
  callers' differing checksum file and prefix as the reason nothing is
  defaulted, and each caller names its counterpart above its own
  callsite. Comment lines only; no script behaviour changes.
- **`macos/scripts/electrum/`'s launchers refuse a datadir that cannot
  hold a unix domain socket, and `README.md` now says which platforms
  that limitation reaches** (closes #175). Each macOS launcher binds and
  releases a probe socket inside `electrum-datadir` before starting
  Electrum, through `perl` where `linux/scripts/electrum/`'s launchers
  use `python3`: `/usr/bin/python3` on macOS is an `xcode_select` tool
  shim sharing one inode with `/usr/bin/git` and
  `/usr/bin/clang`, and `xcrun --find python3` answers
  `/Library/Developer/CommandLineTools/usr/bin/python3`, so `command -v`
  answers for the shim and not for the interpreter behind it.
  `/usr/bin/perl` is the interpreter itself. Measured against a volume
  made with
  `hdiutil create -fs ExFAT`: the bind answers `ENOTSUP` where the same
  call in a directory on APFS succeeds, and Electrum's daemon fails to
  start its RPC server on `daemon_rpc_socket` with that errno while the
  app's own window opens regardless, putting the failure in Electrum's
  crash reporter rather than in the launcher's window. A wallet file
  written to such a datadir by `electrum create` is written without
  error, so what exFAT costs on macOS is the RPC channel and every
  command that goes through it. Only a bind the kernel refuses stops the
  launcher: a missing `perl`, or a datadir path longer than a
  `sockaddr_un` can hold, prints a note and lets Electrum start, because
  refusing on a datadir nothing measured shuts a user out of a
  filesystem that works. The probe unlinks its own name before binding
  it, a name already there answering `EADDRINUSE` whatever the
  filesystem underneath supports, and that name is shorter than
  `daemon_rpc_socket` so that the test is never more fragile than what
  it tests. Measured on `windows-latest` against a volume `diskpart`
  formatted `fs=exfat`: Electrum binds a TCP port on
  `127.0.0.1` there instead of a unix socket, and creating a wallet,
  starting the daemon, `load_wallet` and `getbalance` each answer as
  they do against an NTFS control on the same runner, so
  `win/scripts/electrum/` gets no such check.
- **`linux/scripts/electrum/`'s socket probe unlinks before it binds,
  asks its length question about the path Electrum itself binds, and
  takes the short name macOS's carries** (closes #204). The probe is
  `.probe.<pid>`, shorter than `daemon_rpc_socket` at the widest process
  id `pid_max` allows, so the guard is never the more fragile of the two,
  and `electrum-datadir/.gitignore` carries that one name for both
  platforms. Only a bind the kernel refuses stops a launcher: a path that
  does not fit a `sockaddr_un`, an absent `python3` and a `python3` that
  fails each print a note and let Electrum start. Whether the path fits
  is asked of `daemon_rpc_socket` through `connect`, which raises while
  converting the address, before any system call, and creates nothing at
  that name; the refusal leaves the check as exit 4 rather than 1,
  because an uncaught exception in it exits 1 as well. Measured on
  `ubuntu-latest` (`ubuntu-24.04`, kernel `6.17.0-1022-azure`, `python3`
  3.12.3, `pid_max` 4194304) by running `mainnet.sh` itself against a
  `ROOTDIR` built to each length: at `8a2e676` the launcher refused from
  `ROOTDIR` length 62 up, while a control binding `daemon_rpc_socket` at
  the same length bound, and it now starts Electrum across that band.
  From length 73 the control is refused too, with `AF_UNIX path too long`
  and no errno, and the note names the path's length rather than the
  filesystem. With a residue planted at the probe path and the launcher's
  own process id pinned by `unshare -f -p`, `8a2e676` met `EADDRINUSE`
  and refused a datadir on ext4, where the unlink lets the launcher
  start. On an exFAT loopback image on the same runner the bind answers
  `EPERM` and the launcher refuses on every run — a loopback image rather
  than a drive plugged into a running machine, which is the only exFAT a
  hosted runner offers. CPython raises rather than truncating an
  over-long `AF_UNIX` path, so the truncation half of the same defect on
  macOS does not reach these launchers.
- **macOS's `update-electrum.sh` and `rollback-electrum.sh` anchor the
  bare `run_electrum` alternative in `ELECTRUM_PGREP_PATTERN`** (closes
  #168). Unanchored, it matched any process whose command line merely
  carried the string `run_electrum` anywhere, including as an
  unrelated argument to an unrelated program; the anchor now requires
  it to sit at the start of the command line or right after a path
  separator, ending at a space or the line's end, so a genuine source
  or extracted-tree invocation of a script named `run_electrum` still
  matches. Both scripts keep one shared pattern, as `rollback-electrum.sh`'s
  own comment says they do.
- **`linux/bin/README.md` names what belongs in `linux/bin/`, the way
  `macos/bin/README.md` and `win/bin/README.md` already do for their own
  directories** (closes #169). `linux/bin/.gitignore` names the same
  binaries `update-bitcoin.sh` and `update-electrum.sh` install there;
  the new file explains why `bitcoin-qt` and the command-line tools
  arrive together from one archive, unlike the sibling that fetches
  them separately, and why `electrum.AppImage` is installed unmodified
  under a fixed name rather than extracted.
- **`linux/scripts/electrum/`'s launchers refuse to start Electrum
  against a datadir that cannot hold a unix domain socket, instead of
  starting it silently broken** (closes #148). Before exec-ing the
  AppImage, each launcher binds and releases a probe socket inside
  `electrum-datadir` — the same call Electrum's own daemon makes for its
  RPC channel (`daemon_rpc_socket`) — and refuses with an explanation and
  a manual `--dir` workaround if that bind fails, rather than checking
  the filesystem type. Measured on `ubuntu-latest`: Ubuntu's own kernel
  exFAT driver answers the bind with `EPERM`, `exfat-fuse` answers `EIO`
  instead, and neither matches the `os.chmod` crash `electrum/util.py`'s
  `make_dir` was previously found to raise there — that second failure
  does not reproduce on the kernel driver, whose `os.chmod` no-ops
  silently the way macOS's does. Both drivers still leave the daemon
  unable to come up, which is the failure this launcher now catches
  before Electrum ever runs. `README.md`'s *Choosing a filesystem* now
  carries the same fact against its exFAT row. macOS and Windows are
  unmeasured and unchanged.
- **`CLAUDE.md` stops calling `linux/scripts/lib.sh` and
  `linux/scripts/utilities/lib.sh` "a future" thing, and its
  executable-bit bullet's own quoted command now answers what it
  claims** (closes #173). Both files have forwarded since ISS 116
  landed, before ISS 123's own cut point; the *shared code* bullet now
  says so in the present tense, and names which scripts under
  `linux/scripts/` source which of the two, rather than leaving a
  future-tense sentence describing a tree that already shipped.
  `git ls-files -s | awk '$1 == "100755" { print $4 }'` — the command
  the executable-bit bullet quotes — answers with `linux/scripts/`'s
  own `.sh` files beside `macos/scripts/`'s, ISS 121 having given
  `linux/scripts/utilities/*.sh` the bit before ISS 123's cut point
  too; the bullet's claimed output ("with nothing else") is corrected
  to match, rather than left silently wrong beside the command that
  disproves it. The same bullet's aside on which `lib.sh` files are
  sourced rather than run drops its enumeration instead of growing a
  further entry. That aside listed `shared/`'s two and `macos/`'s two,
  and had been incomplete since `linux/scripts/lib.sh` landed with
  `update-bitcoin`'s own Linux half (issue #117) — not a staleness this
  entry's own diff introduced, but one it would have carried forward
  had it named the Linux forwarders in the sentence above and left the
  aside alone. It is the shape
  [ISS 164](https://github.com/btclib-org/portanode/issues/164) landed
  to remove from two library headers, and completing it to six would
  have set the same trap for whichever platform lands next.
- **`macos/scripts/utilities/lib.sh` and `linux/scripts/utilities/lib.sh`
  no longer name which scripts source them directly** (closes #164).
  Both headers listed the scripts sourcing `$SCRIPT_DIR/lib.sh` rather
  than the platform's own root forwarder, as the reason this file stays
  a separate forwarder instead of being folded away; `verify-binaries.sh`
  started doing that too once its parser moved into
  `shared/utilities/lib.sh`, and macOS's header went further, asserting
  every other script "never touches this file directly" — false on both
  platforms once `verify-binaries.sh` is counted. An enumeration of a
  library's own direct callers goes stale on any change to any one
  caller's sourcing, with nothing to catch it; both headers now say why
  the forwarder exists without naming who currently uses it, and point
  at the `git grep` that answers that question live instead.
- **Each platform's `*/scripts/electrum/README.md` now says that
  `mainnet` and `mainnet-local-server-only` are alternatives against
  the same datadir, not a pair to run together** (closes #158).
  Measured on Linux, on a GitHub Actions `ubuntu-latest` runner (run
  `32940638366`): starting `mainnet-local-server-only.sh` while
  `mainnet.sh`'s own process is still running produces no process of
  its own, and a `daemon`/`daemon_rpc_socket` left behind by a
  terminated first instance — confirmed present after both a `SIGTERM`
  and a `SIGKILL` of its whole process tree — does not, by itself,
  block the other launcher from starting. The Linux README states this
  as measured; the macOS and Windows READMEs state the same effect as
  expected, since neither platform's pair of launchers checks for a
  running sibling either, rather than as something checked on either
  platform.
- **`README.md`, `CLAUDE.md` and `CONTRIBUTING.md` name Linux beside
  macOS and Windows wherever they named the other two** (closes #123):
  the *Folder Structure*, *Detailed Setup*, *Updating Binaries*,
  *Expected Binaries by OS*, *Troubleshooting*, *Security Notes* and
  *Version Compatibility* sections gain the `linux/` paths beside the
  existing two, *Quick Start* and *Launcher Notes* say plainly that the
  root `Bitcoin-Launcher.sh`, `Electrum-Launcher.sh` and
  `Utilities-Launcher.sh` still refuse Linux rather than reaching
  `linux/scripts/`, and `CONTRIBUTING.md`'s gate section says
  `shellcheck` already reads a launcher by its shebang rather than by
  directory, so `linux/scripts/`'s own `.sh` files needed no new hook.
  `CLAUDE.md` gains a measured Linux exFAT fact beside the macOS one:
  on GitHub Actions `ubuntu-latest`, mounting an exFAT image through
  the in-kernel `exfat` driver with no `fmask` given resolves to
  `fmask=0022` — the driver's own fixed default, not the umask-derived
  mask ISS 110's own source-derived claim predicted — and a script
  survives `chmod 644` there the same way it does on macOS, exit 0;
  raising `fmask` past `022` clears the execute bit and the same script
  fails, `Permission denied`, exit 126, which `README.md`'s own
  *Choosing a filesystem* table now cites in
  place of the "documented by the driver rather than measured" wording
  it shipped with. Ubuntu's `ntfs3` driver stays cited as the kernel's
  own documentation rather than as measured here, that half of the
  table's exFAT-versus-NTFS reasoning being outside what this branch
  measured.
- **`win/scripts/utilities/*.bat`'s `powershell -Command` blocks no
  longer split a `^` inside the quote they open** (closes #144). A `^`
  at the end of a batch line continues it only while cmd's quote state
  is closed at that point; every block under this directory opened its
  outer quote on the first physical line and closed it on the last, so
  an interior `^` was a literal character and everything past it ran as
  an unrelated cmd command instead of continuing the script. Measured
  on `windows-latest` against `lib.bat`'s `:update_checksum` and
  `:verify_checksum`: the checksum entry was silently never appended,
  and verification returned failure for an entry that matched, in both
  cases because the guard right after the call reads `%errorlevel%` on
  a command the caret split left it not running. Each block is now
  built as a single physical line instead, converging with the fix
  `win/scripts/bitcoin/regtest-*-cli*.bat` already carry (issue #133);
  measured the same way, `:update_checksum` now appends the correct
  hash and `:verify_checksum` and `:installed_version` read it back
  correctly. `:update_checksum`'s interpolated `"$hash ... $version"`
  string is now single-quoted concatenation instead: nested inside the
  quote that wraps the whole `-Command` argument, its own quotes were
  silently stripped while cmd built PowerShell's argv, which the caret
  split had until now kept unreached.
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
- **Linux's `ELECTRUM_PGREP_PATTERN` anchors `run_electrum` to where a
  program name can appear, in `update-electrum.sh`, `rollback-electrum.sh`
  and `health-check.sh` alike** (closes #156). Unanchored, the alternative
  matched any process whose command line merely carried the string
  `run_electrum` anywhere, including as an unrelated argument to an
  unrelated program; the anchor now requires it to sit at the start of
  the command line or right after a path separator, ending at a space or
  the line's end. The three Linux scripts keep one shared pattern, as
  `health-check.sh`'s own comment says they do.
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
- **The same six Windows regtest CLI launchers quote `%ROOTDIR%` and
  `%DATADIR%` where `BITCOIND_CMD` and `CLI_CMD` build them, instead of
  leaving either exposed to cmd.exe's own metacharacters** (closes
  #145). `ROOTDIR` is wherever the folder is mounted, not a name this
  repository chooses, and a directory name may legally carry a `&`,
  which cmd.exe reads as a command separator anywhere it sits outside
  an open quote; the two variables sat there unquoted in all six
  launchers. Measured on `windows-latest` with `ROOTDIR` carrying one:
  `Get-CimInstance Win32_Process` showed the spawned `cmd.exe` had
  received only the fragment before the `&`, `bitcoind.exe` never
  started, and `CLI_CMD` in a first candidate fix lost `title` and
  `doskey` entirely, because the unquoted `&` inside it split the `set`
  statement itself at assignment time, before `CLI_CMD` was fully
  built. `BITCOIND_CMD` now wraps `%ROOTDIR%` and `%DATADIR%` each in
  its own quote pair; `CLI_CMD` instead stays one continuous quote with
  no interior close/reopen, since its own `&`s are load-bearing —
  chaining `cd`, `title` and `doskey` for `cmd /k` — and closing then
  reopening the quote around `ROOTDIR`/`DATADIR` the way `BITCOIND_CMD`
  does would leave that same `&` unprotected again. Confirmed on
  `windows-latest` with a mount path carrying a `&`: the spawned
  `cmd.exe` processes' own `CommandLine` shows the path intact and
  correctly delimited in both variables. What this did not establish is
  a stand-in `bitcoind.exe` actually running end to end under `cmd /k`
  on that path — the hosted runner has no desktop session, and an
  interactive `cmd /k` console reports "Input redirection is not
  supported" there regardless of the quoting, a runner limitation
  distinct from the fix itself.
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
- **`.pre-commit-config.yaml`'s `typos` hook is `repo: local`, converged
  on `btclib-org/.github`'s own** (issue btclib-org/.github#399).
  `additional_dependencies: [typos==1.49.0]` carries the version pin
  `rev:` used to, and `language`, `entry`, `args` and `types` are
  upstream's own hook definition, copied in rather than fetched —
  `local` and `meta` are the two `repo:` values `pre-commit autoupdate`
  filters out before it walks the rest, so `autoupdate` can no longer
  propose `crate-ci/typos`'s moving `v1` alias here.
- **`REPOSITORY.md`'s *Rulesets* section names no tag, and gives the
  command that reads which ones `tag-integrity` has to match** (closes
  #236). The section explained the rule by grandfathering `v2026.01.27`
  as a lightweight tag, and that tag and the release with it are gone
  from the forge; a tag is a ref in the repository where everything else
  in that file is a setting outside it, so what the file keeps is the
  read rather than the name. `RELEASING.md`'s tagging step loses the
  sentence resting on the grandfathered tag and keeps the
  cross-reference.
- **`REPOSITORY.md`'s *Security settings* table now carries a row for
  every key `.security_and_analysis` answers, and this file keeps its
  own combined-heading shape rather than the organization standard's
  siblings' one heading per setting** (issue btclib-org/.github#468).
  The table read three of `.security_and_analysis`'s five keys and left
  `secret_scanning_non_provider_patterns` and
  `secret_scanning_validity_checks` to the paragraph below it; all five
  are rows now, and that paragraph points at the table instead of
  repeating their state. The topics and private-vulnerability-reporting
  readbacks ISS 468 asks every copy for are already this file's, under
  *Topics* and the same table's own row, and every command this file
  carries answers what the file records beside it. Splitting the
  settings into one heading per setting, as the two landed copies do,
  would rename what this file already reads back correctly without
  closing a gap, so this tree keeps the table.
- **`RELEASING.md`'s *The version string* says that no release carries
  the string `VERSION` holds, and `CHANGELOG.md` and `RELEASE_NOTES.md`
  send a reader from their own headers to that file's check on the
  forge** (issue #240). `2026.01.27` is the day the folder was assembled,
  and the forge carries neither a tag nor a release naming it; *Cutting
  one*'s second step strikes that paragraph at the first release, so the
  state is recorded where the procedure that ends it will meet it.
- **`README.md`'s *Prerequisites* and *Troubleshooting* send a reader to
  the ZIP of `main` the repository page offers, rather than to a
  release's source archive** (closes #239). Both bullets rest on the
  executable bit surviving the route rather than on which archive it is,
  and that ZIP hands back the mode the index records; the releases page
  they named lists nothing. `RELEASING.md`'s opening paragraph says what
  a release ships rather than where a folder is taken from.
- **`CLAUDE.md`'s `ROOTDIR` convention turns on what a path is used for,
  and the Electrum launchers' comments record that ground where they
  print an absolute path** (closes #219, #206). A path the launcher
  itself consumes is relative; a path printed for use outside that
  process is absolute, which is what `$ROOTDIR` alone, a Bitcoin
  launcher's opening block of resolved locations, a note reporting that
  a path is too long, and the command an Electrum launcher prints for
  pasting into a shell have in common. The convention's letter would
  render that note's path relative as
  `electrum-datadir/daemon_rpc_socket`, which fits any `sockaddr_un`, so
  the sentence would report a path as too long by naming one that is
  not, and the remedy it gives — a mount point with a shorter path —
  would have nothing left to act on; the pasted command rendered
  relative does not run at all. `REVIEWING.md`'s question asks the
  path's use rather than its form, and its sweep reads `printf` and
  PowerShell's `Write-Host` and `Write-Output` as prints beside `echo`.
- **`.gitattributes` states the union price as section 9 of the
  standard does** (issue btclib-org/.github#423): the driver is a
  checkout's and the forge does not apply it, so a pull request whose
  `CHANGELOG.md` or `RELEASE_NOTES.md` overlaps its base is reported
  `CONFLICTING` however cleanly the pair merges locally, and a rebase on
  a checkout is what clears it.
- **`.markdownlint.jsonc` points at section 14 of the standard for who
  carries it** (issue btclib-org/.github#316), in place of an
  enumeration of trees.
- **`CONTRIBUTING.md`'s shared half is btclib-org/.github's** (issue
  btclib-org/.github#281): the half is replaced whole rather than each
  change applied by hand, a hand-written list of them being what comes
  up short. Among them, *The landing queue* points at `REPOSITORY.md`'s
  *Plan-gated settings* for the ceiling's figure (issue
  btclib-org/.github#412).
- **`linux/scripts/electrum/`'s socket refusal names what its guard
  measured, and the command it prints in place of its own carries no
  empty argument** (closes #212, closes #216). The guard binds a unix
  socket in the datadir and asks nothing else, so a refusal establishes
  that the daemon's `daemon_rpc_socket` cannot be there and that every
  command against a wallet kept in that datadir goes through it — the
  sentence the macOS launchers carry — rather than that no wallet file
  can be written, which the datadir refutes: on an exFAT loopback under
  Linux's own driver, mounted `fmask=0022`, the bind answers `EPERM`
  where an ordinary file written beside it is there afterwards and reads
  back. `mainnet.sh`'s argument list holds no network flag
  after `--dir`, so the slice the printed command interpolates is empty
  and `printf` runs its format once more against nothing, offering the
  reader a command with a trailing empty argument to paste.
- **`win/scripts/utilities/health-check.bat` names the `bitcoin-cli`
  that answered rather than looking one up** (closes #209). That arm is
  reached only from the block which ran the folder's own
  `bitcoin-cli.exe` at its absolute path and got an answer, so a lookup
  there has no second candidate to find, and the `PATH` label printed
  where the lookup came back empty named where the answer had not come
  from.
- **A `ROOTDIR`-derived value echoed from inside a parenthesised block
  is read through delayed expansion** (closes #211), in
  `win/scripts/utilities/health-check.bat`, `update-bitcoin.bat` and
  `update-electrum.bat`. Percent expansion runs before cmd.exe matches
  the block's parentheses, so a closing parenthesis in the mount point
  ends the block early, and a caret cannot escape a character that
  arrives after the line was written. Measured on `windows-latest`, the
  folder unpacked under a directory whose name carries one:
  `health-check.bat` stops after its own first line, cmd.exe refusing
  the block with `was unexpected at this time.` and exit 255, where this
  file prints its disk-free line with the mount point whole and every
  line below it.
- **The launcher menu header names the resolved root on the `.bat` and
  `.ps1` halves, as the `.command` half already does** (closes #217).
  The folder is mounted at a different point on every machine it is
  plugged into, so the header is what tells a user which plugged-in copy
  the menu in front of them belongs to. The `.bat` half quotes the root
  where the other two parenthesise it: a mount point carrying `&`
  reaches cmd.exe's parser on that line, and the quotes are what keep it
  data — written `^(%ROOTDIR%^)` the same line prints as far as the `&`
  and cmd.exe then reports the remainder as a command it cannot find.
- **A `.ps1` launcher's menu does not pause on a script that returns to
  it** (closes #222). PowerShell runs a `.bat` through a cmd.exe of its
  own, whose command line names the script and so reads to
  `win/scripts/root.bat`'s `:pause_if_own_console` exactly as a
  double-click of that script does; the `.ps1` launchers set
  `PORTANODE_LAUNCHER`, which the label reads before that test. Measured
  on `windows-latest`, a menu selection whose script fails prints
  `Press any key to close this window.` before returning to the menu and
  no longer does, while the same script started outside a launcher still
  pauses. The
  `.bat` launchers need no flag, their `call` keeping a console whose
  command line names the launcher.
- **Every workflow-status badge at the head of `README.md` carries
  `?branch=main`** (issue btclib-org/.github#579). `lint` and `links`
  answer for `main` or answer `no status`, where the unqualified badge
  falls back to another branch's run when `main` has none; the
  pre-commit.ci badge is outside the rule, its branch being in its path.
- **`REPOSITORY.md`'s *Plan-gated settings* carries the concurrent-job
  ceiling, which section 10 of the organization standard names as that
  figure's one home per tree** (issue btclib-org/.github#569, issue
  btclib-org/.github#412). `CONTRIBUTING.md`'s *The landing queue*
  already pointed at that heading, where the section under it was about
  secret scanning alone; `gh api orgs/btclib-org --jq .plan.name` and
  GitHub's limits table are what the number now sits beside.
- **`.github/workflows/links.yml` passes `--include-fragments`** (closes
  btclib-org/.github#583). A link into a heading is then checked as an
  anchor and not only as a page, so a heading renamed in the tree a link
  here points into is red here rather than nowhere; the check reads a
  page already fetched, so it adds no request. Every anchor this tree
  carries into another repository of the organization is the bare
  `github.com/<owner>/<repo>#<heading>` shape, whose missing fragment the
  token overrides — lychee falls back to the repositories API and takes
  the repository's existence as the answer — so what the flag reads here
  is the fragments of the other hosts. btclib-org/.github#630 weighs that
  shape.

### `.gitattributes`'s comment names the driver's sides and one anchor

- **The comment keeps `ours` first and `theirs` second, names which side
  each of a merge and a rebase calls `ours`, and premises the driver on
  an entry arriving at one shared anchor rather than a bullet appended
  to one of a few changelog groups** (issue btclib-org/.github#646).

### CLAUDE.md's worktree removal line stands in a block of its own

- **`git worktree remove --force "$WT"` stands in a block of its own**
  (issue btclib-org/.github#676): the line above it ends in a
  placeholder, and a shell that discards that line as a parse error
  reads the next as a fresh command, so a paste of the block removes
  whatever `$WT` a session that has already been through it still holds.
  Its own block is the one CLAUDE.md's reader pastes deliberately.

### `REPOSITORY.md`'s *Variables* reads both stores back for the review switch

- **`REPOSITORY.md` carries a *Variables* section, which reads the
  repository's Actions variable store and the organization's back for
  `vars.CLAUDE_REVIEW_ENABLED`** (issue btclib-org/.github#682). Both
  answer empty, which section 11 of the organization standard reads as
  the switch's off state, so this file answers in one command whether
  the review gate is on here.

### The single-hook gate line lints from a clean tree

- **`uvx pre-commit run markdownlint-cli2` reads the staged files, so
  from a clean tree it reports `(no files to check)Skipped` and exits
  0** (issue btclib-org/.github#688). `CONTRIBUTING.md`'s single-hook
  line carries `--all-files` as the line above it does, and the hook id
  is the whole of what separates the two.
- **`--all-files` reaches every markdown file this tree tracks** (issue
  btclib-org/.github#688). `markdownlint-cli2` carries neither `files:`
  nor `exclude:` in `.pre-commit-config.yaml`, and that file declares no
  top-level `exclude:`, so the hook id is all that narrows the run — the
  `README.md` files under `macos/`, `win/` and `linux/` included.

### The placeholder ends the `git worktree add` command

- **`git worktree add "$WT" origin/main -b <branch>`, the flag and its
  placeholder last** (issue btclib-org/.github#687). A paste made before
  `<branch>` is filled in redirects into whatever follows it, so with the
  placeholder ahead of `"$WT"` the `>` creates a file at that path — the
  state the block's own removal line leaves behind, where no directory
  stands in the way. Section 9 of the organization standard is the rule
  the order satisfies, and `CLAUDE.md` states it beside the block.

### rootdir_taint sweeps every shell, and the READMEs say what a reader may do

- **`REPOSITORY.md` states what it records and what it passes over,
  where it claimed to be the whole of the settings outside the tree**
  (issue btclib-org/.github#551). Section 11 of the organization
  standard rejects the blanket claim on the ground that no command
  checks it, and asks instead for the settings the standard itself asks
  about, which is a perimeter a copy can be held to. *What this file
  passes over* at the foot names the fields no section of the standard
  states a rule for, the endpoints that answer empty, and what falls
  inside the scope and is not recorded yet — the default branch and the
  absence of a Pages site, which are btclib-org/.github#549. *Merge
  methods* reads `allow_auto_merge` back beside the merge buttons, the
  auto-merge it describes resting on that setting
  (btclib-org/.github#566), and the opening no longer claims that nothing
  here can be recovered by reading the tree (btclib-org/.github#571).
- **`REVIEWING.md`'s `rootdir_taint` sweep answers for the `.ps1` half, and
  answers alike in `bash`, `sh` and `zsh`** (closes #294, closes #295). The seed
  was `ROOTDIR`, which no `.ps1` here spells, so that half was swept by a
  pattern nothing in it could match; and unquoted expansions left the walk to
  `IFS`, which `zsh` does not apply to a parameter, so a reviewer pasting the
  block into their own shell read a short list as a clean tree. The seed carries
  `$Root` and `$RootDir` beside `ROOTDIR`, the assignment pattern carries
  PowerShell's `$name = value`, the loops read a line at a time, and the
  function writes the tainted set to stderr, which is what tells a zero apart
  from a walk that never left its seed.
- **`README.md` says how to take the folder, under a heading of its
  own** (closes #243). *Quick Start* opens at a folder already on the
  disk, and the routes that put it there were subordinate clauses of a
  *Prerequisites* bullet whose subject is the executable bit and of a
  *Troubleshooting* bullet whose subject is a folder that arrived some
  other way. Each of those keeps its own subject and points at *Getting
  the folder* for the route.
- **Every `scripts/utilities/README.md` says a script may be run from
  any working directory** (closes #245). Each told a reader to run from
  the project root or the repo root, and no script there reads the
  working directory: every one resolves the folder's root from its own
  location or from `PORTANODE_ROOT`. They name that root the way
  `README.md` and `CLAUDE.md` do, a reader on a removable volume having
  no repository in front of them. The Windows half also says that the
  `.ps1` files beside its `.bat` entry points are none of them run
  directly, each being called by a `.bat` with whatever that call needs.

### Both datadir `.gitignore` files deny by default

- **`bitcoin-datadir/.gitignore` and `electrum-datadir/.gitignore` deny
  everything and name their own tracked files back in** (closes #196).
  Each used to enumerate Bitcoin Core's or Electrum's runtime artifacts
  one at a time, a shape that goes stale the moment either project's
  own layout gains a file nobody here has named for it. Denying by
  default makes an unlisted runtime file ignored on sight instead, and
  a tracked file that goes missing shows up as absent from
  `git ls-files` rather than as a silent gap in an enumeration. The
  reasoning is in `bitcoin-datadir/.gitignore`'s own comment, and
  `electrum-datadir/.gitignore` points back at it rather than repeating
  it.

### `RELEASING.md`'s rollback commands end in their placeholder

- **`gh release delete --yes v<version>`, `git push origin --delete
  v<version>` and `git tag -d v<version>` put the placeholder last in
  every line** (closes #317). Quoted, `<version>` was ordinary text, so
  an unfilled paste ran all three regardless of position. Unquoted with
  a word following it — the first line's own prior order,
  `v<version> --yes` — `<` reads stdin from a file named `version` and
  `>` writes its target to a file named for the word that follows, so
  the paste still reached `gh` with the tag truncated to `v` and `--yes`
  consumed as a redirection target, wherever the paste's own directory
  held a matching file; `RELEASING.md`'s every other step assumes that
  directory is the repository root, which holds `VERSION`, and the
  default macOS volume format resolves that match case-insensitively.
  Section 9 of the organization standard is the rule that puts the
  placeholder last.

### The `.bat` and `.ps1` scripts read a mount point's `&`, `[` and `]` as data

- **`Resolve-Path` and `Test-Path` in `win/scripts/root.ps1` and the
  three root `.ps1` launchers take `-LiteralPath`** (closes #297). Both
  read an argument without it as a wildcard pattern, so a mount point
  holding `[` or `]` answered *not found* for a directory and a file
  that were both on disk, and the root walk ran past the root it was
  meant to stop at.
- **`monitor-bitcoin-log.ps1` and `verify-binaries.ps1` take the same
  `-LiteralPath` fix**, the pattern `filesystem-type.ps1` and
  `free-space-gb.ps1` already carry: both build the path they test from
  `$RootDir`, the value the bullet above is about.
- **The `.bat` utilities' `set` and `echo` of `%ROOTDIR%` and `%~dp0`
  are quoted** (closes #298). Unquoted, an `&` arriving through either
  expansion ends the command at the `&` and runs the remainder as a
  command of its own, or truncates the assignment silently and leaves
  the script running on the truncated value; `health-check.bat`'s own
  `%~dp0` capture reached this before `%ROOTDIR%` was even resolved.
- **`set-permissions.bat`'s `%USERDOMAIN%\%USERNAME%` echo reads them
  through delayed expansion instead** (closes #300), the file already
  running under `setlocal enabledelayedexpansion`: a `%`-expanded value
  is parsed for metacharacters before the block it sits in runs, an
  `!`-expanded one only once that line executes, past the point cmd.exe
  would otherwise have split it.

### The blinter comparison key adds each group's line-number set

- **`CLAUDE.md`'s blinter bullet compares a diff's two sides by file, by
  rule code, and by the set of line numbers each group's own
  `Line N, M:` header carries** (closes #301). A count of that same
  header is not enough: a fixed instance of a code paired with a
  different, newly introduced instance of it elsewhere in the file
  leaves the count unchanged, where the line numbers themselves still
  differ.

### REPOSITORY.md's Secrets and Security settings sections match their endpoint

- **`REPOSITORY.md`'s Secrets paragraph names a secret held in a store,
  not the token Actions mints for every workflow's job, so `links.yml`'s
  `secrets.GITHUB_TOKEN` sits outside the claim rather than contradicting
  it, and its Security settings paragraph reads CodeQL's own language
  list off `code-scanning/default-setup` instead of `code-quality/setup`**
  (closes #307, closes #313). `code-scanning/default-setup` answers
  `actions`, so CodeQL does have a subject in this tree — its own
  workflow files — and `code-quality/setup`'s empty list is a different
  feature's answer, not a second reading of the same one.

### `health-check.bat`, `rotate-bitcoin-log.bat`, `clean-artifacts.bat` pause

- **Each calls `:pause_if_own_console` before every `exit /b` it
  reaches** (closes #299), the same call the rest of
  `win/scripts/utilities/` already carries. All three return only on a
  success path, with no `exit /b 1` in any of them, so the call sits
  before an `exit /b 0` rather than after an echoed error.

### A `--version` value reaches the `.bat` updaters as data, not as syntax

- **`update-bitcoin.bat` and `update-electrum.bat` quote the `set` of
  `FILE`, `BASE_URL`, `URL`, `CHECKSUM_URL` and `CHECKSUM_SIG_URL`, and
  read them back through delayed expansion in every `echo`** (closes
  #318).
  `%VERSION%` reaches these two files from a scrape regex-constrained to
  digits and dots, or from a `--version` argument the caller quotes
  themselves; quoting a caller's own argument does not stop it holding
  an `&`, so an unquoted `set` or `echo` downstream of it is the same
  hazard #298 found in `%ROOTDIR%`, reachable by a different value.

### The network scripts name a missing binary by its ROOTDIR-relative path

- **Every network script under `bitcoin/` and `electrum/` names a
  missing binary, or the missing binaries directory, by its path under
  `ROOTDIR` rather than by the absolute path this machine resolved**
  (closes #205). The `.sh` and `.command` halves strip the `ROOTDIR`
  prefix with `${x#"$ROOTDIR"/}`, `shared/utilities/lib.sh`'s own
  idiom, and the `.bat` half, the only Windows half these scripts
  carry, writes the constant suffix literally in place of
  `%ROOTDIR%\...`.

### The `-cli` launchers check `bitcoin-cli` before they start anything

- **The regtest `-cli` and `-cli-clean` launchers test `bitcoin-cli` the
  way they already test `bitcoind`, and refuse before starting the
  daemon — and, in the `-clean` variants, before deleting the regtest
  data** (closes #326). Unchecked, the `.sh` and `.command` halves reach
  the shell's own error the first time the reader types `btc`, and the
  `.bat` halves reach whatever `bitcoin-cli.exe` is on `PATH`, the
  `doskey` macro naming the bare binary after a `cd /d` into `win\bin`.
  `CLAUDE.md` carries the rule this follows and why `health-check`, which
  reports on the datadir rather than running the folder, is outside it.

### `health-check` resolves `bitcoin-cli` the same way on every half

- **`win/scripts/utilities/health-check.bat` resolves the client into
  one variable and falls back to a `bitcoin-cli` on `PATH`, which the
  two `.sh` halves already do** (closes #303). The Windows half wrote
  `%ROOTDIR%\win\bin\bitcoin-cli.exe` out at every site that used it
  and reached no other candidate, so on `windows-latest`, with a folder
  whose `win\bin\` was empty, a `bitcoin-cli.exe` on `PATH` and a
  `bitcoind.exe` running, it answered `Bitcoin running: yes (tasklist)`
  and `Bitcoin sync: unknown` without ever invoking that client.
  `macos/scripts/utilities/health-check.sh` carries what pins a borrowed
  client to this folder's own datadir; the other two point at it rather
  than restating it. A client found on `PATH` is printed by the
  absolute path `where` returned, a binary outside the folder being
  outside the ROOTDIR-relative rule rather than an exception to it.

### `--dry-run`'s archive-size request is bounded, and says so on failure

- **`update-bitcoin.bat` and `update-electrum.bat` pass `-TimeoutSec 30`
  on the `Invoke-WebRequest -Method Head` behind `--dry-run`'s
  archive-size estimate, and print an `Archive size: unknown` line where
  no `Content-Length` comes back** (closes #327). It is the value
  `latest-bitcoin-version.ps1` and `latest-electrum-version.ps1` pass on
  their own requests. Measured on
  `windows-latest` against a host that accepts the connection and never
  answers: both files reach the free-space line and exit, where before
  this fix both were still inside the request when the probe's own cap
  killed them, having printed nothing about the size at all.
- **The `set` taking the response's `Content-Length` back into `cmd.exe`
  is quoted**, the form #318 gave `URL` in these same two files: the
  header is whatever the server sent, so an `&` in it ends the
  assignment and runs the remainder as a command where the `set` is
  bare.

### The three root probes ask for `VERSION` beside a platform directory

- **`root.bat`'s `:find_root` and `root.ps1`'s `Resolve-PortaNodeRoot`
  require `VERSION` plus one of `macos\`, `win\` or `linux\`, and
  return the directory the walk started in where it finds none** (closes
  #305). That is the marker `resolve_root` in `shared/lib.sh` looks for,
  so a directory holding `VERSION` and no platform directory is walked
  past by all three; a file named `win` beside `VERSION` no longer
  answers either, the `.bat` half testing for a trailing separator and
  the `.ps1` half for `-PathType Container`. The drive root a failed
  walk returned is also what a hit returns for a folder unpacked at the
  top of a volume, which is what makes it the wrong value to hand back.
  `README.md` names the marker the three agree on.

### `:pause_if_own_console` waits for 30 seconds instead of blocking

- **`win/scripts/root.bat` ends the wait with `timeout /t 30` rather
  than `pause`** (closes #340). Its test asks which script a console was
  opened for, and a scheduled task's console answers that the way a
  double-click does, so a run under Task Scheduler reached `pause` with
  nobody there to press a key. Measured on `windows-latest` with the
  action registered as `cmd.exe /c "<script>"` and run as SYSTEM:
  `rotate-bitcoin-log.bat` read `State=Running` and
  `LastTaskResult=0x41301` ninety seconds in, and reads `Ready` and
  `0x0` once the wait expires on its own.
- **`validate-setup.bat`, `set-permissions.bat` and
  `monitor-bitcoin-log.bat` call it before every `exit /b` that ends
  them, the success return included** (closes #324).
  `set-permissions.bat`'s `:report_permission_effect` carries none: its
  `exit /b 0` returns from a `call` rather than ending the script, so a
  wait there fires once per data directory before the script has
  finished printing.

### The root walk ends at `/` rather than where a directory equals its parent

- **`resolve_root` in `shared/lib.sh` stops the walk on reaching `/`**
  (closes #339). Comparing the next directory with the current one does
  not stop it: the next directory is `"$dir/.."`, which at `/` is
  `//..`, and a leading double slash is implementation-defined in POSIX
  and kept by bash, so `//..` resolves to `//` and `///..` back to `/`
  and the two alternate. A caller with no `VERSION` above it is handed
  `start_dir`, the fallback `CLAUDE.md`'s *`resolve_root` fails
  silently, not loudly* describes, where before it got no answer at all.

### The blinter encoding-warning block is dropped from the comparison

- **`CLAUDE.md` drops the `was read using 'utf_8' encoding` block, which
  blinter writes to stderr, rather than comparing it across two runs**
  (closes #335). Which files the block names moves under an ASCII-only
  edit to an unrelated part of them, so a comparison that keeps it opens
  on a difference the diff did not make. `blinter/io/encoding.py`
  reports the encoding name `charset_normalizer` handed it and compares
  that name against `utf-8`, `utf-8-sig` and `ascii`, while
  `charset_normalizer` answers `utf_8`, which none of the three matches:
  a file holding no byte above 127 is named, and converting it to UTF-8
  as the warning advises is a no-op on it.

### The repository is releaseless by decision, and `RELEASING.md` says so

- **`RELEASING.md`'s *The version string* records that no release is owed
  for `2026.01.27`, and what the `[2026.01.27]` heading means in that
  state** (closes #240). A release here is an announcement and a fixed
  point to roll back to, so the tag a re-cut would sit on names a tree
  `README.md` sends nobody to; the heading, in this file and in
  `RELEASE_NOTES.md`, dates the entries under it and names nothing on the
  forge. Both files are append-only, so the sentence sits in the file
  their headers already point at rather than in a rewritten heading, and
  *Cutting one*'s second step strikes it with the paragraph above it at
  the first release.

### `validate-setup.bat`'s prune test reads one search string, not several

- **`win/scripts/utilities/validate-setup.bat` passes its `prune=`
  pattern behind `findstr`'s `/C:`** (closes #332). A search string
  carrying spaces is otherwise split on them, and the trailing piece,
  `]*[1-9]`, matches any line holding a digit `1`-`9` -- which this
  tree's own `bitcoin-datadir/bitcoin.conf` does, so a `bitcoin.conf`
  with no `prune=` in it read as pruned and the 700GB warning never
  printed. `/R` stays beside `/C:`: measured on `windows-latest`, `/I
  /C:` without it matches the pattern literally and so finds nothing in
  a `bitcoin.conf` carrying `prune=1000`. Running the script whole from
  a 300GB volume, the warning prints for a conf holding no `prune=`,
  for one holding `prune=0` and for one holding `#prune=1000`, and
  stays silent for `prune=1000`, for a space-indented `prune = 1000`
  and for a `prune=550` under `[main]` -- which is what
  `linux/scripts/utilities/validate-setup.sh` prints on the same files,
  from a 300GB loopback image on `ubuntu-latest`. A tab-indented
  `prune=` still reads as unpruned here, the `.bat` pattern's class
  holding a space where the `.sh` halves' `[[:space:]]` holds both.

### The Windows `btc` runs the folder's own `bitcoin-cli.exe`

- **The regtest `-cli` and `-cli-clean` launchers hand their second
  console to `:cli_console` in `win/scripts/bitcoin/lib.bat`, whose
  `doskey` macro names `bitcoin-cli.exe` by an absolute path under
  `win\bin` and quotes the data directory it passes** (closes #334). A
  bare name is resolved against the console's current directory first
  and `PATH` after, so a `cd` anywhere else in that console left `btc`
  driving this folder's datadir through whatever `bitcoin-cli.exe` the
  machine had installed; the `.sh` and `.command` halves expand
  `"$BTC_CLI"` and cannot reach that state. The macro is defined in an
  ordinary batch line rather than in a command string the launcher
  assembles for `cmd /k`, because a quote pair inside such a string
  leaves a `&` in the mount path to split the `set` statement itself,
  which is the constraint #145 measured.

### The data directories stay readable to the account they are restricted to

- **`set-permissions.bat` grants on each data directory rather than on
  every item under it** (closes #333). `icacls` applies each operation
  on its command line to every item it walks, so a `/t` grant puts
  `(OI)(CI)F` on the files as well, and those flags carry no access on a
  file: each file is left with an empty DACL, which denies the account
  the grant names and Administrators alike. Measured on
  `windows-latest`, in a process running as that very account:
  `type bitcoin-datadir\bitcoin.conf` answers `Access is denied.`, and
  `icacls` prints the file's path with no ACE beside it.
- **Granted on the directory alone, the ACE is inheritable and covers
  the subtree.** Over a data directory carrying `blocks\index\`,
  `testnet4\blocks\index\` and `wallets\my wallet\`, every file reads
  back as `(I)(F)` and opens, a hidden file included, while a
  non-administrative account is refused each one and reads a file
  outside the data directories in the same process.
- **A second `icacls` call enables inheritance on the directory's
  contents, so the grant reaches a file an earlier run left protected
  with an empty DACL.** Such a file takes no inherited ACE until
  inheritance is enabled on it again. The call names the contents rather
  than the directory, and follows the grant rather than preceding it:
  sampling the directory's own ACL while each order ran, `/inheritance:e`
  given the directory itself leaves it unprotected and carrying
  `BUILTIN\Users` through most of the walk, and this order through none
  of it, both ending on the same ACL. `/reset` would serve as the repair
  and drop each object's explicit ACEs with it.

### macOS and Linux bound `--dry-run`'s archive-size request too

- **`update-bitcoin.sh` and `update-electrum.sh` under
  `macos/scripts/utilities/` and `linux/scripts/utilities/` pass
  `--max-time 30` on `--dry-run`'s archive-size request, discard curl's
  status, and print an `Archive size: unknown` line where no
  `Content-Length` comes back** (closes #336). It is the bound the `.bat`
  half of the same estimate passes as `-TimeoutSec 30` (#327). Measured
  on `macos-latest` and `ubuntu-latest` against a host that accepts the
  connection and never answers: each reaches the free-space line and
  exits, where without the bound each was still inside the request when
  the probe's own cap killed it. Discarding curl's status is what keeps
  the rest of the preview: `set -e` with `pipefail` reads a failed
  request as the end of the run, so against a host refusing the
  connection the unbounded scripts printed neither the size nor the free
  space.

### The Windows utility scripts wait on the return a successful run reaches

- **`rollback-bitcoin.bat`, `rollback-electrum.bat`, `update-bitcoin.bat`,
  `update-electrum.bat` and `verify-binaries.bat` call
  `:pause_if_own_console` before the `exit /b` that ends them, whatever
  the result** (closes #337). Measured on `windows-latest` in a console
  of the script's own, opened as `cmd /c "<script>"`, which is what a
  double-click is: a rollback closed on the line that printed `Rollback
  complete.` and now holds the console for the wait, and
  `verify-binaries.bat` holds it for `verify-binaries.ps1`'s report on a
  pass as it already did on a failure. Reached instead through a plain
  `call` from a console opened for something else, none of them waits.
  The measurement carried repairs for the checksum guard (issue #360) and
  the verification report (issue #361) as a fixture, the scripts under
  test unmodified. Until those land, a rollback stops at that guard and
  an intact binary reports `FAILED`, so the returns added to the
  rollbacks and to `verify-binaries.bat` are not reached; the updaters'
  was, with PGP verification skipped.
- **`update-bitcoin.bat` and `update-electrum.bat` make the call from
  `:cleanup`, above `endlocal`**, that being the one return both the
  success path and `:error` reach. One line below `endlocal` it answers
  `'"..\root.bat"' is not recognized as an internal or external command`
  and nothing waits, `SCRIPT_DIR` having been discarded by then.
- **`rollback-bitcoin.bat`'s `:restore_one` carries none**: its `exit /b`
  return from a `call` rather than ending the script, and with the call
  added there a console opened for the script waited once per binary
  moved back, before it had printed `Rollback complete.`

### macOS and Linux bound their version detection and survive an empty keyring

- **`update-bitcoin.sh` and `update-electrum.sh` (macOS and Linux) bound
  their version-detection network calls, and `update-bitcoin.sh` no
  longer dies on an empty gpg keyring** (closes #348, #354). Under
  `set -euo pipefail`, `grep -c '^pub'` exits 1 when it counts zero, so
  `update-bitcoin.sh --dry-run` ended silently at that assignment on a
  keyring with nothing imported, before reaching the warning immediately
  below it that names exactly that case; the assignment now falls back
  to `PUBKEYS=0` on that exit instead. All four scripts' version-index
  fetch, and `update-bitcoin.sh`'s per-candidate archive probe, carried
  no bound: `bitcoincore.org` was measured answering the index in 135 s
  on a repeat request, and either call held `--dry-run` open for however
  long the publisher took. The index fetch now runs under
  `--max-time 300` and the probe under `--max-time 30`; the index fetch
  is still fatal when its bound fires, and the probe skips the
  candidate, and both name what happened rather than folding into a
  generic message or leaving curl's own status to say it.

### The instruction files carry no trailing `#` inside a `shell` fence

- **`CLAUDE.md`, `CONTRIBUTING.md` and `REPOSITORY.md` carry no trailing
  `#` comment on a command line inside a `shell` fence, and
  `REVIEWING.md`'s two filing placeholders are bare** (issue
  btclib-org/.github#771, btclib-org/.github#786, btclib-org/.github#772).
  An interactive `zsh` leaves `INTERACTIVE_COMMENTS` unset, so a trailing
  comment reaches the command as an argument and a quoted placeholder
  reaches the tool as its value rather than failing the paste at the
  shell.

### `win/scripts/bitcoin/lib.bat` guards `rmdir` and keeps `$` out of `btc`

- **`win/scripts/bitcoin/lib.bat`'s `:require_deleted` guards `rmdir` with `if
  exist`, and `:cli_console`'s `btc` macro keeps `ROOTDIR` and `DATADIR` as
  `%`-references cmd expands only after doskey's own `$`-substitution has
  run** (closes #352, #355). The first stops a clean first run from printing
  `rmdir`'s own "The system cannot find the file specified." between the
  warning and the launcher's DATADIR block, leaving `rmdir`'s own message
  intact for a directory it genuinely cannot remove. The second keeps a mount
  path's own `$` out of the macro body doskey stores: measured on
  windows-latest with a path carrying a `$t`, `doskey /macros` read the
  stored body back holding the literal `%ROOTDIR%` and `%DATADIR%`
  rather than either resolved path.

### `validate-setup.bat`'s prune pattern accepts a tab like the `.sh` halves

- **Each of the three character classes in the `findstr` pattern
  carries a literal tab byte beside the space** (closes #346). Before,
  the pattern read a leading space only, so a tab-indented `prune=`
  read as unpruned on Windows against `prune=1000` read as pruned on
  macOS and Linux, whose `[[:space:]]` classes already covered a tab at
  all three positions: before `prune`, between `prune` and `=`, and
  between `=` and the digit. `findstr` has no `\t` escape and no named
  class, so the byte is typed directly into the source rather than
  written as one. `bitcoin/src/common/config.cpp` trims `" \t\r\n"`
  off the whole line before it looks for the `=`, and off the option
  name and the value either side of it afterwards, so a tab at any of
  the three positions is as active to Core as a space, and the three
  halves now agree on it. The tab byte survives
  this tree's own whitespace hooks unchanged; measured on
  `windows-latest`, `findstr` matches a tab-indented `prune=1000` the
  way it already matched a space-indented one, `cmd.exe`'s
  quoted-argument parsing carrying the byte through to it unchanged.

### The Windows updaters carry their own failures to the caller

- **`update-bitcoin.bat` and `update-electrum.bat`'s `:cleanup` reads `STATUS`
  on the same physical line `endlocal` clears it, the backup step's `if
  exist`/`copy` pairs are one physical line each, and each download's
  PowerShell block calls `exit 1` on its own failure** (closes #362, #363,
  #364). `endlocal` on its own line discarded `STATUS` before a separate `exit
  /b %STATUS%` line read it, so a failed update returned 0; a caret between
  `if exist` and `copy` wrote `' ' is not recognized` once per backup pair on
  `windows-latest` instead of running it; and `powershell.exe` exits 0 after
  an uncaught `Invoke-WebRequest` error, so `|| goto :error` never branched on
  a failed download. That block prints the exception's own message before
  it exits, a download otherwise being the one failure in these scripts
  that reaches the user as `Update failed.` and nothing else.

### The Windows checksum guard and single-match count survive their callers

- **`win/scripts/utilities/lib.bat`'s `:update_checksum` and
  `:verify_checksum` test `-not (Test-Path $checksum)` in place of
  `!(Test-Path $checksum)`** (closes #360). Every caller enables delayed
  expansion, inherited across the `call`, and cmd.exe strips the
  unmatched `!` from the argument before powershell.exe sees it, so the
  test reaches PowerShell inverted: `rollback-bitcoin.bat` and
  `rollback-electrum.bat` refuse every rollback, and a verified install
  records no checksum entry. `-not` carries no `!` for cmd.exe's parser
  to strip. `shared/utilities/lib.sh`'s `update_checksum` and
  `verify_checksum_entry` test `[ ! -f ... ]` in a POSIX shell, which
  reads no delayed expansion and carries no equivalent defect.
- **`win/scripts/utilities/verify-binaries.ps1` takes `$hashMatches` and
  `$expectedVersions` from `@(...)`-wrapped pipelines** (closes #361). A
  pipeline yielding exactly one object is assigned as that object rather
  than as a one-element array, and Windows PowerShell 5.1 -- what
  `verify-binaries.bat` runs the script under -- gives a bare object no
  `.Count`, so `$hashMatches.Count -gt 0` reads false for an intact
  binary with one recorded version, and the binary is reported `FAILED`.
- **The returns #337 added to the rollbacks and to `verify-binaries.bat`
  are reached**: the checksum guard above no longer refuses a rollback,
  and `verify-binaries.ps1`'s report reaches the wait on a pass as well
  as on a failure.

### `.github/PULL_REQUEST_TEMPLATE.md` is this repository's own

- **`.github/PULL_REQUEST_TEMPLATE.md` is tracked here, its Checks
  naming the gate this tree runs** (issue btclib-org/.github#781,
  btclib-org/.github#785). Section 2 of the organization standard puts
  the file under `.github/` and gives `.github/` to every tier, and
  section 16's checklist gives it to a repository being set up; a
  repository holding none of its own is served `btclib-org/.github`'s
  copy, which sits in no clone of this one. The Checks of that copy read
  `uv run pre-commit run --all-files` and `uv run pytest`, where
  `CONTRIBUTING.md` here gives `uvx pre-commit run --all-files` — there
  being no project, no `pyproject.toml` and no Python for `uv run` to
  sync — and where there is no suite for a second line to name. So the
  file landed here carries the `uvx` command and no suite checkbox; what
  stands in for a suite is under *How it was verified*, running the
  launcher on a macOS, a Windows and a Linux machine from a volume that
  is not the boot disk.

### `set-permissions.bat` reports the ACL it set rather than assuming it

- **`:report_permission_effect` reads the ACL back off each data directory
  instead of printing an unconditional "permissions restricted to"** (closes
  #349). Every `icacls` call sent its output to `nul` and left its exit code
  unread, so the routine decided what to print from `filesystem-type.ps1`'s
  answer alone: on NTFS it announced the restriction whatever `icacls` had
  done. It now runs `icacls` against the directory and looks for the exact
  ACE the grant asked for, printing the restricted line only once that ACE
  is found. That search runs behind a control, its informative answer being
  a miss: `findstr` answers 1 where the string is absent, where the file is
  empty and where the file is not there at all, three states behind one
  code, measured on `windows-latest`. `icacls` echoes the path it was given,
  so a search for that path separates a report that arrived from one that
  did not, and an ACL that could not be read gets its own message rather
  than being reported as a missing ACE. The propagation call reaches the
  directory's existing contents rather than the directory itself, so a
  directory-level readback cannot see whether it succeeded; its exit code is
  captured beside the call it came from and passed in, and a nonzero one
  gets its own warning quoting that code. The exFAT and FAT32 branch is
  unchanged, having already said `icacls` changed nothing there.

### `--dry-run`'s `Archive size: unknown` line names no wait

- **`update-bitcoin` and `update-electrum` under
  `linux/scripts/utilities/`, `macos/scripts/utilities/` and
  `win/scripts/utilities/` print `Archive size: unknown (the HEAD
  request returned no Content-Length).`** (closes #356). The
  `within 30 seconds` dropped from that line named a wait that expired,
  where a host name that does not resolve, an archive absent from the
  URL the script built and a refused connection each reach the line in
  milliseconds; the request's status is discarded, so nothing there
  tells those apart from the bound firing. The comment beside the line
  says it names the absence rather than a cause, which those words
  contradicted.
- **`linux/scripts/utilities/update-bitcoin.sh` and
  `macos/scripts/utilities/update-bitcoin.sh` say why the candidate
  probe's own message still names the bound**: that message prints
  behind `[ "$curl_rc" -eq 28 ]`, `curl`'s status for the time-out
  period being reached, so there the wait did fire.

### CLAUDE.md's blocks name the directory each command runs in

- **The blinter snapshot runs with `env -C <tmpdir>` and the worktree
  block pushes with `git -C "$WT"`** (closes #347). A `cd` binds the
  shell that runs it, so a session that runs each line as its own
  command reaches the next line in the directory it started in, the
  primary checkout: blinter reports on that tree rather than on the
  snapshot, and the push offers that checkout's `HEAD` rather than the
  worktree's.

### The Windows Bitcoin extraction fails before the backup block runs

- **`update-bitcoin.bat` extracts inside a `try`/`catch` with
  `-ErrorAction Stop` and an `exit 1` of its own, and `BIN_DIR`,
  `BACKUP_DIR` and the paths built on them carry a single backslash**
  (closes #366, #368). `powershell.exe` exits 0 after a non-terminating
  `Expand-Archive` error, so `|| goto :error` did not branch and the
  backup block ran between the failed extraction and the `if not exist`
  guard that caught it: the run overwrote `win\bin\backup\bitcoin` with
  the binaries already installed, leaving `rollback-bitcoin.bat` that
  same version to restore and the reader a message about missing
  extracted binaries rather than about the extraction. The block now
  takes the shape the downloads carry, and the comment above them no
  longer draws its contrast against the checksum block alone, which left
  the extraction step outside it. The doubled backslashes were an
  inconsistency with `update-electrum.bat` rather than a defect, Windows
  collapsing a repeated path separator; the `\\s+` in the checksum
  comment is a regex and stays doubled.

### macOS's `set-permissions.sh` reports the mode it reads back

- **`macos/scripts/utilities/set-permissions.sh` keeps each `chmod`'s
  exit status and reads the data directory's mode back with `stat -L -f
  '%OLp'`, printing the restricted sentence only where that mode is 700
  and the `chmod` exited 0** (closes #376). Derived from `diskutil`'s
  `File System Personality` alone, that sentence printed over a `chmod`
  the filesystem had nothing to do with refusing: measured on an APFS
  fixture whose `bitcoin-datadir` held a `uchg`-flagged `bitcoin.conf`,
  which the run left at 644 under a directory it had set to 700, while
  reporting that directory restricted to its owner. A `chmod` that
  failed now names its exit code, and a directory that reads something
  other than 700 is reported with the mode it does read. The messages
  name the filesystem without an article, `diskutil`'s answers not all
  taking the same one.
- **`CLAUDE.md`'s worktree paragraph names the condition under which a
  paste with `-b <branch>` ahead of `"$WT"` writes a file** (closes
  #386). `<` and `>` are performed left to right, so the `>` closing the
  placeholder is reached, and the file written, only where the reader's
  own directory already holds a file named `branch`; ordinarily it does
  not, and the `<` fails first, ending the line before the `>` opens
  anything.

## [2026.01.27] - Initial Release

- Portable Bitcoin Core and Electrum setup for macOS and Windows.
- Cross-platform launchers (root launchers + per-network scripts).
- Regtest multi-node setups (Alice/Bob/Carol) with clean-start variants.
- Update, verify, rollback, and validation utilities for both OSes.
- Checksums and PGP verification support in update workflows.
- Health checks, log rotation, and monitoring scripts.
