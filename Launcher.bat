@echo off
setlocal

set ROOTDIR=%~dp0

:menu
echo PortaNode Launcher
echo 1^) Bitcoin Mainnet (GUI)
echo 2^) Bitcoin Testnet3 (GUI)
echo 3^) Bitcoin Regtest Alice (GUI)
echo 4^) Bitcoin Regtest Bob (GUI)
echo 5^) Bitcoin Regtest Carol (GUI)
echo 6^) Electrum Mainnet
echo 7^) Electrum Testnet
echo 8^) Electrum Regtest
echo 9^) Electrum Mainnet (local server only)
echo 0^) Exit
set /p choice=Select: 

if "%choice%"=="" goto end
if "%choice%"=="1" goto btc_main
if "%choice%"=="2" goto btc_test
if "%choice%"=="3" goto btc_ra
if "%choice%"=="4" goto btc_rb
if "%choice%"=="5" goto btc_rc
if "%choice%"=="6" goto el_main
if "%choice%"=="7" goto el_test
if "%choice%"=="8" goto el_reg
if "%choice%"=="9" goto el_local
if "%choice%"=="0" goto end

echo Invalid selection.
goto menu

:btc_main
call "%ROOTDIR%win\scripts\bitcoin\mainnet-8333-qt.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%).
goto menu

:btc_test
call "%ROOTDIR%win\scripts\bitcoin\testnet3-18333-qt.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%).
goto menu

:btc_ra
call "%ROOTDIR%win\scripts\bitcoin\regtest-18444-Alice-qt.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%).
goto menu

:btc_rb
call "%ROOTDIR%win\scripts\bitcoin\regtest-18555-Bob-qt.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%).
goto menu

:btc_rc
call "%ROOTDIR%win\scripts\bitcoin\regtest-18666-Carol-qt.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%).
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
