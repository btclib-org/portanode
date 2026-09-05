@echo off
setlocal disabledelayedexpansion
REM Clean Windows artifacts

REM Explicitly disabled on line 2 rather than merely not enabled, so
REM the guarantee holds regardless of what a caller set. cmd.exe runs
REM its delayed-expansion pass after percent expansion, so with it on
REM an unmatched "!" is stripped out of the expanded "%~dp0" below and
REM out of every path built on ROOTDIR, and a folder mounted at a path
REM holding one is legal on exFAT and NTFS alike (#374). Nothing here
REM reads a bang-delimited variable, so disabling it outright costs
REM nothing.
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR

pushd "%ROOTDIR%" >nul 2>&1

echo Cleaning artifacts...

REM Windows Explorer artifacts (ehthumbs.db, Thumbs.db, *.stackdump) appear
REM where an Explorer window has been -- the launcher and script
REM directories -- and never inside bitcoin-datadir\ or electrum-datadir\,
REM which hold a synced chain's blocks, chainstate and indexes: hundreds of
REM thousands of files on a USB volume. $skip keeps Get-ChildItem from ever
REM enumerating into either, rather than filtering their contents out after
REM walking them. $root is not walked a second time as "win": it is
REM already one of $root's own children.
REM Built as one physical line -- see :update_checksum in
REM win/scripts/utilities/lib.bat (#144) on why a caret split across a
REM powershell -Command block's open quote is not a continuation.
powershell -NoProfile -Command "& { $root = '%ROOTDIR%'; $skip = @('bitcoin-datadir','electrum-datadir'); $paths = (Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue | Where-Object { $skip -notcontains $_.Name }).FullName; if ($paths) { Get-ChildItem -Path $paths -Recurse -Force -ErrorAction SilentlyContinue -Include 'ehthumbs.db','Thumbs.db','*.stackdump' | Remove-Item -Force -ErrorAction SilentlyContinue } }"

echo Cleanup complete.
popd >nul 2>&1
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b 0
