@echo off
setlocal enabledelayedexpansion
REM Validate setup

set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
call "%SCRIPT_DIR%lib.bat" :rootdir_arg "%ROOTDIR%" ROOTDIR_ARG

pushd "%ROOTDIR%" >nul 2>&1

echo Validating setup at "%ROOTDIR%"


if exist "%SCRIPT_DIR%verify-binaries.bat" (
    call "%SCRIPT_DIR%verify-binaries.bat"
    if errorlevel 1 (
        popd >nul 2>&1
        call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
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
REM (any network section) lowers the requirement. /C: is what makes the
REM pattern one search string: findstr otherwise splits a search string
REM on its spaces, and the trailing piece, "]*[1-9]", matches any line
REM carrying a digit 1-9 -- which this tree's own bitcoin.conf does, so
REM a conf holding no prune= at all reads as pruned and the 700GB
REM warning below never prints. /R is what keeps the string a regular
REM expression behind /C:; measured on windows-latest, /I /C: without
REM /R matches the pattern literally and so answers no match for a
REM bitcoin.conf carrying "prune=1000". The pattern matches a
REM leading space, not a tab -- this tree's own bitcoin.conf indents
REM with neither, so a tab-indented "prune=" would be missed here where
REM the macOS script's [[:space:]] class would still catch it.
set PRUNED=0
if exist "%ROOTDIR%\bitcoin-datadir\bitcoin.conf" (
    findstr /R /I /C:"^[ ]*prune[ ]*=[ ]*[1-9]" ^
      "%ROOTDIR%\bitcoin-datadir\bitcoin.conf" >nul 2>&1
    if not errorlevel 1 set PRUNED=1
)

set FREE_GB=
for /f "usebackq delims=" %%F in (`powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT_DIR%free-space-gb.ps1" -Path "%ROOTDIR_ARG%"`) do set FREE_GB=%%F
if not defined FREE_GB (
    echo WARNING: Could not determine disk free space.
) else (
    echo Disk free space: !FREE_GB! GB
    if !FREE_GB! lss 100 (
        echo ERROR: Less than 100GB free.
        popd >nul 2>&1
        call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
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
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b 0
