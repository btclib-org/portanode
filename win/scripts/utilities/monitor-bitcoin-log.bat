@echo off
setlocal enabledelayedexpansion
REM Monitor Bitcoin log for errors (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"

set LOG_FILE=%ROOTDIR%\bitcoin-datadir\debug.log
set LAST_CHECK_FILE=%ROOTDIR%\.last_log_check

if not exist "%LOG_FILE%" (
    echo Log file not found: %LOG_FILE%
    exit /b 0
)

if exist "%LAST_CHECK_FILE%" (
    for /f "usebackq delims=" %%L in ("%LAST_CHECK_FILE%") do set LAST_LINE=%%L
) else (
    set LAST_LINE=0
)

for /f "usebackq delims=" %%C in (`powershell -Command "& { (Get-Content -Path '%LOG_FILE%' -ReadCount 0).Count }"`) do set CURRENT_LINES=%%C

if %CURRENT_LINES% gtr %LAST_LINE% (
    powershell -Command "& { $start = %LAST_LINE% + 1; $end = %CURRENT_LINES%; $lines = Get-Content -Path '%LOG_FILE%' | Select-Object -Skip ($start-1) -First ($end-$start+1); $errors = $lines | Select-String -Pattern 'error|warning|failed' -CaseSensitive:$false | Select-Object -First 5; if ($errors) { Write-Host 'Bitcoin log errors detected:'; $errors | ForEach-Object { Write-Host $_.Line } } }"
    echo %CURRENT_LINES%> "%LAST_CHECK_FILE%"
)

exit /b 0
