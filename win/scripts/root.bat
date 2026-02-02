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
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"
if not "%OUTVAR%"=="" set "%OUTVAR%=%ROOTDIR%"
exit /b 0
