@echo off
setlocal disabledelayedexpansion
REM Copyright (c) The btclib developers
REM Distributed under the MIT software license, see the accompanying
REM LICENSE file or https://opensource.org/license/mit for the full text.

REM Explicitly disabled on line 2 rather than merely not enabled: a bare
REM "setlocal" keeps whatever state the caller left the pass at, and the
REM caller here is the console this was started from. The measurement is
REM in win\scripts\root.bat, above :resolve_root (#473).
set "SCRIPT_DIR=%~dp0"
call "%%SCRIPT_DIR%%win\scripts\root.bat" :resolve_root "%%SCRIPT_DIR%%" ROOTDIR
if errorlevel 1 (
    call "%%SCRIPT_DIR%%win\scripts\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

REM The root is quoted where the .command and .ps1 halves
REM parenthesise it: a mount point carrying & reaches cmd.exe's
REM parser on the header line below, and the quotes are what
REM keep it data.

:menu
echo Utilities Launcher "%ROOTDIR%"
echo 1^) Update Bitcoin Version
echo 2^) Update Electrum Version
echo 3^) Rollback Last Bitcoin Update
echo 4^) Rollback Last Electrum Update
echo 5^) Verify binaries
echo 6^) Validate setup
echo 7^) Set permissions
echo 8^) Health check
echo 9^) Monitor Bitcoin log
echo 10^) Rotate Bitcoin log
echo 11^) Clean Windows artifacts
echo 0^) Exit
set "CHOICE="
set /p "CHOICE=Select: "

if "%CHOICE%"=="" set "CHOICE=0"
if "%CHOICE%"=="1" set "SCRIPT_REL=win\scripts\utilities\update-bitcoin.bat"
if "%CHOICE%"=="2" set "SCRIPT_REL=win\scripts\utilities\update-electrum.bat"
if "%CHOICE%"=="3" set "SCRIPT_REL=win\scripts\utilities\rollback-bitcoin.bat"
if "%CHOICE%"=="4" set "SCRIPT_REL=win\scripts\utilities\rollback-electrum.bat"
if "%CHOICE%"=="5" set "SCRIPT_REL=win\scripts\utilities\verify-binaries.bat"
if "%CHOICE%"=="6" set "SCRIPT_REL=win\scripts\utilities\validate-setup.bat"
if "%CHOICE%"=="7" set "SCRIPT_REL=win\scripts\utilities\set-permissions.bat"
if "%CHOICE%"=="8" set "SCRIPT_REL=win\scripts\utilities\health-check.bat"
if "%CHOICE%"=="9" set "SCRIPT_REL=win\scripts\utilities\monitor-bitcoin-log.bat"
if "%CHOICE%"=="10" set "SCRIPT_REL=win\scripts\utilities\rotate-bitcoin-log.bat"
if "%CHOICE%"=="11" set "SCRIPT_REL=win\scripts\utilities\clean-artifacts.bat"
if "%CHOICE%"=="0" goto end

if "%CHOICE%"=="1" goto run
if "%CHOICE%"=="2" goto run
if "%CHOICE%"=="3" goto run
if "%CHOICE%"=="4" goto run
if "%CHOICE%"=="5" goto run
if "%CHOICE%"=="6" goto run
if "%CHOICE%"=="7" goto run
if "%CHOICE%"=="8" goto run
if "%CHOICE%"=="9" goto run
if "%CHOICE%"=="10" goto run
if "%CHOICE%"=="11" goto run

echo Invalid selection.
echo.
goto menu

:run
call :run_script
echo.
goto menu

REM :run_script
REM Runs the script SCRIPT_REL names under ROOTDIR, and says so where none
REM is there or where it returns an errorlevel of 1 or more.
:run_script
set "SCRIPT=%ROOTDIR%\%SCRIPT_REL%"
if not exist "%SCRIPT%" (
    echo Script not found: %SCRIPT_REL%
    goto :eof
)
call "%%SCRIPT%%"
if errorlevel 1 echo Command failed (exit %errorlevel%).
goto :eof

:end
endlocal
exit /b 0
