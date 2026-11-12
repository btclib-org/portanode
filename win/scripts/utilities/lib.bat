@echo off
REM Copyright (c) The btclib developers
REM Distributed under the MIT software license, see the accompanying
REM LICENSE file or https://opensource.org/license/mit for the full text.

REM Shared helpers for Windows utility scripts.

set "ACTION=%~1"
if "%ACTION%"=="" goto :eof
shift /1
goto %ACTION%

REM :verify_pgp_signature SIG DATA LABEL KEYRING MIN
REM Fails CLOSED (exit /b 1) unless SIG carries good signatures from MIN
REM distinct keys of KEYRING, the rule shared/utilities/lib.sh's
REM pgp_verify_or_fail states. gpg runs in a home of its own, made empty for
REM the call in SIG's folder, with KEYRING copied in as its only keyring, so
REM it reads no option, key or trust setting of the user's, as that
REM function's comment says, and --batch is not passed, for the reason it
REM gives. The updaters download into a folder of their own, made fresh, and
REM remove it with what they downloaded, the home included. mkdir has to
REM make the home, so a folder already there under that name is not used.
REM Each updater verifies once in its folder. A second call in the same
REM folder can draw the name of the first one's home and is then refused,
REM as os-windows.yml run 43343570008 measured.
REM gpg is started from inside that home, which it is given as ".", and finds
REM the keyring by a name without a slash, which it reads as a file of that
REM home. Git for Windows' gpg is an MSYS program and wants a home written
REM as /c/..., as #806 says, so no path to the home or the keyring is
REM written out for it. cmd.exe looks for a command in the current folder
REM before PATH, so gpg is looked up before the folder changes, from the
REM folder the caller runs in, and started by the path found.
REM Written flat (no %var% set-and-read inside a ( ) block) because a
REM read of that shape inside one answers with the value the variable
REM held when cmd.exe parsed the block. Delayed expansion is the other
REM way of fixing that, and lib.bat cannot turn it on for itself: the
REM local scoping it comes with would confine the variables its labels
REM set for their callers, :installed_version's OUTVAR among them.
REM Written flat, neither GPG_HOME nor the caller's own SIG_FILE and
REM DATA_FILE needs it -- each is read at a line that runs after the line
REM setting it -- and the callers reach this label with delayed expansion
REM disabled, which is what lets a "!" in TEMP or in the mount path survive
REM as far as here (#393, #411). The construct is named rather than
REM spelled, because spelled out it reads to the batch linter as this file
REM asking for what the paragraph forbids, and it then prints that advice
REM against exit points throughout the file.
REM GPG_HOME is built on SIG's folder, which the updaters build on TEMP, and
REM TEMP is the caller's to set, not this file's: an account name or a
REM redirected TEMP holding an unmatched "!" is legal on Windows. It is read
REM with "%...%" because every caller reaches this label with delayed
REM expansion disabled, which is what leaves the character standing: with it
REM on, the pass that would substitute a "!VAR!" strips an unmatched "!" out
REM of what "%TEMP%" expanded to (#393). A "!" in the mount path is a
REM separate source with a separate owner, and it is stripped a second time
REM out of the caller's own "call" line, which is #411 and is measured at
REM update-bitcoin.bat's comment on its own second line. Neither source
REM implies the other: a plain mount path with a bangy TEMP reaches this
REM label with a working call target. The state at each call is checked by a
REM hook in .pre-commit-config.yaml (#448).
:verify_pgp_signature
set "SIG_FILE=%~1"
set "DATA_FILE=%~2"
set "LABEL=%~3"
set "KEYRING=%~4"
set "MIN_SIGS=%~5"
set "KEYRING_NAME=%~nx4"

set "GPG_HOME=%~dp1gpg-home-%RANDOM%%RANDOM%"

set "GPG_EXE="
for /f "delims=" %%G in ('where gpg 2^>nul') do if not defined GPG_EXE set "GPG_EXE=%%G"
if not defined GPG_EXE (
    echo Error: gpg not found; cannot verify %LABEL%.
    echo Install gpg.
    exit /b 1
)
call :keyring_is_readable "%%KEYRING%%"
if errorlevel 1 (
    echo Error: %KEYRING_NAME% is missing, empty or unreadable, so %LABEL% is
    echo refused.
    exit /b 1
)

echo Verifying %LABEL% signature...
mkdir "%GPG_HOME%" >nul 2>&1
if errorlevel 1 goto :verify_pgp_no_home
copy /b /y "%KEYRING%" "%GPG_HOME%\keys.gpg" >nul 2>&1
if errorlevel 1 goto :verify_pgp_no_home
set "STATUS_FILE=%GPG_HOME%\status.txt"
pushd "%GPG_HOME%"
"%GPG_EXE%" --homedir . --no-default-keyring --keyring keys.gpg --status-fd 1 ^
    --verify "%SIG_FILE%" "%DATA_FILE%" 1> "%STATUS_FILE%" 2>nul
popd
call :pgp_read_status
exit /b %errorlevel%

:verify_pgp_no_home
echo Error: no folder could be made for gpg to verify %LABEL% in; whether
echo the signature is good is unknown.
exit /b 1

REM :pgp_read_status
REM Reads the status lines gpg wrote to STATUS_FILE for
REM :verify_pgp_signature, and exits 0 where they hold good signatures from
REM MIN_SIGS distinct keys, as shared/utilities/lib.sh's pgp_read_status
REM does.
REM A status file that is absent or empty is gpg's answer lost rather
REM than a signature refused, and the searches below cannot separate
REM the two: where cmd.exe cannot open the file, a search answers the 1
REM that "cmd /d /c exit 1" set, as it does on a file holding no NEWSIG.
REM The exit code of gpg's line separates them the wrong way round, so it
REM is not read at all: a redirection cmd.exe cannot open leaves
REM errorlevel 0, which is what a good signature leaves, where a bad
REM signature leaves 1 and a key not in the keyring leaves 2.
REM The test is on size rather than existence, an empty file answering
REM no more than a missing one; no case measured here separates the
REM two. The message names the absence rather than a cause, several
REM reaching it alike.
:pgp_read_status
set "STATUS_OK=0"
if exist "%STATUS_FILE%" for %%S in ("%STATUS_FILE%") do if %%~zS GTR 0 set "STATUS_OK=1"
if "%STATUS_OK%"=="0" (
    echo Error: gpg's status output for %LABEL% was not read; whether the
    echo signature is good is unknown.
    exit /b 1
)

REM Each search below reads the status file from standard input and follows
REM "cmd /d /c exit 1", for the reason win/scripts/electrum/lib.bat gives.
REM %TEMP% follows the account name, so the file can sit under a letter
REM outside the ANSI code page. Measured on windows-latest, with gpg 2.4.9
REM writing the file under such a folder, cmd.exe opens it and findstr finds
REM GOODSIG in it.
cmd /d /c exit 1
findstr /c:"[GNUPG:] BADSIG" < "%STATUS_FILE%" >nul 2>&1
if %errorlevel%==0 (
    echo Error: BAD PGP signature on %LABEL%.
    exit /b 1
)

REM gpg's own doc/DETAILS gives NEWSIG as issued right before a
REM signature verification starts, so a status file holding none is
REM gpg reporting that it never reached one.
REM The GOODSIG test below cannot separate that from a signature
REM gpg read and could not validate, and names the keyring for both.
REM DETAILS says under GOODSIG that the per-signature codes "were
REM used as a marker for a new signature; new code should use the
REM NEWSIG status instead", so the dependence is the one upstream
REM asks for; nothing in this tree states a minimum gpg, and the
REM oldest measured against it is 2.4.4.
REM gpg's own exit status does not separate them either: a key that
REM is not in the keyring and a signature file that cannot be opened both
REM leave errorlevel 2. Nor does the FAILURE line, which reads
REM "verify" for a signature file that is missing or empty and
REM "gpg-exit" for one holding something that is not a signature and
REM for a file to check that is missing; a test on it would leave
REM those last two on the keyring message.
REM Measured with gpg 2.4.9 on windows-latest: NEWSIG is present for
REM a good signature, for a tampered one and for a key that is not
REM imported, and absent where the signature file is missing, empty
REM or not a signature and where the file it signs is missing. A file
REM the account is denied by ACL is not among them: icacls granting
REM the runner no access at all left gpg reading it, so an unreadable
REM file is measured on the POSIX half alone.
REM The message names what gpg did not do rather than a cause,
REM several reaching it alike. A signature file that is present and
REM readable and merely not a signature is one of them -- the shape a
REM download answering 200 with an error page leaves -- so advice to
REM check presence and readability would send that reader to confirm two
REM things already true.
cmd /d /c exit 1
findstr /c:"[GNUPG:] NEWSIG" < "%STATUS_FILE%" >nul 2>&1
if not %errorlevel%==0 (
    echo Error: gpg found no PGP signature to check on %LABEL%.
    echo Check the signature file and the file it signs.
    exit /b 1
)

REM The status file is counted by pgp_read_status's rule, as that
REM function's comment states, and MIN_SIGS read as pgp_verify_or_fail
REM reads its MIN. A PowerShell that exits non-zero for any reason,
REM including not running at all, refuses. The catch makes an error that
REM does not stop the block one of those reasons.
REM The powershell argument below is one physical line for the reason
REM :update_checksum's comment gives. The values reach PowerShell through
REM the environment, for the reason :install_verified's comment gives.
powershell -NoProfile -Command "& { try { $min = $env:MIN_SIGS; if ($min -cnotmatch '^[1-9][0-9]{0,8}$') { Write-Output ('Error: ' + $min + ' is not a number of signatures to ask for, so ' + $env:LABEL + ' is refused.'); exit 1 }; $sigs = New-Object System.Collections.ArrayList; $anyGood = $false; foreach ($line in [IO.File]::ReadAllLines($env:STATUS_FILE)) { $w = $line.Split(' '); if ($w.Count -lt 2 -or $w[0] -cne '[GNUPG:]') { continue }; if ($w[1] -ceq 'NEWSIG') { [void]$sigs.Add(@{ goods = 0; valids = 0; revoked = $false; gid = ''; sfpr = ''; hash = ''; primary = ''; errs = 0; errhash = ''; errrc = '' }); continue }; if ($w[1] -ceq 'GOODSIG') { $anyGood = $true }; if ($sigs.Count -eq 0) { continue }; $s = $sigs[$sigs.Count - 1]; if ($w[1] -ceq 'GOODSIG') { $s['goods'] += 1; $s['gid'] = $w[2].ToUpperInvariant() } elseif ($w[1] -ceq 'VALIDSIG') { $s['valids'] += 1; $s['sfpr'] = $w[2].ToUpperInvariant(); if ($w.Count -gt 9) { $s['hash'] = $w[9] }; if ($w.Count -gt 11) { $s['primary'] = $w[11].ToUpperInvariant() } } elseif ($w[1] -ceq 'ERRSIG') { $s['errs'] += 1; if ($w.Count -gt 7) { $s['errhash'] = $w[4]; $s['errrc'] = $w[7] } } elseif ($w[1] -ceq 'REVKEYSIG' -or $w[1] -ceq 'KEYREVOKED') { $s['revoked'] = $true } }; $counted = @{}; $weak = 0; foreach ($s in $sigs) { if ($s['errs'] -eq 1 -and $s['goods'] -eq 0 -and $s['valids'] -eq 0 -and $s['errhash'] -cmatch '^0*[1-3]$' -and $s['errrc'] -cne '9') { $weak += 1; continue }; if ($s['goods'] -eq 1 -and $s['valids'] -eq 1 -and -not $s['revoked'] -and $s['gid'].Length -ge 16 -and $s['sfpr'].EndsWith($s['gid'], [StringComparison]::Ordinal) -and ($s['primary'].Length -eq 40 -or $s['primary'].Length -eq 64) -and $s['primary'] -cmatch '^[0-9A-F]+$' -and $s['hash'] -cmatch '^[0-9]+$') { if ($s['hash'] -cnotmatch '^0*[0-3]$') { $counted[$s['primary']] = $true } elseif ($s['hash'] -cmatch '^0*[1-3]$') { $weak += 1 } } }; $weakMsg = [string]$weak + ' signature(s) on ' + $env:LABEL + ' use MD5, SHA-1 or RIPEMD-160, a weak hash, and do not count.'; if (-not $anyGood) { Write-Output ('Error: no PGP signature on ' + $env:LABEL + ' verifies against a key in ' + $env:KEYRING_NAME + '.'); if ($weak -gt 0) { Write-Output $weakMsg }; exit 1 }; if ($counted.Count -lt [int]$min) { Write-Output ('Error: ' + $env:LABEL + ' carries good signatures from ' + $counted.Count + ' key(s) in ' + $env:KEYRING_NAME + '; it asks for ' + $min + '.'); if ($weak -gt 0) { Write-Output $weakMsg }; Write-Output 'A key counts once, and not at all where it is expired or revoked.'; exit 1 }; Write-Output ($env:LABEL + ': good signatures from ' + $counted.Count + ' key(s) in ' + $env:KEYRING_NAME + '; ' + $min + ' required.') } catch { Write-Output ('Error: ' + $_.Exception.Message); exit 1 }; exit 0 }"
if not %errorlevel%==0 (
    echo Error: %LABEL% is refused.
    exit /b 1
)
exit /b 0

REM :keyring_is_readable KEYRING
REM Exits 0 where KEYRING names a file holding at least one byte, as
REM shared/utilities/lib.sh's keyring_is_readable does. A path that ends
REM in "\" exists only where it names a folder. A file the account cannot
REM read passes here, and :verify_pgp_signature refuses it when its copy
REM fails.
:keyring_is_readable
set "KIR_FILE=%~1"
set "KIR_SIZE="
if "%KIR_FILE%"=="" exit /b 1
if not exist "%KIR_FILE%" exit /b 1
if exist "%KIR_FILE%\" exit /b 1
for %%K in ("%KIR_FILE%") do set "KIR_SIZE=%%~zK"
if "%KIR_SIZE%"=="" exit /b 1
if "%KIR_SIZE%"=="0" exit /b 1
exit /b 0

REM :preview_keyring KEYRING NAME WHAT MIN
REM For an updater's --dry-run, with gpg found: prints what
REM :verify_pgp_signature would make of KEYRING before any signature is
REM read, as shared/utilities/lib.sh's preview_keyring does. NAME is the
REM keyring as the user knows it and WHAT is what a refusal would stop.
REM Always exits 0: a preview reports and does not end the run.
:preview_keyring
set "PK_NAME=%~2"
set "PK_WHAT=%~3"
set "PK_MIN=%~4"
call :keyring_is_readable "%~1"
if errorlevel 1 goto :preview_keyring_refused
echo gpg: found. Verification asks for %PK_MIN% good signature(s) from
echo distinct keys in %PK_NAME%.
exit /b 0

:preview_keyring_refused
echo gpg: found, but %PK_NAME% is missing, empty or unreadable --
echo verification would refuse %PK_WHAT%.
exit /b 0

REM :update_checksum FILE ENTRY_PATH VERSION
REM Appends FILE's hash to CHECKSUM_FILE under ENTRY_PATH. The updaters
REM pass the verified file they install from, not the copy under
REM win\bin, and then check that copy against the entry: an entry hashed
REM from the copy records whatever the write left there, and the check
REM then compares the copy with itself (#568). Every value reaches
REM PowerShell through the environment, for the reason
REM :install_verified's comment gives.
:update_checksum
set "FILEPATH_RAW=%~1"
set "ENTRY_RAW=%~2"
set "VERSION_LABEL=%~3"
call :normalize_fs_path "%%FILEPATH_RAW%%" FILEPATH_FS
call :normalize_entry_path "%%ENTRY_RAW%%" FILEPATH_ENTRY
if not exist "%FILEPATH_FS%" exit /b 0
if "%CHECKSUM_FILE%"=="" exit /b 0
REM Appends the one new entry with Add-Content rather than rewriting the file
REM with Set-Content, as README.md's *Checksums* says: an updater never
REM rewrites an entry. A rewrite of every line on each call -- and
REM Select-Object -Unique silently dropping any repeated one, comments
REM included -- is what Add-Content avoids.
REM Measured on windows-latest (#144): a "^" at end of line continues a
REM batch file's line only while cmd's quote state is closed at that point;
REM inside the double-quoted -Command argument below, "^" is a literal
REM character rather than a continuation, which is why that argument is
REM one physical line. $entry is built
REM with single-quoted concatenation rather than a double-quoted
REM interpolated string: measured on windows-latest, a double quote nested
REM inside the one that already wraps this whole -Command argument is not
REM passed through to powershell.exe -- it is consumed while the argument
REM is split into argv, along with the space either side of it, turning
REM "$hash  ...  $version" into three bare, unquoted tokens and a parse
REM error. Every other quoted PowerShell string in this file is already
REM single-quoted for the same reason.
REM "-not" rather than PowerShell's own negation operator, which is
REM the character cmd.exe's delayed-expansion pass consumes:
REM "!(Test-Path $checksum)" would reach PowerShell as
REM "(Test-Path $checksum)", the test inverted, wherever delayed
REM expansion is on (#360). "-not" carries nothing for cmd.exe's
REM parser to strip under either state, so this line holds whichever
REM one a caller leaves (#374, #411).
REM Get-FileHash's own failure is non-terminating, returning nothing so
REM ".Hash" on that empty result is $null and it is ".ToLower()" -- a
REM method call on that $null -- that throws "You cannot call a method
REM on a null-valued expression": that is the unreadable-file arm. The
REM cmdlet itself failing to resolve (Windows PowerShell 5.1 failing to
REM autoload Microsoft.PowerShell.Utility, #420) raises instead, at
REM command resolution, before ".Hash" is ever reached. Neither throw
REM aborts more than the one assignment, so without a guard $hash stays
REM unset either way, coerces to an empty string in $entry, and
REM Add-Content still appends an entry whose hash field is empty, which
REM no updater then rewrites. $fh is checked before ".Hash" is read, so
REM either failure leaves it unset and exits 1 with nothing appended.
REM :verify_checksum and :installed_version below test the same way.
powershell -NoProfile -Command "& { $file = $env:FILEPATH_FS; $version = $env:VERSION_LABEL; $checksum = $env:CHECKSUM_FILE; if (-not (Test-Path -LiteralPath $checksum)) { Write-Host 'Warning: win/checksums.sha256 not found; skipping.'; exit 0 } $fh = Get-FileHash -Algorithm SHA256 -LiteralPath $file; if (-not $fh) { Write-Host ('Error: could not hash the source of ' + $env:FILEPATH_ENTRY + '; not appending to win/checksums.sha256.'); exit 1 } $hash = $fh.Hash.ToLower(); $entry = $hash + '  ' + $env:FILEPATH_ENTRY + '  version=' + $version; $existing = Get-Content -LiteralPath $checksum; if ($existing -notcontains $entry) { Add-Content -Encoding ASCII -LiteralPath $checksum -Value $entry } }"
if errorlevel 1 exit /b 1
exit /b 0

:verify_checksum
set "FILEPATH_RAW=%~1"
set "CHECKPATH_RAW=%~2"
call :normalize_fs_path "%%FILEPATH_RAW%%" FILEPATH_FS
call :normalize_entry_path "%%CHECKPATH_RAW%%" CHECKPATH_ENTRY
REM A relative FILE is taken against ROOTDIR, not against the current
REM directory, which the updaters keep outside the folder (#656).
if not "%FILEPATH_FS:~1,1%"==":" if not "%FILEPATH_FS:~0,1%"=="\" set "FILEPATH_FS=%ROOTDIR%\%FILEPATH_FS%"
REM Fails CLOSED on a missing file, converging on
REM shared/utilities/lib.sh's verify_checksum_entry, which returns
REM non-zero on the same case.
if exist "%FILEPATH_FS%" goto :verify_checksum_found
call :rootdir_relative "%%FILEPATH_FS%%" FILEPATH_REL
echo Error: %FILEPATH_REL% not found.
exit /b 1

:verify_checksum_found
if "%CHECKSUM_FILE%"=="" exit /b 1
call :rootdir_relative "%%FILEPATH_FS%%" FILEPATH_REL
REM Built as one physical line: see :update_checksum's comment above on
REM why a "^" split across this block's open quote is not a continuation.
REM "-not" rather than "!" for the reason :update_checksum's comment
REM above gives. Values reach PowerShell as $env: reads, for the reason
REM :install_verified's comment below gives.
REM A file Get-FileHash cannot read is refused by name, as
REM :update_checksum refuses it (#652). A line matches where its first
REM field is the hash and its second the entry path, each compared whole,
REM as shared/utilities/lib.sh's verify_checksum_entry compares them: a
REM substring test reads a line as naming any path its own text holds
REM (#657). The path is compared without regard to case, as Windows
REM resolves one. '\s+' carries one backslash, for the reason
REM latest-electrum-version.ps1's header gives.
powershell -NoProfile -Command "& { $path = $env:CHECKPATH_ENTRY; $checksum = $env:CHECKSUM_FILE; if (-not (Test-Path -LiteralPath $checksum)) { exit 1 } $fh = Get-FileHash -Algorithm SHA256 -LiteralPath $env:FILEPATH_FS; if (-not $fh) { Write-Host ('Error: could not hash ' + $env:FILEPATH_REL + '.'); exit 1 } $found = $false; foreach ($l in (Get-Content -LiteralPath $checksum)) { $w = $l.Trim() -split '\s+'; if ($w.Count -ge 2 -and $w[0] -ieq $fh.Hash -and $w[1].Replace('\','/') -ieq $path) { $found = $true; break } } if (-not $found) { exit 1 } }"
if errorlevel 1 exit /b 1
exit /b 0

REM :install_verified SRC DEST
REM Copies SRC over DEST, reads DEST back and compares its SHA-256 with
REM SRC's, copying again on a mismatch and failing once every attempt
REM has mismatched: shared/utilities/lib.sh's install_verified, for the
REM same removable volume. A DEST that cannot be hashed counts as a
REM mismatch. A copy that fails outright is reported and not retried,
REM being an error the copy itself raises rather than a silent one.
REM One physical line, for the reason :update_checksum's comment gives.
REM The paths reach PowerShell through the environment, as
REM :pgp_read_status's STATUS_FILE does, rather than spliced
REM between single quotes in the command text: a path holding an
REM apostrophe ends such a string early, and PowerShell then refuses the
REM whole command as a parse error (#578). Where a cmdlet takes
REM -LiteralPath the path goes there, so a "[" in it is not read as a
REM wildcard. The other calls that hand PowerShell a value this way
REM point here.
:install_verified
set "INS_SRC=%~1"
set "INS_DEST=%~2"
powershell -NoProfile -Command "& { $src = $env:INS_SRC; $dest = $env:INS_DEST; $name = Split-Path -Leaf $dest; $want = Get-FileHash -Algorithm SHA256 -LiteralPath $src; if (-not $want) { Write-Host ('Error: cannot hash the source of ' + $name + '.'); exit 1 } foreach ($i in 1..5) { try { Copy-Item -LiteralPath $src -Destination $dest -Force -ErrorAction Stop } catch { Write-Host ('Error: copying ' + $name + ' failed: ' + $_.Exception.Message); exit 1 } $got = Get-FileHash -Algorithm SHA256 -LiteralPath $dest -ErrorAction SilentlyContinue; if ($got -and $got.Hash -eq $want.Hash) { exit 0 } Write-Host ('Warning: ' + $name + ' corrupted on write (attempt ' + $i + '/5); retrying...') } Write-Host ('Error: ' + $name + ' still corrupt after 5 attempts.'); Write-Host 'The destination filesystem may be unreliable.'; exit 1 }"
if errorlevel 1 exit /b 1
exit /b 0

REM :installed_version FILE ENTRY_PATH CHECKSUM_FILE OUTVAR
REM Sets OUTVAR to the "version=" label of the checksum entry matching
REM FILE's current hash, or "unknown". It never fails the caller. Its
REM answer is a --dry-run plan's "currently installed" line, a
REM rollback's version lines, and what compare-versions.ps1 compares
REM before an update: "unknown" there
REM means no version is refused as older.
:installed_version
set "IV_FILE_RAW=%~1"
set "IV_ENTRY_RAW=%~2"
set "IV_CHECKSUM=%~3"
set "IV_OUTVAR=%~4"
call :normalize_fs_path "%%IV_FILE_RAW%%" IV_FILE_FS
call :normalize_entry_path "%%IV_ENTRY_RAW%%" IV_ENTRY_ENTRY
set "%IV_OUTVAR%=unknown"
if not exist "%IV_FILE_FS%" exit /b 0
if not exist "%IV_CHECKSUM%" exit /b 0
REM Built as one physical line: see :update_checksum's comment above on
REM why a "^" split across this block's open quote is not a continuation.
REM Values reach PowerShell as $env: reads, for the reason
REM :install_verified's comment above gives. The entry is matched as
REM :verify_checksum matches it, its '\s+' included, and a file
REM Get-FileHash cannot read leaves OUTVAR "unknown".
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "& { $fh = Get-FileHash -Algorithm SHA256 -LiteralPath $env:IV_FILE_FS -ErrorAction SilentlyContinue; if (-not $fh) { exit 0 } foreach ($l in (Get-Content -LiteralPath $env:IV_CHECKSUM)) { $w = $l.Trim() -split '\s+'; if ($w.Count -ge 2 -and $w[0] -ieq $fh.Hash -and $w[1].Replace('\','/') -ieq $env:IV_ENTRY_ENTRY) { if ($l -match 'version=(\S+)') { Write-Output $matches[1] } break } } }"`) do set "%IV_OUTVAR%=%%V"
exit /b 0

REM :rootdir_relative PATH OUTVAR
REM PATH with the ROOTDIR prefix removed, for a message: the folder is
REM mounted at a different point on every machine it is plugged into, so a
REM message quoting the mount point tells the reader where this run
REM happened rather than which file in the folder is meant. A path outside
REM the folder carries no such prefix and comes back unchanged, and so
REM does every path where ROOTDIR is unset.
REM
REM The prefix is cut by its length, and no path is in a call's arguments
REM before the call's own parse: a "call" doubles each "^" in its
REM arguments, as win\scripts\root.bat says at its head, so a pattern
REM built from ROOTDIR there matches no path whose folder holds one
REM (#892). The loop counts the characters of ROOTDIR and its separator
REM one "call set" at a time, only the count reaching a call's arguments
REM before their second parse. The "if /i" before the last "call" compares
REM the two paths outside that call's arguments, where no "^" is doubled,
REM and ignores case.
:rootdir_relative
set "RR_PATH=%~1"
set "RR_OUTVAR=%~2"
if not defined ROOTDIR goto :rootdir_relative_done
if not defined RR_PATH goto :rootdir_relative_done
set "RR_ROOT=%ROOTDIR%\"
if "%ROOTDIR:~-1%"=="\" set "RR_ROOT=%ROOTDIR%"
set "RR_LEN=0"

:rootdir_relative_count
call set "RR_CHAR=%%RR_ROOT:~%RR_LEN%,1%%"
if defined RR_CHAR (
    set /a "RR_LEN+=1"
    goto :rootdir_relative_count
)
call set "RR_HEAD=%%RR_PATH:~0,%RR_LEN%%%"
if /i "%RR_HEAD%"=="%RR_ROOT%" call set "RR_PATH=%%RR_PATH:~%RR_LEN%%%"

:rootdir_relative_done
set "%RR_OUTVAR%=%RR_PATH%"
exit /b 0

REM :refuse_while_running <name> <doing> <image>
REM Returns 0 where tasklist answers that no process runs <image>. Otherwise
REM returns 1 with a message: one does, or tasklist is missing or failed, and
REM then nothing says that <name> is stopped. <doing> is what the caller is
REM about to do, as "updating". One run of tasklist gives both answers: the
REM line that follows it only where it exits 0 is the proof a listing was
REM read, and a pipe into find could not give that, its status being find's.
:refuse_while_running
set "GUARD_NAME=%~1"
set "GUARD_DOING=%~2"
set "GUARD_LISTED="
set "GUARD_FOUND="
for /f "tokens=1 delims= " %%L in ('tasklist /nh /fi "imagename eq %~3" 2^>nul ^&^& echo portanode-listed') do (
    if "%%L"=="portanode-listed" set "GUARD_LISTED=1"
    if /i "%%L"=="%~3" set "GUARD_FOUND=1"
)
if defined GUARD_FOUND (
    echo Error: %GUARD_NAME% is running. Stop it before %GUARD_DOING%.
    exit /b 1
)
if defined GUARD_LISTED exit /b 0
echo Error: cannot tell whether %GUARD_NAME% is running: tasklist is missing or failed. Not %GUARD_DOING%.
exit /b 1

REM :normalize_fs_path PATH OUTVAR
REM Sets OUTVAR to PATH with each / turned into \, the form a Windows
REM path takes.
:normalize_fs_path
set "RAW=%~1"
set "OUTVAR=%~2"
set "VAL=%RAW:/=\%"
set "%OUTVAR%=%VAL%"
exit /b 0

REM :normalize_entry_path PATH OUTVAR
REM Sets OUTVAR to PATH with each \ turned into /, the form
REM CHECKSUM_FILE's entries take.
:normalize_entry_path
set "RAW=%~1"
set "OUTVAR=%~2"
set "VAL=%RAW:\=/%"
set "%OUTVAR%=%VAL%"
exit /b 0
