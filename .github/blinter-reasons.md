# Why the accepted Blinter Warning findings are no defect

`.github/blinter-baseline.json` accepts each Blinter finding that is no
defect. This file says why for the Warning rules, one section per rule,
its heading starting with the rule code. `.pre-commit-config.yaml`'s
header says why for the Error and Security rules.
`.github/workflows/script-security.yml`'s header says how the job holds
the two files to each other.

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
