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
    gpg --verify "%TMPDIR%\\%SIG_FILE%" "%TMPDIR%\\%FILE%" || goto :error
    set PGP_OK=1
) else (
    echo Warning: gpg not found; skipping PGP signature verification.
)

if not exist "%TMPDIR%\\%FILE%" (
    echo Error: download failed.
    goto :error
)

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
if exist "%BIN_DIR%\\electrum.exe" ^
  copy /y "%BIN_DIR%\\electrum.exe" "%BACKUP_DIR%\\" >nul

copy /y "%TMPDIR%\\%FILE%" "%BIN_DIR%\\electrum.exe" >nul

if "%PGP_OK%"=="1" (
  call :update_checksum "win\bin\electrum.exe" "%VERSION%"
) else (
  echo Warning: PGP not verified; skipping checksum update.
)

echo Electrum updated to %VERSION%

if exist "%SCRIPT_DIR%verify-binaries.bat" (
    call "%SCRIPT_DIR%verify-binaries.bat"
    if errorlevel 1 set STATUS=1
) else (
    echo Warning: verify-binaries.bat not found; skipping verification.
)

goto :cleanup

:update_checksum
set FILEPATH=%~1
set VERSION_LABEL=%~2
if not exist "%FILEPATH%" exit /b 0
powershell -Command ^
  "& { $file = '%FILEPATH%'; $version = '%VERSION_LABEL%'; ^
  $checksum = '%CHECKSUM_FILE%'; ^
  if (!(Test-Path $checksum)) { ^
    Write-Host 'Warning: win/checksums.sha256 not found; skipping.'; ^
    exit 0 } ^
  $hash = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower(); ^
  $entry = \"$hash  $file  version=$version\"; ^
  $lines = Get-Content $checksum; ^
  if ($lines -notcontains $entry) { $lines += $entry } ^
  $lines = $lines | Select-Object -Unique; ^
  Set-Content -Encoding ASCII $checksum $lines }"
exit /b 0

:error
echo Update failed.
set STATUS=1

:cleanup
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
popd >nul 2>&1
endlocal
exit /b %STATUS%
