@echo off
setlocal

set ROOTDIR=%~dp0

:menu
echo Electrum Launcher
echo 1^) Mainnet
echo 2^) Testnet
echo 3^) Regtest
echo 4^) Mainnet ^(local server only^)
echo 0^) Exit
set /p choice=Select: 

if "%choice%"=="" set "choice=0"
if "%choice%"=="1" set "SCRIPT=%ROOTDIR%win\scripts\electrum\mainnet.bat"
if "%choice%"=="2" set "SCRIPT=%ROOTDIR%win\scripts\electrum\testnet.bat"
if "%choice%"=="3" set "SCRIPT=%ROOTDIR%win\scripts\electrum\regtest.bat"
if "%choice%"=="4" set "SCRIPT=%ROOTDIR%win\scripts\electrum\mainnet-local-server-only.bat"
if "%choice%"=="0" goto end

if "%choice%"=="1" goto run
if "%choice%"=="2" goto run
if "%choice%"=="3" goto run
if "%choice%"=="4" goto run

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
