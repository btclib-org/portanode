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

if "%choice%"=="" goto end
if "%choice%"=="1" goto el_main
if "%choice%"=="2" goto el_test
if "%choice%"=="3" goto el_reg
if "%choice%"=="4" goto el_local
if "%choice%"=="0" goto end

echo Invalid selection.
goto menu

:el_main
call "%ROOTDIR%win\scripts\electrum\mainnet.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%).
goto menu

:el_test
call "%ROOTDIR%win\scripts\electrum\testnet.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%).
goto menu

:el_reg
call "%ROOTDIR%win\scripts\electrum\regtest.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%).
goto menu

:el_local
call "%ROOTDIR%win\scripts\electrum\mainnet-local-server-only.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%).
goto menu

:end
endlocal
exit /b 0
