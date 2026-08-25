@echo off
setlocal enabledelayedexpansion
REM Validate setup

set SCRIPT_DIR=%~dp0
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR

pushd "%ROOTDIR%" >nul 2>&1

echo Validating setup at %ROOTDIR%


if exist "%SCRIPT_DIR%verify-binaries.bat" (
    call "%SCRIPT_DIR%verify-binaries.bat"
    if errorlevel 1 (
        popd >nul 2>&1
        exit /b 1
    )
) else (
    echo WARNING: verify-binaries.bat not found, skipping checksum check
)

if exist "bitcoin-datadir" if exist "electrum-datadir" (
    echo OK: Data directories exist
) else (
    echo WARNING: Data directories not found
)

REM The two figures are README.md's Prerequisites: 700GB for an
REM unpruned mainnet full sync, 100GB otherwise (pruned, testnet, or
REM regtest) -- changing either belongs there first, this comment
REM second. Pruning is read from bitcoin-datadir\bitcoin.conf rather
REM than assumed: an active, non-zero "prune=" anywhere in the file
REM (any network section) lowers the requirement. The pattern matches a
REM leading space, not a tab -- this tree's own bitcoin.conf indents
REM with neither, so a tab-indented "prune=" would be missed here where
REM the macOS script's [[:space:]] class would still catch it.
set PRUNED=0
if exist "%ROOTDIR%\bitcoin-datadir\bitcoin.conf" (
    findstr /R /I "^[ ]*prune[ ]*=[ ]*[1-9]" ^
      "%ROOTDIR%\bitcoin-datadir\bitcoin.conf" >nul 2>&1
    if not errorlevel 1 set PRUNED=1
)

set FREE_GB=
for /f "usebackq delims=" %%F in (`powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT_DIR%free-space-gb.ps1" -Path "%ROOTDIR%"`) do set FREE_GB=%%F
if not defined FREE_GB (
    echo WARNING: Could not determine disk free space.
) else (
    echo Disk free space: !FREE_GB! GB
    if !FREE_GB! lss 100 (
        echo ERROR: Less than 100GB free.
        popd >nul 2>&1
        exit /b 1
    )
    if !PRUNED!==0 if !FREE_GB! lss 700 (
        echo WARNING: Less than 700GB free, and
        echo bitcoin-datadir\bitcoin.conf has no active prune=. An
        echo unpruned mainnet full sync needs 700GB; enable pruning,
        echo or use testnet/regtest, if this is not one.
    )
)

echo Setup validation completed.
popd >nul 2>&1
exit /b 0
