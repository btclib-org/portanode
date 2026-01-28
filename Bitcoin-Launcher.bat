@echo off
setlocal

set ROOTDIR=%~dp0

:menu
echo Bitcoin Launcher
echo 1^) Mainnet ^(GUI^)
echo 2^) Testnet3 ^(GUI^)
echo 3^) Regtest Alice ^(GUI^)
echo 4^) Regtest Bob ^(GUI^)
echo 5^) Regtest Carol ^(GUI^)
echo 0^) Exit
set /p choice=Select: 

if "%choice%"=="" set "choice=0"
if "%choice%"=="1" set "SCRIPT=%ROOTDIR%win\scripts\bitcoin\mainnet-8333-qt.bat"
if "%choice%"=="2" set "SCRIPT=%ROOTDIR%win\scripts\bitcoin\testnet3-18333-qt.bat"
if "%choice%"=="3" set "SCRIPT=%ROOTDIR%win\scripts\bitcoin\regtest-18444-Alice-qt.bat"
if "%choice%"=="4" set "SCRIPT=%ROOTDIR%win\scripts\bitcoin\regtest-18555-Bob-qt.bat"
if "%choice%"=="5" set "SCRIPT=%ROOTDIR%win\scripts\bitcoin\regtest-18666-Carol-qt.bat"
if "%choice%"=="0" goto end

if "%choice%"=="1" goto run
if "%choice%"=="2" goto run
if "%choice%"=="3" goto run
if "%choice%"=="4" goto run
if "%choice%"=="5" goto run

echo Invalid selection.
goto menu

:run
call :run_script
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
