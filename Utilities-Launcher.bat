@echo off
setlocal

set ROOTDIR=%~dp0

 :menu
echo Utilities Launcher
echo 1^) Verify binaries (Windows)
echo 2^) Validate setup (Windows)
echo 3^) Health check
echo 4^) Rotate Bitcoin log
echo 5^) Monitor Bitcoin log
echo 6^) Clean artifacts (Windows)
echo 7^) Set permissions
echo 0^) Exit
set /p choice=Select: 

if "%choice%"=="" goto end
if "%choice%"=="1" goto v
if "%choice%"=="2" goto val
if "%choice%"=="3" goto hc
if "%choice%"=="4" goto rot
if "%choice%"=="5" goto mon
if "%choice%"=="6" goto clean
if "%choice%"=="7" goto perm
if "%choice%"=="0" goto end

echo Invalid selection.
goto menu

:v
call "%ROOTDIR%win\scripts\utilities\verify-binaries.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:val
call "%ROOTDIR%win\scripts\utilities\validate-setup.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:hc
call "%ROOTDIR%win\scripts\utilities\health-check.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:rot
call "%ROOTDIR%win\scripts\utilities\rotate-bitcoin-log.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:mon
call "%ROOTDIR%win\scripts\utilities\monitor-bitcoin-log.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:clean
call "%ROOTDIR%win\scripts\utilities\clean-artifacts.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:perm
call "%ROOTDIR%win\scripts\utilities\set-permissions.bat"
if errorlevel 1 echo Command failed (exit %errorlevel%). Returning to menu.
goto menu

:end
endlocal
exit /b 0
