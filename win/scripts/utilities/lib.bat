@echo off
REM Shared helpers for Windows utility scripts.

set "ACTION=%~1"
if "%ACTION%"=="" goto :eof
shift
goto %ACTION%

REM :warn_if_no_pubkeys
REM Reports on the local keyring and never fails the caller: both
REM --dry-run, the side-effect-free preview, and :verify_pgp_signature
REM call it, and neither wants that question answered by an error.
REM Measured on windows-latest (#382), against the keyring directory
REM gpg creates on its own first run: a for /f over gpg piped into
REM findstr does not return, where the same listing redirected to a
REM file returns in about a second. The wait is the pipe rather than
REM gpg, so the listing goes to a file and nothing here reads a
REM running command's output.
REM The bound is Start-Process with WaitForExit, at the value the
REM archive-size request in the same --dry-run block passes as
REM -TimeoutSec 30, rather than a second number to defend. It covers
REM a gpg slow for its own reasons, which is not the case measured
REM above.
REM An empty answer file is not a keyring holding no key, so the two
REM print different warnings and neither ends the run: --dry-run
REM reaches its free-space line and exits 0 either way (#327, #336).
REM That warning names the absence rather than a cause, as the
REM archive-size line in the same block does and for the same reason:
REM the bound firing, a gpg that is not on PATH and a probe that could
REM not run all reach it alike.
REM The powershell argument below is one physical line for the reason
REM :update_checksum's comment gives.
REM WNP_ANSWER_FILE is TEMP-derived, and TEMP is the caller's to set,
REM not this file's: an account name or a redirected TEMP holding an
REM unmatched "!" is legal on Windows. It is read with "%...%"
REM because every caller reaches this label with delayed expansion
REM disabled, which is what leaves the character standing: with it
REM on, the pass that would substitute a "!VAR!" strips an
REM unmatched "!" out of what "%TEMP%" expanded to (#393). A "!"
REM in the mount path is a separate source with a separate owner,
REM and it is stripped a second time out of the caller's own
REM "call" line, which is #411 and is measured at
REM update-bitcoin.bat's comment on its own second line. Neither
REM source implies the other: a plain mount path with a bangy TEMP
REM reaches this label with a working call target. The state at
REM each call is checked by a hook in .pre-commit-config.yaml (#448).
:warn_if_no_pubkeys
set "WNP_ANSWER_FILE=%TEMP%\pn_pubkeys_%RANDOM%%RANDOM%.txt"
type nul > "%WNP_ANSWER_FILE%"
powershell -NoProfile -Command "& { $out = $env:WNP_ANSWER_FILE + '.out'; $err = $env:WNP_ANSWER_FILE + '.err'; $p = Start-Process -FilePath 'gpg' -ArgumentList '--batch','--list-keys','--with-colons' -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err; if ($p.WaitForExit(30000)) { $a = 'no'; if (Select-String -Path $out -Pattern '^pub' -Quiet) { $a = 'yes' }; Set-Content -Path $env:WNP_ANSWER_FILE -Value $a } else { $p.Kill() }; Remove-Item $out, $err -Force -ErrorAction SilentlyContinue }" >nul 2>&1
set "WNP_ANSWER="
set /p WNP_ANSWER=<"%WNP_ANSWER_FILE%"
del "%WNP_ANSWER_FILE%" >nul 2>&1
if "%WNP_ANSWER%"=="yes" exit /b 0
if "%WNP_ANSWER%"=="no" echo Warning: no public keys found in local keyring.
if "%WNP_ANSWER%"=="" (
    echo Warning: the local keyring was not read; whether a public key
    echo is imported is unknown.
)
exit /b 0

REM :verify_pgp_signature SIG DATA LABEL OUTVAR [FPR_FILE]
REM Fails CLOSED (exit /b 1) unless a good signature is found. If FPR_FILE has
REM any 40-hex fingerprint line, additionally requires a VALIDSIG from a listed
REM key (pinning). Set PORTANODE_ALLOW_UNVERIFIED=1 to bypass (NOT recommended).
REM Written flat (no %var% set-and-read inside a ( ) block) because a
REM read of that shape inside one answers with the value the variable
REM held when cmd.exe parsed the block. Delayed expansion is the other
REM way of fixing that, and lib.bat cannot turn it on for itself: the
REM local scoping it comes with would confine the OUTVAR this file sets
REM for its caller. Written flat, none of STATUS_FILE, FPR_CLEAN or
REM the caller's own SIG_FILE and DATA_FILE needs it -- each is read
REM at a line that runs after the line setting it -- and the callers
REM reach this label with delayed expansion disabled, which is what
REM lets a "!" in TEMP or in the mount path survive as far as here
REM (#393, #411). The construct is named rather than spelled, because
REM spelled out it reads to the batch linter as this file asking for
REM what the paragraph forbids, and it then prints that advice against
REM exit points throughout the file.
:verify_pgp_signature
set "SIG_FILE=%~1"
set "DATA_FILE=%~2"
set "LABEL=%~3"
set "OUTVAR=%~4"
set "FPR_FILE=%~5"
if not "%OUTVAR%"=="" set "%OUTVAR%=0"

if "%PORTANODE_ALLOW_UNVERIFIED%"=="1" (
    echo Warning: PORTANODE_ALLOW_UNVERIFIED=1 set; skipping PGP verification
    echo of %LABEL%. Installing UNAUTHENTICATED binaries.
    exit /b 0
)

where gpg >nul 2>&1
if not %errorlevel%==0 (
    echo Error: gpg not found; cannot verify %LABEL%.
    echo Install gpg and import the signing key, or set
    echo PORTANODE_ALLOW_UNVERIFIED=1 to bypass ^(NOT recommended^).
    exit /b 1
)

call :warn_if_no_pubkeys
echo Verifying %LABEL% signature...
REM STATUS_FILE is TEMP-derived: see the comment above
REM :warn_if_no_pubkeys's own WNP_ANSWER_FILE on why that makes the
REM caller's delayed-expansion state the thing it depends on (#393,
REM #411). "%SIG_FILE%"/"%DATA_FILE%" are the caller's own paths rather
REM than this file's, and depend on it the same way.
set "STATUS_FILE=%TEMP%\pgp_status_%RANDOM%%RANDOM%.txt"
gpg --status-fd 1 --verify "%SIG_FILE%" "%DATA_FILE%" 1> "%STATUS_FILE%" 2>nul

findstr /c:"[GNUPG:] BADSIG" "%STATUS_FILE%" >nul 2>&1
if %errorlevel%==0 (
    echo Error: BAD PGP signature on %LABEL%.
    del "%STATUS_FILE%" >nul 2>&1
    exit /b 1
)
findstr /c:"[GNUPG:] GOODSIG" "%STATUS_FILE%" >nul 2>&1
if not %errorlevel%==0 (
    echo Error: no valid PGP signature on %LABEL% ^(is the signer's key imported?^).
    echo Import the signing key, or set PORTANODE_ALLOW_UNVERIFIED=1 ^(NOT recommended^).
    del "%STATUS_FILE%" >nul 2>&1
    exit /b 1
)

REM Optional fingerprint pinning: enforce only if FPR_FILE lists a fingerprint.
REM Pre-filter to hex-only lines in a temp file (so the loop never echoes
REM comment text containing ) or > etc.), then require a pinned fingerprint to
REM appear on a VALIDSIG line (which carries both signing and primary key fprs).
set "FPR_CLEAN=%TEMP%\pn_fpr_%RANDOM%%RANDOM%.txt"
set "PIN=0"
if not "%FPR_FILE%"=="" if exist "%FPR_FILE%" findstr /i /r "^[0-9A-F][0-9A-F]*$" "%FPR_FILE%" > "%FPR_CLEAN%" 2>nul
if exist "%FPR_CLEAN%" for %%Z in ("%FPR_CLEAN%") do if %%~zZ GTR 0 set "PIN=1"
if "%PIN%"=="1" (
    set "MATCHED="
    for /f "usebackq delims=" %%K in ("%FPR_CLEAN%") do (
        findstr /c:"[GNUPG:] VALIDSIG" "%STATUS_FILE%" | findstr /i /c:"%%K" >nul 2>&1 && set "MATCHED=1"
    )
    if not defined MATCHED (
        echo Error: %LABEL% signed, but not by a pinned key in "%FPR_FILE%".
        del "%STATUS_FILE%" >nul 2>&1
        del "%FPR_CLEAN%" >nul 2>&1
        exit /b 1
    )
)

del "%FPR_CLEAN%" >nul 2>&1
del "%STATUS_FILE%" >nul 2>&1
if not "%OUTVAR%"=="" set "%OUTVAR%=1"
exit /b 0

:update_checksum
set "FILEPATH_RAW=%~1"
set "VERSION_LABEL=%~2"
call :normalize_fs_path "%FILEPATH_RAW%" FILEPATH_FS
call :normalize_entry_path "%FILEPATH_RAW%" FILEPATH_ENTRY
if not exist "%FILEPATH_FS%" exit /b 0
if "%CHECKSUM_FILE%"=="" exit /b 0
REM Appends the one new entry with Add-Content rather than rewriting the file
REM with Set-Content, matching what README.md documents this file as:
REM append-only. A rewrite of every line on each call -- and Select-Object
REM -Unique silently dropping any repeated one, comments included -- is what
REM Add-Content avoids.
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
REM Add-Content still appends an entry whose hash field is empty into
REM the append-only checksums.sha256. $fh is checked before ".Hash" is
REM read, so either failure leaves it unset and exits 1 with nothing
REM appended. :verify_checksum below already fails closed on the same
REM $null unguarded, because PowerShell binds a $null argument into
REM String.StartsWith as a false match rather than raising.
powershell -NoProfile -Command "& { $file = '%FILEPATH_FS%'; $version = '%VERSION_LABEL%'; $checksum = '%CHECKSUM_FILE%'; if (-not (Test-Path $checksum)) { Write-Host 'Warning: win/checksums.sha256 not found; skipping.'; exit 0 } $fh = Get-FileHash -Algorithm SHA256 $file; if (-not $fh) { Write-Host 'Error: could not hash %FILEPATH_ENTRY%; not appending to win/checksums.sha256.'; exit 1 } $hash = $fh.Hash.ToLower(); $entry = $hash + '  %FILEPATH_ENTRY%  version=' + $version; $existing = Get-Content $checksum; if ($existing -notcontains $entry) { Add-Content -Encoding ASCII -Path $checksum -Value $entry } }"
if errorlevel 1 exit /b 1
exit /b 0

:verify_checksum
set "FILEPATH_RAW=%~1"
set "CHECKPATH_RAW=%~2"
call :normalize_fs_path "%FILEPATH_RAW%" FILEPATH_FS
call :normalize_entry_path "%CHECKPATH_RAW%" CHECKPATH_ENTRY
REM Fails CLOSED on a missing file, converging on
REM shared/utilities/lib.sh's verify_checksum_entry, which returns
REM non-zero on the same case.
if exist "%FILEPATH_FS%" goto :verify_checksum_found
call :rootdir_relative "%FILEPATH_FS%" FILEPATH_REL
echo Error: %FILEPATH_REL% not found.
exit /b 1
:verify_checksum_found
if "%CHECKSUM_FILE%"=="" exit /b 1
REM Built as one physical line: see :update_checksum's comment above on
REM why a "^" split across this block's open quote is not a continuation.
REM "-not" rather than "!" for the reason :update_checksum's comment
REM above gives.
powershell -NoProfile -Command "& { $file = '%FILEPATH_FS%'; $path = '%CHECKPATH_ENTRY%'; $checksum = '%CHECKSUM_FILE%'; if (-not (Test-Path $checksum)) { exit 1 } $hash = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower(); $pathNorm = $path.ToLower(); $lines = Get-Content $checksum; $found = $false; foreach ($l in $lines) { $line = $l.ToLower().Replace('\','/'); if ($line.StartsWith($hash) -and $line.Contains($pathNorm)) { $found = $true; break } } if (-not $found) { exit 1 } }"
if errorlevel 1 exit /b 1
exit /b 0

REM :installed_version FILE ENTRY_PATH CHECKSUM_FILE OUTVAR
REM Sets OUTVAR to the "version=" label of the checksum entry matching
REM FILE's current hash, or "unknown". For a --dry-run plan's "currently
REM installed" line; never fails the caller, only reports.
:installed_version
set "IV_FILE_RAW=%~1"
set "IV_ENTRY_RAW=%~2"
set "IV_CHECKSUM=%~3"
set "IV_OUTVAR=%~4"
call :normalize_fs_path "%IV_FILE_RAW%" IV_FILE_FS
call :normalize_entry_path "%IV_ENTRY_RAW%" IV_ENTRY_ENTRY
set "%IV_OUTVAR%=unknown"
if not exist "%IV_FILE_FS%" exit /b 0
if not exist "%IV_CHECKSUM%" exit /b 0
REM Built as one physical line: see :update_checksum's comment above on
REM why a "^" split across this block's open quote is not a continuation.
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "& { $hash = (Get-FileHash -Algorithm SHA256 '%IV_FILE_FS%').Hash.ToLower(); $path = '%IV_ENTRY_ENTRY%'.ToLower(); $lines = Get-Content '%IV_CHECKSUM%'; foreach ($l in $lines) { $line = $l.ToLower().Replace('\','/'); if ($line.StartsWith($hash) -and $line.Contains($path)) { if ($l -match 'version=(\S+)') { Write-Output $matches[1] } break } } }"`) do set "%IV_OUTVAR%=%%V"
exit /b 0

REM :rootdir_relative PATH OUTVAR
REM PATH with the ROOTDIR prefix removed, for a message: the folder is
REM mounted at a different point on every machine it is plugged into, so a
REM message quoting the mount point tells the reader where this run
REM happened rather than which file in the folder is meant. A path outside
REM the folder carries no such prefix and comes back unchanged, being a
REM path CLAUDE.md's ROOTDIR convention does not reach.
REM "call set" is what expands ROOTDIR inside the pattern: cmd reads the
REM percent signs of "%PATH:%ROOTDIR%\=%" as three pairs and substitutes
REM nothing, where the second parse a "call" adds sees one pair around an
REM already-expanded ROOTDIR. The guard is for an unset ROOTDIR, which
REM would leave the pattern a bare backslash and strip every separator in
REM the path.
:rootdir_relative
set "RR_PATH=%~1"
set "RR_OUTVAR=%~2"
if defined ROOTDIR call set "RR_PATH=%%RR_PATH:%ROOTDIR%\=%%"
set "%RR_OUTVAR%=%RR_PATH%"
exit /b 0

REM :rootdir_arg ROOTDIR OUTVAR
REM ROOTDIR carries no trailing separator except at a drive root
REM (win/scripts/root.bat), and that one case is what this guards: handed
REM straight to a quoted "%ROOTDIR%" argument for a spawned process --
REM powershell.exe reads its argv by the Windows rules, where a backslash
REM immediately before a closing quote escapes the quote instead of ending
REM it -- a trailing "E:\" would run the argument on past the intended end
REM of the line. Doubling that one backslash keeps it: an even count before
REM the quote parses back to one literal backslash and a real close, where
REM ROOTDIR's ordinary no-trailing-separator case has nothing to double.
:rootdir_arg
set "RA_ROOTDIR=%~1"
set "RA_OUTVAR=%~2"
if "%RA_ROOTDIR:~-1%"=="\" set "RA_ROOTDIR=%RA_ROOTDIR%\"
set "%RA_OUTVAR%=%RA_ROOTDIR%"
exit /b 0

:normalize_fs_path
set "RAW=%~1"
set "OUTVAR=%~2"
set "VAL=%RAW:/=\%"
set "%OUTVAR%=%VAL%"
exit /b 0

:normalize_entry_path
set "RAW=%~1"
set "OUTVAR=%~2"
set "VAL=%RAW:\=/%"
set "%OUTVAR%=%VAL%"
exit /b 0
