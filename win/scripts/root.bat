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
REM A root is marked by VERSION plus one of macos\, win\ or linux\,
REM which is the marker resolve_root in shared/lib.sh looks for; the
REM comment at the head of that loop argues why any one of the three is
REM enough. The trailing backslash is what makes "if exist" test for a
REM directory: without it a plain file named win answers here. VERSION
REM is tested without one, so a directory of that name answers here
REM where resolve_root's own [ -f ] refuses it.
if exist "%ROOTDIR%\\VERSION" (
    if exist "%ROOTDIR%\\macos\" goto :root_resolved
    if exist "%ROOTDIR%\\win\" goto :root_resolved
    if exist "%ROOTDIR%\\linux\" goto :root_resolved
)
for %%I in ("%ROOTDIR%\\..") do set "PARENT=%%~fI"
if /I "%PARENT%"=="%ROOTDIR%" goto :find_root_failed
set "ROOTDIR=%PARENT%"
goto :find_root

:find_root_failed
REM A walk that reaches the top of the drive without a match returns
REM START_DIR rather than the drive root. Neither names a real root, so
REM what this settles is which directory a failed walk hands back, and
REM the drive root is also what a hit returns for a folder unpacked at
REM the top of a volume: a caller handed that value cannot tell the two
REM apart, where START_DIR is the argument it passed in.
set "ROOTDIR=%START_DIR%"
goto :root_resolved

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
REM Waits before returning, but only where the console this script is
REM running in was opened specifically to run it. A double-click of a
REM .bat runs it as "cmd.exe /c <that .bat>", and that console closes the
REM instant the script exits -- discarding whatever it just echoed. A
REM console that was already open before the script started -- a typed
REM invocation, or Bitcoin-Launcher.bat's own "call", which runs in the
REM launcher's own console and returns to its menu instead of closing --
REM is not this console's origin and gets no wait: CMDCMDLINE is fixed
REM when a console is created and does not change across a "call" within
REM it, so it names the script that console was opened for, not
REM whichever script a chain of "call"s has reached since.
REM
REM The first argument is the caller's own %~nx0, read by the caller
REM before this call -- %0 inside this file names root.bat, not the
REM caller, the same reason :resolve_root's own caller reads %~dp0 into
REM SCRIPT_DIR beforehand rather than after.
REM
REM The console command line is read through delayed expansion, and the
REM test is a substring replacement rather than a pipe into find,
REM because %CMDCMDLINE% is substituted before the line is parsed, so
REM its contents are read as part of the command: a console started as
REM "cd /d <this folder> && win\scripts\electrum\mainnet.bat" splits the
REM test at the &&, printing the console command line to the user and
REM running the remainder as a command of its own. Delayed expansion
REM substitutes after the line has been parsed, so &, &&, | and > in
REM the value stay data. A pipe undoes that, each side of one being a
REM new cmd.exe that parses what it is handed; the quotes come out of
REM the value because the comparison is a quoted one that the value's
REM own quotes would end early. The replacement ignores case, so a
REM console command line naming the script in another case still
REM matches it.
REM
REM Measured on windows-latest, each form against a console command
REM line carrying &&, & and a "| ... >nul": the pipe form answers "The
REM input line is too long", CMDCMDLINE inside that child naming the
REM child's own line, and expands a second time whatever % reference
REM the console command line carries, which waits in a console that was
REM not opened for this script; the form below with the value's quotes
REM left in reads every console as somebody else's, so nothing waits
REM at all.
REM
REM The wait expires rather than blocking on a key, because the test
REM above answers yes for a console nobody is at. Task Scheduler runs
REM its action in a cmd.exe whose command line names the script, which
REM is what a double-click produces too, so a scheduled run reaches
REM here with no one to press anything. Measured on windows-latest,
REM the action registered as cmd.exe /c "<script>" and run as SYSTEM:
REM with "pause >nul" here, a scheduled rotate-bitcoin-log.bat still
REM reads State=Running and LastTaskResult=0x41301
REM (SCHED_S_TASK_RUNNING) ninety seconds after it started, against
REM Ready and 0x0 for a task that completes; with the wait below, that
REM run and the log monitor's both read Ready and 0x0. README.md's
REM "Logs and Debugging" is what sends a user to schedule them.
REM
REM Detecting the non-interactive session instead, and skipping the
REM wait there, was the rejected alternative. It can be made to work
REM on a task that already exists -- the detection runs when the
REM script runs, so the action needs no change -- and what it costs
REM is that it has to be right about every console shape. The shapes
REM not run here include a Task Scheduler action whose Program is the
REM .bat path itself rather than cmd /c "<path>", and a task set to
REM run only when the user is logged on. A wait that expires cannot
REM hang in any of them, because it never asks what kind of console
REM it is in.
REM
REM "timeout" ends two ways and only one of them is the countdown.
REM Where stdin is a console -- a double-click, and a scheduled task's
REM own console -- it counts down and returns, measured at just under
REM its 30 seconds in both. Where stdin is redirected it prints "Input
REM redirection is not supported" and returns at once, so a console
REM reached through a pipe is told it has 30 seconds and gets none; a
REM double-click does not produce that case. /NOBREAK is not passed,
REM so a key ends the countdown early, which is what the message
REM offers; that half is documented rather than measured here, a
REM hosted runner having no console to type into.
REM
REM The test reaches every console but one, and PORTANODE_LAUNCHER is
REM how that one announces itself: a .ps1 launcher starts a .bat through
REM a cmd.exe of PowerShell's own, whose command line names the script
REM and so reads here exactly as a double-click of it does, where the
REM console it belongs to is the launcher's and stays open on the menu.
if defined PORTANODE_LAUNCHER exit /b 0
setlocal enabledelayedexpansion
set "SELF=%~1"
set CMDLINE=!CMDCMDLINE:"=!
if not "!CMDLINE:%SELF%=!"=="!CMDLINE!" (
    echo.
    echo Closing in 30 seconds; press a key to close now.
    timeout /t 30 >nul
)
exit /b 0
