@echo off
setlocal enabledelayedexpansion
REM Update Electrum version (Windows)

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
    set HAS_PUBKEYS=
    for /f %%A in ('gpg --list-keys --with-colons 2^>nul ^| findstr /B "pub"') do set HAS_PUBKEYS=1
    if not defined HAS_PUBKEYS echo Warning: no public keys found in local keyring.
    echo Verifying Electrum signature...
    gpg --verify "%TMPDIR%\%SIG_FILE%" "%TMPDIR%\%FILE%" || goto :error
    set PGP_OK=1
) else (
    echo Warning: gpg not found; skipping PGP signature verification.
)



