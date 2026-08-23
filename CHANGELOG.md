# Changelog

All notable changes to PortaNode will be documented in this file.

The format is based on [Calendar Versioning](https://calver.org/),
using YYYY.MM.DD format.

## [2026.01.29] - git main branch

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
- The markdown in the tree was brought to the shared markdownlint
  configuration: list indentation, blank lines around headings and lists,
  ordered-list prefixes and headings ending in a full stop. No wording
  changed. Trailing whitespace and missing final newlines were fixed in
  the `.bat` launchers, which keep their CRLF line endings — the
  line-ending hook excludes them for that reason.
- `.gitattributes` marks `CHANGELOG.md` and `RELEASE_NOTES.md`
  `merge=union`, so two branches each appending an entry no longer
  conflict on the insertion point.
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

## [2026.01.27] - Initial Release

- Portable Bitcoin Core and Electrum setup for macOS and Windows.
- Cross-platform launchers (root launchers + per-network scripts).
- Regtest multi-node setups (Alice/Bob/Carol) with clean-start variants.
- Update, verify, rollback, and validation utilities for both OSes.
- Checksums and PGP verification support in update workflows.
- Health checks, log rotation, and monitoring scripts.
