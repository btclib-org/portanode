@echo off
setlocal

set ROOTDIR=%~dp0

echo Electrum Launcher
echo 1^) Mainnet
echo 2^) Testnet
echo 3^) Regtest
echo 4^) Mainnet ^(local server only^)
echo 0^) Exit
set /p choice=Select: 

if "%choice%"=="1" goto el_main
if "%choice%"=="2" goto el_test
if "%choice%"=="3" goto el_reg
if "%choice%"=="4" goto el_local
if "%choice%"=="0" goto end

echo Invalid selection.
goto end

:el_main
call "%ROOTDIR%win\scripts\electrum\mainnet.bat"
goto end

:el_test
call "%ROOTDIR%win\scripts\electrum\testnet.bat"
goto end

:el_reg
call "%ROOTDIR%win\scripts\electrum\regtest.bat"
goto end

:el_local
call "%ROOTDIR%win\scripts\electrum\mainnet-local-server-only.bat"
goto end

:end
endlocal
exit /b 0
