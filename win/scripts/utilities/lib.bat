@echo off
REM Shared helpers for Windows utility scripts.

set "ACTION=%~1"
if "%ACTION%"=="" goto :eof
shift
goto %ACTION%

:warn_if_no_pubkeys
set "HAS_PUBKEYS="
for /f %%A in ('gpg --list-keys --with-colons 2^>nul ^| findstr /B "pub"') do set HAS_PUBKEYS=1
if not defined HAS_PUBKEYS echo Warning: no public keys found in local keyring.
exit /b 0

REM :verify_pgp_signature SIG DATA LABEL OUTVAR [FPR_FILE]
REM Fails CLOSED (exit /b 1) unless a good signature is found. If FPR_FILE has
REM any 40-hex fingerprint line, additionally requires a VALIDSIG from a listed
REM key (pinning). Set PORTANODE_ALLOW_UNVERIFIED=1 to bypass (NOT recommended).
REM Written flat (no %var% set-and-read inside a ( ) block) because lib.bat has
REM no delayed expansion and must not enable it (it sets the caller's OUTVAR).
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
powershell -Command ^
  "& { $file = '%FILEPATH_FS%'; $version = '%VERSION_LABEL%'; ^
  $checksum = '%CHECKSUM_FILE%'; ^
  if (!(Test-Path $checksum)) { ^
    Write-Host 'Warning: win/checksums.sha256 not found; skipping.'; ^
    exit 0 } ^
  $hash = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower(); ^
  $entry = "$hash  %FILEPATH_ENTRY%  version=$version"; ^
  $lines = Get-Content $checksum; ^
  if ($lines -notcontains $entry) { $lines += $entry } ^
  $lines = $lines | Select-Object -Unique; ^
  Set-Content -Encoding ASCII $checksum $lines }"
exit /b 0

:verify_checksum
set "FILEPATH_RAW=%~1"
set "CHECKPATH_RAW=%~2"
call :normalize_fs_path "%FILEPATH_RAW%" FILEPATH_FS
call :normalize_entry_path "%CHECKPATH_RAW%" CHECKPATH_ENTRY
if not exist "%FILEPATH_FS%" exit /b 0
if "%CHECKSUM_FILE%"=="" exit /b 1
powershell -Command ^
  "& { $file = '%FILEPATH_FS%'; $path = '%CHECKPATH_ENTRY%'; ^
  $checksum = '%CHECKSUM_FILE%'; ^
  if (!(Test-Path $checksum)) { exit 1 } ^
  $hash = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower(); ^
  $pathNorm = $path.ToLower(); ^
  $lines = Get-Content $checksum; ^
  $found = $false; foreach ($l in $lines) { ^
    $line = $l.ToLower().Replace('\','/'); ^
    if ($line.StartsWith($hash) -and $line.Contains($pathNorm)) { $found = $true; break } } ^
  if (-not $found) { exit 1 } }"
if errorlevel 1 exit /b 1
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
