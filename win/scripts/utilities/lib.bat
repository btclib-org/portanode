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

:verify_pgp_signature
set "SIG_FILE=%~1"
set "DATA_FILE=%~2"
set "LABEL=%~3"
set "OUTVAR=%~4"
set "RESULT=0"
where gpg >nul 2>&1
if %errorlevel%==0 (
    call :warn_if_no_pubkeys
    echo Verifying %LABEL% signature...
    set "STATUS_FILE=%TEMP%\\pgp_status_%RANDOM%%RANDOM%.txt"
    gpg --status-fd 1 --verify "%SIG_FILE%" "%DATA_FILE%" 1> "%STATUS_FILE%"
    set "HAS_GOOD="
    set "HAS_BAD="
    set "HAS_NOPUB="
    for /f "delims=" %%A in ('findstr /c:"[GNUPG:] GOODSIG" "%STATUS_FILE%"') do set HAS_GOOD=1
    for /f "delims=" %%A in ('findstr /c:"[GNUPG:] BADSIG" "%STATUS_FILE%"') do set HAS_BAD=1
    for /f "delims=" %%A in ('findstr /c:"[GNUPG:] NO_PUBKEY" "%STATUS_FILE%"') do set HAS_NOPUB=1
    del "%STATUS_FILE%" >nul 2>&1
    if defined HAS_BAD (
        echo PGP signature verification failed
        exit /b 1
    )
    if not defined HAS_GOOD (
        if defined HAS_NOPUB (
            echo Warning: missing public keys for one or more signatures.
            exit /b 0
        )
        echo PGP signature verification failed
        exit /b 1
    )
    if defined HAS_NOPUB echo Warning: missing public keys for one or more signatures.
    set "RESULT=1"
) else (
    echo Warning: gpg not found; skipping PGP signature verification.
)
if not "%OUTVAR%"=="" set "%OUTVAR%=%RESULT%"
exit /b 0

:update_checksum
set "FILEPATH=%~1"
set "VERSION_LABEL=%~2"
if not exist "%FILEPATH%" exit /b 0
if "%CHECKSUM_FILE%"=="" exit /b 0
powershell -Command ^
  "& { $file = '%FILEPATH%'; $version = '%VERSION_LABEL%'; ^
  $checksum = '%CHECKSUM_FILE%'; ^
  if (!(Test-Path $checksum)) { ^
    Write-Host 'Warning: win/checksums.sha256 not found; skipping.'; ^
    exit 0 } ^
  $hash = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower(); ^
  $entry = "$hash  $file  version=$version"; ^
  $lines = Get-Content $checksum; ^
  if ($lines -notcontains $entry) { $lines += $entry } ^
  $lines = $lines | Select-Object -Unique; ^
  Set-Content -Encoding ASCII $checksum $lines }"
exit /b 0

:verify_checksum
set "FILEPATH=%~1"
set "CHECKPATH=%~2"
if not exist "%FILEPATH%" exit /b 0
if "%CHECKSUM_FILE%"=="" exit /b 1
powershell -Command ^
  "& { $file = '%FILEPATH%'; $path = '%CHECKPATH%'; ^
  $checksum = '%CHECKSUM_FILE%'; ^
  if (!(Test-Path $checksum)) { exit 1 } ^
  $hash = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower(); ^
  $lines = Get-Content $checksum; ^
  $found = $false; foreach ($l in $lines) { ^
    if ($l.ToLower().StartsWith($hash) -and $l.ToLower().Contains($path.ToLower())) { $found = $true; break } } ^
  if (-not $found) { exit 1 } }"
if errorlevel 1 exit /b 1
exit /b 0
