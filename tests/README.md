# Tests

The suite runs the launchers and their helpers on the machine in front of
it, with nothing to install: `bash` on macOS and Linux, PowerShell on
Windows. `CONTRIBUTING.md`'s last section says which workflows run it,
on which platforms and when.

```shell
bash tests/run.sh
```

```powershell
pwsh -NoProfile -File tests\run.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run.ps1
```

Each runner prints one line per case, `ok` or `not ok` and then what the
case checks, and exits 1 where any case failed or any test file exited
non-zero.

What the suite does not reach is a launcher starting Bitcoin Core or
Electrum: no binary is in the tree. A test that runs a launcher that far
gives it stand-ins that record the arguments they are given, as
`sh/bitcoin-launchers.sh` does for the macOS and Linux Bitcoin launchers
and `win/regtest-cli-command.ps1` for the Windows regtest CLI launchers.
CI runs the menus from each runner's checkout, on the platforms
`CONTRIBUTING.md`'s last section names.

## Coverage

`coverage.yml` measures what the suite runs, one share per language, each
read from one run:

- bash lines, by `tests/kcov.sh`, which runs `tests/run.sh` under `kcov` in
  a Debian container. It installs packages and adds a user, so it is not
  run on a developer's machine.
- `.ps1` statements, by `tests/statements.ps1`, which runs `tests/run.ps1`
  on a Windows runner over a copy of the checkout whose `.ps1` files outside
  `tests/` log each statement they run. It runs on a runner only. Its header
  says why it does not use Pester.

`.bat` is unmeasured, no tool counting a batch file's statements, and the
Windows job lists each `.bat` as unmeasured. Branches are measured in
neither language (btclib-org/portanode#784).

Each job fails where the suite fails, and where its share is under its
floor: the argument its last step in `coverage.yml` passes. A pull request
that raises a share raises that floor with it, to the whole percent at or
under the total its run printed. Each script cuts that total at two
decimals rather than rounding it, so it never reads above the share. That
edit to `coverage.yml` is what runs the workflow on the pull request.

## Adding a test

A test file holds the cases of one subject, a helper or a launcher:

- `tests/sh/<subject>.sh` for what macOS and Linux run. It sources
  `tests/lib.sh`, calls `check` once per case and ends with `finish`.
- `tests/win/<subject>.ps1` for what Windows runs. It dot-sources
  `tests/lib.ps1`, calls `Test-Same` or `Test-Contain` once per case and
  ends with `Complete-Test`.

The runners pick up every file in those directories.
`tests/sh/resolve-root.sh` and `tests/win/resolve-root.ps1` are the model
to copy.

A new `tests/win/` file that starts `cmd.exe` is added to `$needsCmd` in
`test.yml`.

A file under `tests/sh/` carries the guard the `run-by-path-guard` hook
asks of every `.sh`, and neither a shebang nor the executable bit: it is
run by `bash`, never started by its path.

A case sets up what it needs in a temporary directory and leaves nothing
behind, the checkout included.
`win/regtest-cli-command.ps1` also sets a registry value, which its header
names, and restores it; other consoles opened meanwhile follow that value.
