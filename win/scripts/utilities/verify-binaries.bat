@echo off
setlocal disabledelayedexpansion
REM Verify binaries against win/checksums.sha256

REM Explicitly disabled on line 2 rather than merely not enabled, so
REM the guarantee holds regardless of what a caller set. cmd.exe runs
REM its delayed-expansion pass after percent expansion, so with it on
REM an unmatched "!" is stripped out of the expanded "%~dp0" below and
REM out of every path built on ROOTDIR, and a folder mounted at a path
REM holding one is legal on exFAT and NTFS alike (#374). A bare
REM "setlocal" leaves the state where the caller had it, and one
REM caller here is the console the reader starts this from, directly
REM or through Utilities-Launcher.bat. Measured on windows-latest from
REM C:\p374\ba!ng\portanode: under a "cmd /V:ON", and under a "cmd"
REM given no /V flag at all once the user's own DelayedExpansion
REM value under HKCU\Software\Microsoft\Command Processor is 1, the
REM "!" is gone from "%~dp0" and this script answers "Error:
REM win/checksums.sha256 not found." where the same call under a "cmd
REM /V:OFF" reads the file and reports on each binary. Nothing here
REM reads a bang-delimited variable, so disabling it outright costs
REM nothing.
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
call "%SCRIPT_DIR%lib.bat" :rootdir_arg "%ROOTDIR%" ROOTDIR_ARG
set CHECKSUM_FILE=win/checksums.sha256

pushd "%ROOTDIR%" >nul 2>&1

echo Verifying binaries against %CHECKSUM_FILE%

if not exist "%ROOTDIR%\%CHECKSUM_FILE%" (
    echo Error: %CHECKSUM_FILE% not found.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT_DIR%verify-binaries.ps1" ^
  -RootDir "%ROOTDIR_ARG%"

set ERR=%ERRORLEVEL%
popd >nul 2>&1
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b %ERR%
