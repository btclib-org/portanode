@echo off
setlocal

set ROOTDIR=%~dp0

echo Utilities Launcher
echo 1^) Verify binaries
echo 2^) Validate setup
echo 3^) Health check
echo 4^) Rotate Bitcoin log
echo 5^) Monitor Bitcoin log
echo 6^) Clean artifacts
echo 7^) Set permissions
echo 0^) Exit
set /p choice=Select: 

if "%choice%"=="1" goto v
if "%choice%"=="2" goto val
if "%choice%"=="3" goto hc
if "%choice%"=="4" goto rot
if "%choice%"=="5" goto mon
if "%choice%"=="6" goto clean
if "%choice%"=="7" goto perm
if "%choice%"=="0" goto end

echo Invalid selection.
goto end

:v
call "%ROOTDIR%win\scripts\utilities\verify-binaries.bat"
goto end

:val
call "%ROOTDIR%win\scripts\utilities\validate-setup.bat"
goto end

:hc
call "%ROOTDIR%win\scripts\utilities\health-check.bat"
goto end

:rot
call "%ROOTDIR%win\scripts\utilities\rotate-bitcoin-log.bat"
goto end

:mon
call "%ROOTDIR%win\scripts\utilities\monitor-bitcoin-log.bat"
goto end

:clean
call "%ROOTDIR%win\scripts\utilities\clean-artifacts.bat"
goto end

:perm
call "%ROOTDIR%win\scripts\utilities\set-permissions.bat"
goto end

:end
endlocal
exit /b 0
