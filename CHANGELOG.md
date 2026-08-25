# Changelog

All notable changes to PortaNode will be documented in this file.

The format is based on [Calendar Versioning](https://calver.org/),
using YYYY.MM.DD format.

## [2026.01.29] - git main branch

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

## [2026.01.27] - Initial Release

- Portable Bitcoin Core and Electrum setup for macOS and Windows.
- Cross-platform launchers (root launchers + per-network scripts).
- Regtest multi-node setups (Alice/Bob/Carol) with clean-start variants.
- Update, verify, rollback, and validation utilities for both OSes.
- Checksums and PGP verification support in update workflows.
- Health checks, log rotation, and monitoring scripts.
