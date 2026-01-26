@echo off
setlocal enabledelayedexpansion
REM Update Electrum binaries (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"
pushd "%ROOTDIR%" >nul 2>&1

set CHECKSUM_FILE=%ROOTDIR%\checksums.sha256
set TMPDIR=%TEMP%\portanode-electrum-update
set STATUS=0

if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
mkdir "%TMPDIR%"

echo Updating Electrum...

for /f "usebackq delims=" %%V in (`powershell -Command "& { $html = (Invoke-WebRequest -Uri 'https://electrum.org/' -UseBasicParsing).Content; $m = [regex]::Match($html, 'Latest release: Electrum-([0-9.]+)'); if ($m.Success) { $m.Groups[1].Value } }"`) do set VERSION=%%V

if "%VERSION%"=="" (
    echo Error: Failed to determine latest Electrum version.
    goto :error
)

set FILE=electrum-%VERSION%-portable.exe
set URL=https://download.electrum.org/%VERSION%/%FILE%

echo Downloading %URL%...
powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%URL%' -OutFile '%TMPDIR%\\%FILE%' }" || goto :error

if not exist "%TMPDIR%\\%FILE%" (
    echo Error: download failed.
    goto :error
)

if not exist "%ROOTDIR%\\bin-backup\\electrum" mkdir "%ROOTDIR%\\bin-backup\\electrum"
if exist "%ROOTDIR%\\win\\bin\\electrum.exe" copy /y "%ROOTDIR%\\win\\bin\\electrum.exe" "%ROOTDIR%\\bin-backup\\electrum\\" >nul

copy /y "%TMPDIR%\\%FILE%" "%ROOTDIR%\\win\\bin\\electrum.exe" >nul

call :update_checksum "win\\bin\\electrum.exe"

echo Electrum updated to %VERSION%

if exist "%SCRIPT_DIR%verify-binaries.bat" (
    call "%SCRIPT_DIR%verify-binaries.bat"
    if errorlevel 1 set STATUS=1
) else (
    echo Warning: verify-binaries.bat not found; skipping verification.
)

goto :cleanup

:update_checksum
set FILEPATH=%~1
if not exist "%FILEPATH%" exit /b 0
powershell -Command "& { $file = '%FILEPATH%'; $checksum = '%CHECKSUM_FILE%'; if (!(Test-Path $checksum)) { Write-Host 'Warning: checksums.sha256 not found; skipping.'; exit 0 } $hash = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower(); $lines = Get-Content $checksum; $escaped = [regex]::Escape($file); $lines = $lines | Where-Object { $_ -notmatch ('\\s' + $escaped + '$') }; $lines += \"$hash  $file\"; Set-Content -Encoding ASCII $checksum $lines }"
exit /b 0

:error
echo Update failed.
set STATUS=1

:cleanup
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
popd >nul 2>&1
endlocal
exit /b %STATUS%
