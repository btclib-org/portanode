@echo off
set "ACTION=%~1"
if "%ACTION%"=="" goto :eof
shift
goto %ACTION%

:resolve_root
set "START_DIR=%~1"
set "OUTVAR=%~2"

if defined PORTANODE_ROOT (
    set "ROOTDIR=%PORTANODE_ROOT%"
    goto :root_resolved
)

set "ROOTDIR=%START_DIR%"
:find_root
if exist "%ROOTDIR%\\VERSION" goto :root_resolved
for %%I in ("%ROOTDIR%\\..") do set "PARENT=%%~fI"
if /I "%PARENT%"=="%ROOTDIR%" goto :root_resolved
set "ROOTDIR=%PARENT%"
goto :find_root

:root_resolved
REM The root is returned with no trailing separator, and a caller writes the
REM separator it needs after it. That is the shape resolve_root in
REM macos/scripts/lib.sh and Resolve-PortaNodeRoot in root.ps1 return, and the
REM shape the callers of this file are written for; a caller that adds one to
REM a path that already ends in a separator is the case Windows forgives, by
REM collapsing the repeat, and the other way round is not.
REM A drive root keeps its backslash, there being no other way to write it:
REM "E:" alone names the current directory of that drive rather than its root.
REM So a caller ending a quoted argument with the root meets a backslash
REM before the closing quote in that one case, and nowhere else.
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"
if "%ROOTDIR:~-1%"=="\" if not "%ROOTDIR:~-2%"==":\" set "ROOTDIR=%ROOTDIR:~0,-1%"
if not "%OUTVAR%"=="" set "%OUTVAR%=%ROOTDIR%"
exit /b 0

:pause_if_own_console
REM Pauses before returning, but only where the console this script is
REM running in was opened specifically to run it. A double-click of a
REM .bat runs it as "cmd.exe /c <that .bat>", and that console closes the
REM instant the script exits -- discarding whatever it just echoed. A
REM console that was already open before the script started -- a typed
REM invocation, or Bitcoin-Launcher.bat's own "call", which runs in the
REM launcher's own console and returns to its menu instead of closing --
REM is not this console's origin and gets no pause: CMDCMDLINE is fixed
REM when a console is created and does not change across a "call" within
REM it, so it names the script that console was opened for, not
REM whichever script a chain of "call"s has reached since.
REM
REM The first argument is the caller's own %~nx0, read by the caller
REM before this call -- %0 inside this file names root.bat, not the
REM caller, the same reason :resolve_root's own caller reads %~dp0 into
REM SCRIPT_DIR beforehand rather than after.
set "SELF=%~1"
echo "%CMDCMDLINE%" | find /I "%SELF%" >nul
if not errorlevel 1 (
    echo.
    echo Press any key to close this window.
    pause >nul
)
exit /b 0
