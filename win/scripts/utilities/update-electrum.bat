@echo off
setlocal enabledelayedexpansion
REM Update Electrum binaries (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"
pushd "%ROOTDIR%" >nul 2>&1

set "BIN_DIR=%ROOTDIR%\\win\\bin"
set "BACKUP_DIR=%BIN_DIR%\\backup\\electrum"
set CHECKSUM_FILE=%ROOTDIR%\\win\\checksums.sha256
set TMPDIR=%BIN_DIR%\\.tmp-downloads\\electrum
set STATUS=0

if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
mkdir "%TMPDIR%"

echo Updating Electrum...

tasklist /fi "imagename eq electrum.exe" | find /i "electrum.exe" >nul
if %errorlevel%==0 (
    echo Error: Electrum is running. Stop it before updating.
    popd >nul 2>&1
    exit /b 1
)

for /f "usebackq delims=" %%V in (`powershell -Command ^
    "& { $html = (Invoke-WebRequest -Uri 'https://electrum.org/' ^
    -UseBasicParsing).Content; ^
    $m = [regex]::Match($html, 'Latest release: Electrum-([0-9.]+)'); ^
    if ($m.Success) { $m.Groups[1].Value } }"`) ^
do set VERSION=%%V

if "%VERSION%"=="" (
    echo Error: Failed to determine latest Electrum version.
    goto :error
)

set FILE=electrum-%VERSION%-portable.exe
set SIG_FILE=%FILE%.asc
set BASE_URL=https://download.electrum.org/%VERSION%/
set URL=%BASE_URL%%FILE%

echo Downloading %URL%...
set PGP_OK=0
powershell -Command ^
  "& { $ProgressPreference = 'SilentlyContinue'; ^
  Invoke-WebRequest -Uri '%URL%' -OutFile '%TMPDIR%\\%FILE%' }" ^
  || goto :error
powershell -Command ^
  "& { $ProgressPreference = 'SilentlyContinue'; ^
  Invoke-WebRequest -Uri '%URL%.asc' ^
  -OutFile '%TMPDIR%\\%SIG_FILE%' }" ^
  || goto :error

where gpg >nul 2>&1
if %errorlevel%==0 (
    echo Verifying Electrum signature...
    set PGP_FINGERPRINT=
    gpg --status-fd 1 --verify "%TMPDIR%\%SIG_FILE%" "%TMPDIR%\%FILE%" > "%TMPDIR%\gpg-status.txt" 2>&1
    findstr /C:"[GNUPG:] GOODSIG" /C:"[GNUPG:] VALIDSIG" "%TMPDIR%\gpg-status.txt" >nul
    if %errorlevel%==0 (
        set PGP_OK=1
        for /f "tokens=3" %%F in ('findstr /C:"[GNUPG:] VALIDSIG" "%TMPDIR%\gpg-status.txt"') do if not defined PGP_FINGERPRINT set PGP_FINGERPRINT=%%F
        if defined PGP_FINGERPRINT (
            echo PGP signature verified (fingerprint: !PGP_FINGERPRINT!).
        ) else (
            echo PGP signature verified (one or more known keys).
        )
        findstr /C:"[GNUPG:] NO_PUBKEY" /C:"[GNUPG:] ERRSIG" "%TMPDIR%\gpg-status.txt" >nul
        if %errorlevel%==0 echo Warning: some signatures could not be checked (missing public keys).
    ) else (
        echo PGP signature verification failed
        goto :error
    )
) else (
    echo Warning: gpg not found; skipping PGP signature verification.
)


