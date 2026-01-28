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
if "%choice%"=="1" set "SCRIPT=%ROOTDIR%win\scripts\utilities\update-bitcoin.bat"
if "%choice%"=="2" set "SCRIPT=%ROOTDIR%win\scripts\utilities\update-electrum.bat"
if "%choice%"=="3" set "SCRIPT=%ROOTDIR%win\scripts\utilities\verify-binaries.bat"
if "%choice%"=="4" set "SCRIPT=%ROOTDIR%win\scripts\utilities\validate-setup.bat"
if "%choice%"=="5" set "SCRIPT=%ROOTDIR%win\scripts\utilities\set-permissions.bat"
if "%choice%"=="6" set "SCRIPT=%ROOTDIR%win\scripts\utilities\health-check.bat"
if "%choice%"=="7" set "SCRIPT=%ROOTDIR%win\scripts\utilities\monitor-bitcoin-log.bat"
if "%choice%"=="8" set "SCRIPT=%ROOTDIR%win\scripts\utilities\rotate-bitcoin-log.bat"
if "%choice%"=="9" set "SCRIPT=%ROOTDIR%win\scripts\utilities\clean-artifacts.bat"
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
