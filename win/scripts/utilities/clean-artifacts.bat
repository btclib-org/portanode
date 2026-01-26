@echo off
setlocal enabledelayedexpansion
REM Clean Windows artifacts

set SCRIPT_DIR=%~dp0
set ROOTDIR=%SCRIPT_DIR%..\..\..
for %%I in ("%ROOTDIR%") do set "ROOTDIR=%%~fI"

pushd "%ROOTDIR%" >nul 2>&1

echo Cleaning artifacts...

powershell -Command "& { $root = '%ROOTDIR%'; Get-ChildItem -Path $root -Recurse -Force -ErrorAction SilentlyContinue -Include 'ehthumbs.db','Thumbs.db','*.stackdump' | Remove-Item -Force -ErrorAction SilentlyContinue }"

echo Cleanup complete.
popd >nul 2>&1
exit /b 0
