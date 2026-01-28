@echo off
setlocal enabledelayedexpansion
REM Update Bitcoin Core binaries (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"
pushd "%ROOTDIR%" >nul 2>&1

set "BIN_DIR=%ROOTDIR%\\win\\bin"
set "BACKUP_DIR=%BIN_DIR%\\backup\\bitcoin"

set VERSION=30.2
set FILE=bitcoin-%VERSION%-win64.zip
set BASE_URL=https://bitcoincore.org/bin/bitcoin-core-%VERSION%/
set URL=%BASE_URL%%FILE%
set CHECKSUM_URL=%BASE_URL%SHA256SUMS
set CHECKSUM_SIG_URL=%BASE_URL%SHA256SUMS.asc
set CHECKSUM_FILE=%ROOTDIR%\\win\\checksums.sha256

set TMPDIR=%BIN_DIR%\\.tmp-downloads\\bitcoin
set STATUS=0
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
mkdir "%TMPDIR%"

echo Updating Bitcoin Core to %VERSION%...

tasklist /fi "imagename eq bitcoind.exe" | find /i "bitcoind.exe" >nul
if %errorlevel%==0 (
    echo Error: Bitcoin Core is running. Stop it before updating.
    popd >nul 2>&1
    exit /b 1
)
tasklist /fi "imagename eq bitcoin-qt.exe" | find /i "bitcoin-qt.exe" >nul
if %errorlevel%==0 (
    echo Error: Bitcoin Core is running. Stop it before updating.
    popd >nul 2>&1
    exit /b 1
)
echo Downloading %URL%...
set PGP_OK=0
powershell -Command ^
  "& { $ProgressPreference = 'SilentlyContinue'; ^
  Invoke-WebRequest -Uri '%URL%' -OutFile '%TMPDIR%\\%FILE%' }" ^
  || goto :error
powershell -Command ^
  "& { $ProgressPreference = 'SilentlyContinue'; ^
  Invoke-WebRequest -Uri '%CHECKSUM_URL%' ^
  -OutFile '%TMPDIR%\\SHA256SUMS' }" ^
  || goto :error
powershell -Command ^
  "& { $ProgressPreference = 'SilentlyContinue'; ^
  Invoke-WebRequest -Uri '%CHECKSUM_SIG_URL%' ^
  -OutFile '%TMPDIR%\\SHA256SUMS.asc' }" ^
  || goto :error

where gpg >nul 2>&1
if %errorlevel%==0 (
    echo Verifying SHA256SUMS signature...
    gpg --verify "%TMPDIR%\\SHA256SUMS.asc" ^
      "%TMPDIR%\\SHA256SUMS" || goto :error
    set PGP_OK=1
) else (
    echo Warning: gpg not found; skipping PGP signature verification.
)

powershell -Command ^
  "& { $sum = Get-Content '%TMPDIR%\\SHA256SUMS' ^
  | Select-String -Pattern '%FILE%' | Select-Object -First 1; ^
  if (-not $sum) { Write-Host 'Checksum entry not found.'; exit 1 } ^
  $expected = ($sum -split '\\s+')[0].ToLower(); ^
  $actual = (Get-FileHash -Algorithm SHA256 ^
    '%TMPDIR%\\%FILE%').Hash.ToLower(); ^
  if ($expected -ne $actual) { Write-Host 'Checksum failed.'; exit 1 } ^
  Write-Host '%FILE%: OK' }" || goto :error

powershell -Command ^
  "& { Expand-Archive -Force '%TMPDIR%\\%FILE%' '%TMPDIR%\\' }" ^
  || goto :error

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
if exist "%BIN_DIR%\\bitcoin-qt.exe" ^
  copy /y "%BIN_DIR%\\bitcoin-qt.exe" "%BACKUP_DIR%\\" >nul
if exist "%BIN_DIR%\\bitcoind.exe" ^
  copy /y "%BIN_DIR%\\bitcoind.exe" "%BACKUP_DIR%\\" >nul
if exist "%BIN_DIR%\\bitcoin-cli.exe" ^
  copy /y "%BIN_DIR%\\bitcoin-cli.exe" "%BACKUP_DIR%\\" >nul
if exist "%BIN_DIR%\\bitcoin-wallet.exe" ^
  copy /y "%BIN_DIR%\\bitcoin-wallet.exe" "%BACKUP_DIR%\\" >nul
if exist "%BIN_DIR%\\bitcoin-tx.exe" ^
  copy /y "%BIN_DIR%\\bitcoin-tx.exe" "%BACKUP_DIR%\\" >nul
if exist "%BIN_DIR%\\bitcoin-util.exe" ^
  copy /y "%BIN_DIR%\\bitcoin-util.exe" "%BACKUP_DIR%\\" >nul
if exist "%BIN_DIR%\\bitcoin.exe" ^
  copy /y "%BIN_DIR%\\bitcoin.exe" "%BACKUP_DIR%\\" >nul

if not exist "%TMPDIR%\\bitcoin-%VERSION%\\bin\\bitcoin-qt.exe" (
    echo Error: extracted binaries not found.
    goto :error
)
copy /y "%TMPDIR%\\bitcoin-%VERSION%\\bin\\*.exe" "%BIN_DIR%\\" >nul

if "%PGP_OK%"=="1" (
  call :update_checksum "win\bin\bitcoin-qt.exe" "%VERSION%"
  call :update_checksum "win\bin\bitcoind.exe" "%VERSION%"
  call :update_checksum "win\bin\bitcoin-cli.exe" "%VERSION%"
  call :update_checksum "win\bin\bitcoin-wallet.exe" "%VERSION%"
  call :update_checksum "win\bin\bitcoin-tx.exe" "%VERSION%"
  call :update_checksum "win\bin\bitcoin-util.exe" "%VERSION%"
  call :update_checksum "win\bin\bitcoin.exe" "%VERSION%"
) else (
  echo Warning: PGP not verified; skipping checksum update.
)

echo Bitcoin Core updated to %VERSION%

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
