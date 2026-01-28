@echo off
setlocal enabledelayedexpansion
REM Rollback Bitcoin Core binaries (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"
set BACKUP_DIR=%ROOTDIR%\win\bin\backup\bitcoin
set CHECKSUM_FILE=%ROOTDIR%\win\checksums.sha256

pushd "%ROOTDIR%" >nul 2>&1

if not exist "%BACKUP_DIR%" (
    echo No backup found in %BACKUP_DIR%
    popd >nul 2>&1
    exit /b 1
)

echo Rolling back Bitcoin binaries...

if not exist "%CHECKSUM_FILE%" (
    echo Error: %CHECKSUM_FILE% not found.
    popd >nul 2>&1
    exit /b 1
)

call :verify_checksum "%BACKUP_DIR%\bitcoin-qt.exe" "win\bin\bitcoin-qt.exe"
if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-qt.exe.
    popd >nul 2>&1
    exit /b 1
)
if exist "%BACKUP_DIR%\bitcoind.exe" (
  call :verify_checksum "%BACKUP_DIR%\bitcoind.exe" "win\bin\bitcoind.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoind.exe.
    popd >nul 2>&1
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin-cli.exe" (
  call :verify_checksum "%BACKUP_DIR%\bitcoin-cli.exe" "win\bin\bitcoin-cli.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-cli.exe.
    popd >nul 2>&1
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin-wallet.exe" (
  call :verify_checksum "%BACKUP_DIR%\bitcoin-wallet.exe" "win\bin\bitcoin-wallet.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-wallet.exe.
    popd >nul 2>&1
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin-tx.exe" (
  call :verify_checksum "%BACKUP_DIR%\bitcoin-tx.exe" "win\bin\bitcoin-tx.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-tx.exe.
    popd >nul 2>&1
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin-util.exe" (
  call :verify_checksum "%BACKUP_DIR%\bitcoin-util.exe" "win\bin\bitcoin-util.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin-util.exe.
    popd >nul 2>&1
    exit /b 1
  )
)
if exist "%BACKUP_DIR%\bitcoin.exe" (
  call :verify_checksum "%BACKUP_DIR%\bitcoin.exe" "win\bin\bitcoin.exe"
  if errorlevel 1 (
    echo Error: backup binary checksum not recognized for bitcoin.exe.
    popd >nul 2>&1
    exit /b 1
  )
)

if not exist "%BACKUP_DIR%\bitcoin-qt.exe" (
    echo Backup files not found in %BACKUP_DIR%
    popd >nul 2>&1
    exit /b 1
)

move /y "%BACKUP_DIR%\bitcoin-qt.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
move /y "%BACKUP_DIR%\bitcoind.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
move /y "%BACKUP_DIR%\bitcoin-cli.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
move /y "%BACKUP_DIR%\bitcoin-wallet.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
move /y "%BACKUP_DIR%\bitcoin-tx.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
move /y "%BACKUP_DIR%\bitcoin-util.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
move /y "%BACKUP_DIR%\bitcoin.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
if exist "%BACKUP_DIR%" rmdir "%BACKUP_DIR%" >nul 2>&1

echo Rollback complete.

if exist "%SCRIPT_DIR%verify-binaries.bat" (
    call "%SCRIPT_DIR%verify-binaries.bat"
    if errorlevel 1 (
        popd >nul 2>&1
        exit /b 1
    )
) else (
    echo Warning: verify-binaries.bat not found; skipping verification.
)

popd >nul 2>&1
exit /b 0

:verify_checksum
set FILEPATH=%~1
set CHECKPATH=%~2
if not exist "%FILEPATH%" exit /b 0
powershell -Command ^
  "& { $file = %FILEPATH%; $path = %CHECKPATH%; ^
  $checksum = %CHECKSUM_FILE%; ^
  if (!(Test-Path $checksum)) { exit 1 } ^
  $hash = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower(); ^
  $lines = Get-Content $checksum; ^
  $found = $false; foreach ($l in $lines) { ^
    if ($l.ToLower().StartsWith($hash) -and $l.ToLower().Contains($path.ToLower())) { $found = $true; break } } ^
  if (-not $found) { exit 1 } }"
if errorlevel 1 exit /b 1
exit /b 0
