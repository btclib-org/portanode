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
echo Bitcoin Launcher "%ROOTDIR%"
echo 1^) Mainnet ^(GUI^)
echo 2^) Testnet3 ^(GUI^)
echo 3^) Testnet4 ^(GUI^)
echo 4^) Regtest Alice ^(GUI^)
echo 5^) Regtest Alice ^(GUI, clean^)
echo 6^) Regtest Alice ^(CLI^)
echo 7^) Regtest Alice ^(CLI, clean^)
echo 8^) Regtest Bob ^(GUI^)
echo 9^) Regtest Bob ^(GUI, clean^)
echo 10^) Regtest Bob ^(CLI^)
echo 11^) Regtest Bob ^(CLI, clean^)
echo 12^) Regtest Carol ^(GUI^)
echo 13^) Regtest Carol ^(GUI, clean^)
echo 14^) Regtest Carol ^(CLI^)
echo 15^) Regtest Carol ^(CLI, clean^)
echo 0^) Exit
set /p "choice=Select: "

if "%choice%"=="" set "choice=0"
if "%choice%"=="1" set "SCRIPT_REL=win\scripts\bitcoin\mainnet-8333-qt.bat"
if "%choice%"=="2" set "SCRIPT_REL=win\scripts\bitcoin\testnet3-18333-qt.bat"
if "%choice%"=="3" set "SCRIPT_REL=win\scripts\bitcoin\testnet4-48333-qt.bat"
if "%choice%"=="4" set "SCRIPT_REL=win\scripts\bitcoin\regtest-18444-Alice-qt.bat"
if "%choice%"=="5" set "SCRIPT_REL=win\scripts\bitcoin\regtest-18444-Alice-qt-clean.bat"
if "%choice%"=="6" set "SCRIPT_REL=win\scripts\bitcoin\regtest-18444-Alice-cli.bat"
if "%choice%"=="7" set "SCRIPT_REL=win\scripts\bitcoin\regtest-18444-Alice-cli-clean.bat"
if "%choice%"=="8" set "SCRIPT_REL=win\scripts\bitcoin\regtest-18555-Bob-qt.bat"
if "%choice%"=="9" set "SCRIPT_REL=win\scripts\bitcoin\regtest-18555-Bob-qt-clean.bat"
if "%choice%"=="10" set "SCRIPT_REL=win\scripts\bitcoin\regtest-18555-Bob-cli.bat"
if "%choice%"=="11" set "SCRIPT_REL=win\scripts\bitcoin\regtest-18555-Bob-cli-clean.bat"
if "%choice%"=="12" set "SCRIPT_REL=win\scripts\bitcoin\regtest-18666-Carol-qt.bat"
if "%choice%"=="13" set "SCRIPT_REL=win\scripts\bitcoin\regtest-18666-Carol-qt-clean.bat"
if "%choice%"=="14" set "SCRIPT_REL=win\scripts\bitcoin\regtest-18666-Carol-cli.bat"
if "%choice%"=="15" set "SCRIPT_REL=win\scripts\bitcoin\regtest-18666-Carol-cli-clean.bat"
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
if "%choice%"=="12" goto run
if "%choice%"=="13" goto run
if "%choice%"=="14" goto run
if "%choice%"=="15" goto run

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
