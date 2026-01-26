@echo off
setlocal enabledelayedexpansion
REM Clean macOS and Windows artifacts (Windows)

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"

pushd "%ROOTDIR%" >nul 2>&1

echo Cleaning artifacts...

powershell -Command "& { $root = '%ROOTDIR%'; Get-ChildItem -Path $root -Recurse -Force -ErrorAction SilentlyContinue -Include '.DS_Store','ehthumbs.db','Thumbs.db','*.stackdump' | Remove-Item -Force -ErrorAction SilentlyContinue; Get-ChildItem -Path $root -Recurse -Force -ErrorAction SilentlyContinue -Filter '._*' | Remove-Item -Force -ErrorAction SilentlyContinue; Get-ChildItem -Path $root -Recurse -Force -ErrorAction SilentlyContinue -Directory -Filter '.Spotlight-V100' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Get-ChildItem -Path $root -Recurse -Force -ErrorAction SilentlyContinue -Directory -Filter '.Trashes' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }"

echo Cleanup complete.
popd >nul 2>&1
exit /b 0
