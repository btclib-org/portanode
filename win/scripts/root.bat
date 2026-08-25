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
