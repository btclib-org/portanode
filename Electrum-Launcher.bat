@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%win\scripts\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR

:menu
echo Electrum Launcher
echo 1^) Mainnet
echo 2^) Testnet3
echo 3^) Testnet4
echo 4^) Regtest
echo 5^) Mainnet ^(local server only^)
echo 0^) Exit
set /p "choice=Select: "

if "%choice%"=="" set "choice=0"
if "%choice%"=="1" set "SCRIPT=%ROOTDIR%\win\scripts\electrum\mainnet.bat"
if "%choice%"=="2" set "SCRIPT=%ROOTDIR%\win\scripts\electrum\testnet3.bat"
if "%choice%"=="3" set "SCRIPT=%ROOTDIR%\win\scripts\electrum\testnet4.bat"
if "%choice%"=="4" set "SCRIPT=%ROOTDIR%\win\scripts\electrum\regtest.bat"
if "%choice%"=="5" set "SCRIPT=%ROOTDIR%\win\scripts\electrum\mainnet-local-server-only.bat"
if "%choice%"=="0" goto end

if "%choice%"=="1" goto run
if "%choice%"=="2" goto run
if "%choice%"=="3" goto run
if "%choice%"=="4" goto run
if "%choice%"=="5" goto run

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
