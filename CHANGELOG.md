<!-- markdownlint-disable MD022 MD032 -->
<!-- This file is merge=union, so a rebase joins two sections and drops
     the blank line between them without a conflict: the rule is off
     here for the duration of btclib-org/.github#33, and goes back on
     when that queue is empty. btclib-org/.github#138 is the record. -->

# Changelog

All notable changes to PortaNode will be documented in this file.

The format is based on [Calendar Versioning](https://calver.org/),
using YYYY.MM.DD format.

## [2026.01.29] - git main branch

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

## [2026.01.27] - Initial Release

- Portable Bitcoin Core and Electrum setup for macOS and Windows.
- Cross-platform launchers (root launchers + per-network scripts).
- Regtest multi-node setups (Alice/Bob/Carol) with clean-start variants.
- Update, verify, rollback, and validation utilities for both OSes.
- Checksums and PGP verification support in update workflows.
- Health checks, log rotation, and monitoring scripts.
