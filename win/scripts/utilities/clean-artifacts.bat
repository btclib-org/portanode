@echo off
setlocal enabledelayedexpansion
REM Clean Windows artifacts

set SCRIPT_DIR=%~dp0
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR

pushd "%ROOTDIR%" >nul 2>&1

echo Cleaning artifacts...

powershell -Command ^
  "& { $root = '%ROOTDIR%'; ^
  $targets = @($root, (Join-Path $root 'win')); ^
  foreach ($t in $targets) { ^
    if (Test-Path $t) { ^
      Get-ChildItem -Path $t -Recurse -Force ^
        -ErrorAction SilentlyContinue ^
        -Include 'ehthumbs.db','Thumbs.db','*.stackdump' ^
        | Remove-Item -Force -ErrorAction SilentlyContinue ^
    } ^
  } }"

echo Cleanup complete.
popd >nul 2>&1
exit /b 0
