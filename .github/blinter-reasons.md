# Why the accepted Blinter Warning findings are no defect

`.github/blinter-baseline.json` accepts each Blinter finding that is no
defect. This file says why for the Warning rules, one section per rule,
its heading starting with the rule code. `.pre-commit-config.yaml`'s
header says why for the Error and Security rules.
`.github/workflows/script-security.yml`'s header says how the job holds
the two files to each other.

A finding that is Blinter's defect rather than the script's is accepted
in the baseline and reported upstream. It is first filed in this
repository as an `upstream-report` issue, as `btclib-common.md`'s
[*Collateral*](https://github.com/btclib-org/claude-process/blob/main/process/btclib-common.md#collateral)
says.

## E006 Potentially undefined variable reference

Blinter counts a variable as defined only where a `set` in its own file
names it.
Each accepted `E006` has one of these shapes:

- **A `call` earlier in the file sets the variable.** The called label
  takes the variable's name as its last argument and sets it by name,
  with `set "%<name>%=..."`. None of these labels opens a scope of its own,
  so the value reaches the caller. `:resolve_root` in
  `win\scripts\root.bat` sets `ROOTDIR` this way, and each caller tests
  `errorlevel` on the next line and stops on a failure.
  `:installed_version`, `:rootdir_relative` and `:normalize_fs_path` in
  `win\scripts\utilities\lib.bat` set theirs the same way.
- **A `lib.bat` label reads a variable its caller sets.** Every caller of
  `win\scripts\bitcoin\lib.bat` resolves `ROOTDIR` before its first call.
  `win\scripts\utilities\lib.bat` tests `CHECKSUM_FILE` for an empty value
  before it uses it.
- **`root.bat` reads `PORTANODE_ROOT` only inside
  `if defined PORTANODE_ROOT`.** The variable is the user's own setting.
- **The line is a `REM` comment.** Blinter reads its prose as code.

## W001 Missing exit code

Each accepted `W001` has one of these shapes:

- **A launch script runs to its end.** The launch scripts under
  `win\scripts\bitcoin` and `win\scripts\electrum` hold no label and no
  `goto`, and their last command is `start`. They return `start`'s
  status, which the root launcher's `if errorlevel 1` reads.
- **The script ends on `exit /b 0`.** In `health-check.bat` and
  `validate-setup.bat`, Blinter reads that `exit` as inside a block, for
  the reason `W068` gives. With those `for /f` lines joined, Blinter
  reports no `W001` on either.

## W002 Missing ERRORLEVEL check

Blinter looks for `errorlevel` or `if not` on the command's line and the
three lines after it. Each accepted `W002` has one of these shapes:

- **A `powershell` line ends in `|| goto :error`.** These are downloads
  in `update-bitcoin.bat` and `update-electrum.bat`, and the checksum
  test in `update-bitcoin.bat`.
- **`:warn_if_no_pubkeys` in `win\scripts\utilities\lib.bat` reads
  its answer from a file.** The file is emptied before `powershell`
  runs, and the label warns where the answer is empty.
- **A `del` removes a temporary file under `%TEMP%`.** These are in
  `win\scripts\utilities\lib.bat`, and their output goes to `nul`. A
  failed `del` leaves the file behind and changes nothing the label
  returns.

## W003 Operation without error handling

Blinter makes the test `W002` describes on `powershell` and on other
external commands. Every accepted `W003` is on a `powershell` line of
the first two shapes `W002` lists.

## W004 Potential infinite loop

Blinter reports a `goto` back to an earlier label unless a `set /a` or a
test of a shifted argument sits near it. Each loop here has an exit:

- `:menu` in the root `.bat` launchers exits on the entry `0`. `set /p`
  keeps the last entry on an empty line and at the end of input, so until
  [ISS 686](https://github.com/btclib-org/portanode/issues/686) is fixed,
  an entry other than `0` followed by the end of input repeats the menu
  without end. The finding stays after that fix.
- `:parse_args` in the updaters ends at the first empty `%~1`, and each
  pass that comes back to it has shifted one or two arguments.
- `:find_root` in `win\scripts\root.bat` ends at a root, or at a
  directory that is its own parent.

## W005 Unquoted variable with spaces

Blinter reports an `if` that compares a `%variable%` outside quotes.
Every accepted `W005` compares `%errorlevel%`, which cmd.exe expands to
the last exit code, a number with no space in it. A variable named
`ERRORLEVEL` would take its place, and no script in the tree sets one.

## W007 File operation on potentially locked file

Blinter reports a `copy`, `move`, `del` or `ren` whose line names an
`.exe`, among other paths. The accepted `W007` is the `move` in
`rollback-electrum.bat` that puts the backup back in `win\bin`. Where
the move fails, the `if errorlevel 1` on the next line reports it.
Nothing is deleted before it, so a failure leaves the installed version
in place.

## W009 Windows version compatibility

Blinter reports `where` as missing from older Windows. `README.md`
supports Windows 10 and later, and Microsoft's reference page for it
lists Windows 10 and Windows 11.

## W011 Unicode handling issue

Blinter reports a `findstr` line that holds `<` or `>`, and an `echo`
line whose redirection it does not read, such as `1>&2`. Each accepted
`W011` is a `findstr` whose output goes to `nul`, or the `echo ... 1>&2`
of `:resolve_root` in `win\scripts\root.bat`.

The findings are accepted for what Blinter's rule tests. Each of these
`findstr` lines reads its file on standard input, with `<`, for the reason
the comment in `win\scripts\electrum\lib.bat` gives.

## W014 Missing PAUSE for user interaction

Blinter asks for a `pause` in a script that reads `set /p` and holds no
`pause`, and reports its last line. Every accepted `W014` is the last
line of a root `.bat` launcher, the `exit /b 0` of `:end`. The menu
goes there only where the choice is `0`, which asks to close. The
launcher's one other exit, where `PORTANODE_ROOT` names no PortaNode
folder, waits first with `:pause_if_own_console`.

## W022 Missing SETLOCAL EnableDelayedExpansion

Blinter reads a `!name!` anywhere in a file as a use of delayed
expansion, comments included. The only `!name!` in
`win\scripts\utilities\lib.bat` is in a `REM` comment. The file opens no
scope of its own, since its labels run in their caller's.

## W023 Inefficient nested FOR loops

Blinter reads a `for` whose block opens within the twenty lines after
another `for` as nested in it. The accepted `W023` is the verification
loop in `update-bitcoin.bat`. The `for` before it ends on its own line,
so the loop is not nested.

## W025 Missing error handling

Blinter looks for `errorlevel`, or for `if` and a space, on the command's
line and the two lines after it. Each accepted `W025` has one of these shapes:

- **A `mkdir` of the download directory ends in
  `|| goto :tmpdir_failed`.** These are in `update-bitcoin.bat` and
  `update-electrum.bat`.
- **A `del` removes a temporary file under `%TEMP%`,** for the reason
  `W002` gives.

## W028 Errorlevel handling difference between .bat/.cmd

`set`, `path`, `append`, `dpath`, `ftype`, `assoc` and `prompt` set
`ERRORLEVEL` differently in a `.bat` file and in a `.cmd` file. Blinter
reports the first of these commands in each `.bat` file.

The difference matters only where `ERRORLEVEL` is read after one of these
commands, and no script here reads it there:

- each `errorlevel` test follows the command it tests, and none of those
  is one of these;
- no `exit /b` leaves out its code, and no script ends on one of these
  commands;
- a `goto :eof` that follows one of these commands is the return of a
  `lib.bat` or `root.bat` called with no label, and every call names one.

## W033 Command execution may be ambiguous

Blinter reads a `call` target as running up to the first space or colon.
A quoted target that holds neither keeps its closing quote, and so seems
to end without an extension. Every accepted `W033` calls a quoted path that ends
in `.bat`, or `"%SCRIPT%"` in a root `.bat` launcher, which sets `SCRIPT`
to the `.bat` path of a menu entry.

## W039 Nested FOR loops without call optimization

Blinter reports a nested `for` with no `call :label`. The accepted
`W039` is on the loop `W023` describes, which is not nested.

## W040 Nested FOR loop variable reuse

Blinter reports a nested `for` that reuses the outer loop's variable.
The accepted `W040` is on the loop `W023` describes, which is not
nested, so its `%%E` is its own.

## W052 SHIFT inside parenthesized block

A `shift` inside a block leaves `%1` in that block as it was. Each block
that shifts here reads its arguments before the `shift`, and then leaves
through `goto :parse_args`, which reads `%1` again on a line of its own.

## W061 Unbalanced PUSHD and POPD commands

Blinter pairs a `popd` only with a `pushd` written earlier in the same
file:

- The utilities other than the updaters change directory with
  `call root.bat :leave_folder`, and so do `:require_datadir_free` and
  `:require_no_mainnet_node` in `win\scripts\bitcoin\lib.bat` and
  `:require_non_portable_build` in `win\scripts\electrum\lib.bat`. The
  `pushd` of `:leave_folder` is in `root.bat`, and it is the one Blinter
  reports unmatched there.
- The updaters `pushd` once and `popd` on each path out, so Blinter
  matches the first `popd` only.

Every exit after the change of directory pops first, except the exit
taken where the change failed.

## W068 Percent expansion of a variable set in the same parenthesized block

Blinter's count of open parentheses stays raised after a `for /f` whose
`^` continues it on the next line, the shape `E010` reports. From there
it reads every later line as inside a block. With those `for /f` lines
joined, Blinter reports no `W068` here. No accepted `W068` reads, inside
a block, a variable that block sets.

## W071 Parse-time pseudo-variable inside a parenthesized block

The same miscount as `W068`'s. No accepted `W071` is inside a block.
