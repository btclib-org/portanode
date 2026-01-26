@echo off
setlocal

set ROOTDIR=%~dp0

echo Bitcoin Launcher
echo 1^) Mainnet ^(GUI^)
echo 2^) Testnet3 ^(GUI^)
echo 3^) Regtest Alice ^(GUI^)
echo 4^) Regtest Bob ^(GUI^)
echo 5^) Regtest Carol ^(GUI^)
echo 0^) Exit
set /p choice=Select: 

if "%choice%"=="1" goto btc_main
if "%choice%"=="2" goto btc_test
if "%choice%"=="3" goto btc_ra
if "%choice%"=="4" goto btc_rb
if "%choice%"=="5" goto btc_rc
if "%choice%"=="0" goto end

echo Invalid selection.
goto end

:btc_main
call "%ROOTDIR%win\scripts\bitcoin\mainnet-8333-qt.bat"
goto end

:btc_test
call "%ROOTDIR%win\scripts\bitcoin\testnet3-18333-qt.bat"
goto end

:btc_ra
call "%ROOTDIR%win\scripts\bitcoin\regtest-18444-Alice-qt.bat"
goto end

:btc_rb
call "%ROOTDIR%win\scripts\bitcoin\regtest-18555-Bob-qt.bat"
goto end

:btc_rc
call "%ROOTDIR%win\scripts\bitcoin\regtest-18666-Carol-qt.bat"
goto end

:end
endlocal
exit /b 0
