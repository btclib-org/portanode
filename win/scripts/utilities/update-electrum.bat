@echo off
setlocal enabledelayedexpansion
REM Update Electrum version (Windows)

set SCRIPT_DIR=%~dp0
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
pushd "%ROOTDIR%" >nul 2>&1

set "BIN_DIR=%ROOTDIR%\win\bin"
set "BACKUP_DIR=%BIN_DIR%\backup\electrum"
set CHECKSUM_FILE=%ROOTDIR%\win\checksums.sha256
set TMPDIR=%BIN_DIR%\.tmp-downloads\electrum
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

for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command ^
    "& { $html = (Invoke-WebRequest -Uri 'https://download.electrum.org/' ^
    -UseBasicParsing).Content; ^
    $versions = [regex]::Matches($html, 'href=\"(\\d+\\.\\d+\\.\\d+)/\"') ^
      | ForEach-Object { $_.Groups[1].Value }; ^
    $versions = $versions | Sort-Object -Unique | Sort-Object {[version]$_}; ^
    if ($versions) { $versions | Select-Object -Last 1 } }"`) ^
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
  Invoke-WebRequest -Uri '%URL%' -OutFile '%TMPDIR%\%FILE%' }" ^
  || goto :error
powershell -Command ^
  "& { $ProgressPreference = 'SilentlyContinue'; ^
  Invoke-WebRequest -Uri '%URL%.asc' ^
  -OutFile '%TMPDIR%\%SIG_FILE%' }" ^
  || goto :error

call "%SCRIPT_DIR%lib.bat" :verify_pgp_signature "%TMPDIR%\%SIG_FILE%" "%TMPDIR%\%FILE%" "Electrum" PGP_OK
if errorlevel 1 goto :error

if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
if exist "%BIN_DIR%\electrum.exe" copy /y "%BIN_DIR%\electrum.exe" "%BACKUP_DIR%\" >nul

if not exist "%TMPDIR%\%FILE%" (
    echo Error: downloaded file not found.
    goto :error
)
copy /y "%TMPDIR%\%FILE%" "%BIN_DIR%\electrum.exe" >nul

if "%PGP_OK%"=="1" (
  call "%SCRIPT_DIR%lib.bat" :update_checksum "win/bin/electrum.exe" "%VERSION%"
) else (
  echo Warning: PGP signature(s) not verified; skipping checksum update.
)

echo Electrum updated to %VERSION%

goto :cleanup

:error
echo Update failed.
set STATUS=1

:cleanup
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
popd >nul 2>&1
endlocal
exit /b %STATUS%
