@echo off
setlocal disabledelayedexpansion

REM Explicitly disabled on line 2 rather than merely not enabled: a bare
REM "setlocal" keeps whatever state the caller left the pass at, and the
REM caller here is the console this was started from. The measurement is
REM in win\scripts\root.bat, above :resolve_root (#473).
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%win\scripts\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR

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
set /p "choice=Select: "

if "%choice%"=="" set "choice=0"
if "%choice%"=="1" set "SCRIPT_REL=win\scripts\utilities\update-bitcoin.bat"
if "%choice%"=="2" set "SCRIPT_REL=win\scripts\utilities\update-electrum.bat"
if "%choice%"=="3" set "SCRIPT_REL=win\scripts\utilities\rollback-bitcoin.bat"
if "%choice%"=="4" set "SCRIPT_REL=win\scripts\utilities\rollback-electrum.bat"
if "%choice%"=="5" set "SCRIPT_REL=win\scripts\utilities\verify-binaries.bat"
if "%choice%"=="6" set "SCRIPT_REL=win\scripts\utilities\validate-setup.bat"
if "%choice%"=="7" set "SCRIPT_REL=win\scripts\utilities\set-permissions.bat"
if "%choice%"=="8" set "SCRIPT_REL=win\scripts\utilities\health-check.bat"
if "%choice%"=="9" set "SCRIPT_REL=win\scripts\utilities\monitor-bitcoin-log.bat"
if "%choice%"=="10" set "SCRIPT_REL=win\scripts\utilities\rotate-bitcoin-log.bat"
if "%choice%"=="11" set "SCRIPT_REL=win\scripts\utilities\clean-artifacts.bat"
if "%choice%"=="0" goto end

if "%choice%"=="1" goto run
if "%choice%"=="2" goto run
if "%choice%"=="3" goto run
if "%choice%"=="4" goto run
if "%choice%"=="5" goto run
if "%choice%"=="6" goto run
if "%choice%"=="7" goto run
if "%choice%"=="8" goto run
if "%choice%"=="9" goto run
if "%choice%"=="10" goto run
if "%choice%"=="11" goto run

echo Invalid selection.
echo.
goto menu

:run
call :run_script
echo.
goto menu

:run_script
set "SCRIPT=%ROOTDIR%\%SCRIPT_REL%"
if not exist "%SCRIPT%" (
    echo Script not found: %SCRIPT_REL%
    goto :eof
)
call "%SCRIPT%"
if errorlevel 1 echo Command failed (exit %errorlevel%).
goto :eof

:end
endlocal
exit /b 0
