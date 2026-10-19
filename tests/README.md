# Tests

The suite runs the launchers and their helpers on the machine in front of
it, with nothing to install: `bash` on macOS and Linux, PowerShell on
Windows. `.github/workflows/tests.yml` runs it on every pull request, on
Linux, macOS and Windows.

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
Electrum: no binary is in the tree. On Windows, CI runs the menus from a
checkout on `D:`, with Windows on `C:`; on macOS and Linux it runs them
from the runner's home directory.

## Adding a test

A test file holds the cases of one subject, a helper or a launcher:

- `tests/sh/<subject>.sh` for what macOS and Linux run. It sources
  `tests/lib.sh`, calls `check` once per case and ends with `finish`.
- `tests/win/<subject>.ps1` for what Windows runs. It dot-sources
  `tests/lib.ps1`, calls `Test-Same` or `Test-Contain` once per case and
  ends with `Complete-Test`.

The runners pick up every file in those directories, and the files already
there are the model to copy.

A file under `tests/sh/` carries the guard the `run-by-path-guard` hook
asks of every `.sh`, and neither a shebang nor the executable bit: it is
run by `bash`, never started by its path.

A case sets up what it needs in a temporary directory and leaves nothing
behind, the checkout included.
