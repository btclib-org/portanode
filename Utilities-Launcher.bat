@echo off
setlocal

set ROOTDIR=%~dp0

:menu
echo Utilities Launcher
echo 1^) Update Bitcoin binaries
echo 2^) Update Electrum binaries
echo 3^) Verify binaries
echo 4^) Validate setup
echo 5^) Set permissions
echo 6^) Health check
echo 7^) Monitor Bitcoin log
echo 8^) Rotate Bitcoin log
echo 9^) Clean Windows artifacts
echo 0^) Exit
set /p choice=Select: 

if "%choice%"=="" set "choice=0"
if "%choice%"=="1" goto upd_btc
if "%choice%"=="2" goto upd_el
if "%choice%"=="3" goto v
if "%choice%"=="4" goto val
if "%choice%"=="5" goto perm
if "%choice%"=="6" goto hc
if "%choice%"=="7" goto mon
if "%choice%"=="8" goto rot
if "%choice%"=="9" goto clean
if "%choice%"=="0" goto end

echo Invalid selection.
goto menu

:upd_btc
call "%ROOTDIR%win\scripts\utilities\update-bitcoin.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:upd_el
call "%ROOTDIR%win\scripts\utilities\update-electrum.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:v
call "%ROOTDIR%win\scripts\utilities\verify-binaries.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:val
call "%ROOTDIR%win\scripts\utilities\validate-setup.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:perm
call "%ROOTDIR%win\scripts\utilities\set-permissions.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:hc
call "%ROOTDIR%win\scripts\utilities\health-check.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:mon
call "%ROOTDIR%win\scripts\utilities\monitor-bitcoin-log.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:rot
call "%ROOTDIR%win\scripts\utilities\rotate-bitcoin-log.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:clean
call "%ROOTDIR%win\scripts\utilities\clean-artifacts.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:end
endlocal
exit /b 0
