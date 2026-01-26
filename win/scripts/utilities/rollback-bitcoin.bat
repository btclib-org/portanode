@echo off
setlocal enabledelayedexpansion
REM Rollback Bitcoin Core binaries (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"
set BACKUP_DIR=%ROOTDIR%\win\bin-backup\bitcoin

pushd "%ROOTDIR%" >nul 2>&1

if not exist "%BACKUP_DIR%" (
    echo No backup found in %BACKUP_DIR%
    popd >nul 2>&1
    exit /b 1
)

echo Rolling back Bitcoin binaries...

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

echo Rollback complete. Run macos\scripts\utilities\validate-setup.sh to verify.

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
