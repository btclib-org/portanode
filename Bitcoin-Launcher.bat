@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%win\scripts\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR

:menu
echo Bitcoin Launcher
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
if "%choice%"=="1" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\mainnet-8333-qt.bat"
if "%choice%"=="2" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\testnet3-18333-qt.bat"
if "%choice%"=="3" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\testnet4-48333-qt.bat"
if "%choice%"=="4" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\regtest-18444-Alice-qt.bat"
if "%choice%"=="5" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\regtest-18444-Alice-qt-clean.bat"
if "%choice%"=="6" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\regtest-18444-Alice-cli.bat"
if "%choice%"=="7" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\regtest-18444-Alice-cli-clean.bat"
if "%choice%"=="8" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\regtest-18555-Bob-qt.bat"
if "%choice%"=="9" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\regtest-18555-Bob-qt-clean.bat"
if "%choice%"=="10" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\regtest-18555-Bob-cli.bat"
if "%choice%"=="11" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\regtest-18555-Bob-cli-clean.bat"
if "%choice%"=="12" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\regtest-18666-Carol-qt.bat"
if "%choice%"=="13" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\regtest-18666-Carol-qt-clean.bat"
if "%choice%"=="14" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\regtest-18666-Carol-cli.bat"
if "%choice%"=="15" set "SCRIPT=%ROOTDIR%\win\scripts\bitcoin\regtest-18666-Carol-cli-clean.bat"
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
if not exist "%SCRIPT%" (
    echo Script not found: %SCRIPT%
    goto :eof
)
call "%SCRIPT%"
if errorlevel 1 echo Command failed (exit %errorlevel%).
goto :eof

:end
endlocal
exit /b 0
