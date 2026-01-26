@echo off
setlocal enabledelayedexpansion
REM Rotate Bitcoin debug log (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"

set LOG_FILE=%ROOTDIR%\bitcoin-datadir\debug.log
set MAX_ROTATIONS=5

if not exist "%LOG_FILE%" (
    echo Log file not found: %LOG_FILE%
    exit /b 0
)

set /a START=%MAX_ROTATIONS%-1
for /l %%I in (%START%,-1,1) do (
    if exist "%LOG_FILE%.%%I" (
        set /a NEXT=%%I+1
        ren "%LOG_FILE%.%%I" "debug.log.!NEXT!"
    )
)

powershell -Command "& { Copy-Item -Force '%LOG_FILE%' '%LOG_FILE%.1'; Clear-Content -Path '%LOG_FILE%' }"
echo Log rotated: %LOG_FILE%
exit /b 0
