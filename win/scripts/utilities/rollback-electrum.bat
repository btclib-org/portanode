@echo off
setlocal enabledelayedexpansion
REM Rollback Electrum binaries (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"
set BACKUP_DIR=%ROOTDIR%\win\bin\backup\electrum
set CHECKSUM_FILE=%ROOTDIR%\win\checksums.sha256

pushd "%ROOTDIR%" >nul 2>&1

if not exist "%BACKUP_DIR%" (
    echo No backup found in %BACKUP_DIR%
    popd >nul 2>&1
    exit /b 1
)

echo Rolling back Electrum binaries...

if not exist "%CHECKSUM_FILE%" (
    echo Error: %CHECKSUM_FILE% not found.
    popd >nul 2>&1
    exit /b 1
)

call :verify_checksum "%BACKUP_DIR%\electrum.exe" "win\bin\electrum.exe"
if errorlevel 1 (
    echo Error: backup binary checksum not recognized for electrum.exe.
    popd >nul 2>&1
    exit /b 1
)

if not exist "%BACKUP_DIR%\electrum.exe" (
    echo Backup files not found in %BACKUP_DIR%
    popd >nul 2>&1
    exit /b 1
)

move /y "%BACKUP_DIR%\electrum.exe" "%ROOTDIR%\win\bin\" >nul 2>&1
if exist "%BACKUP_DIR%" rmdir "%BACKUP_DIR%" >nul 2>&1

echo Rollback complete. Run win\scripts\utilities\validate-setup.bat to verify.

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
