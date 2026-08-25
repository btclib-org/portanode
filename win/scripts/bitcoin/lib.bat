@echo off
REM Shared guards for the Bitcoin launchers beside this file, called by label:
REM     call "%SCRIPT_DIR%lib.bat" :label [arguments]
REM Each prints its own message and returns 1 where the caller must stop, so a
REM caller writes: if errorlevel 1 exit /b 1
REM
REM Both read the command line of every running process, Win32_Process being
REM where Windows keeps it, and so both need powershell.exe. A node given the
REM same directory under another name -- a substituted drive, a junction, an
REM 8.3 short path -- is not recognized, and neither is a node of another
REM user, whose command line the query returns empty.
set "ACTION=%~1"
if "%ACTION%"=="" goto :eof
shift
goto %ACTION%

:require_datadir_free
REM Refuse to go on while a Bitcoin node is using the data directory named by
REM the first argument. The second argument, where given, is a switch that
REM node's command line has to carry as well: it is what tells a regtest node
REM from the mainnet node sharing bitcoin-datadir with it.
REM
REM Windows refuses to delete a file another process holds open rather than
REM deleting it, so a clean start run under a live node leaves a data
REM directory emptied of everything except that node's own open files, with
REM the node writing on into what is left. The macOS half of this guard
REM answers a different outcome: there "rm -rf" deletes the open files.
REM
REM The path is matched with repeated separators collapsed and a backslash
REM before a quote dropped, those being the spellings of one directory a
REM command line arrives in. The match ends at a quote, at a space or at the
REM end of the line, which is what stops a node on a subdirectory of this one
REM -- regtest_bob under bitcoin-datadir -- from answering for it.
REM
REM An answer that is neither yes nor no counts as yes. The caller is about to
REM delete a directory, and deleting one on a question nothing answered is
REM what this guard is for; $ErrorActionPreference is what turns a query that
REM fails into an exit code rather than into an empty result.
setlocal
set "NODE_DATADIR=%~1"
set "NODE_SWITCH=%~2"
set "PSFIND=$ErrorActionPreference = 'Stop'; $q = [char]34;"
set "PSFIND=%PSFIND% $d = [regex]::Escape(($env:NODE_DATADIR -replace '\\+','\'));"
set "PSFIND=%PSFIND% $re = '-datadir=' + $q + '?' + $d + $q + '?(\s|$)';"
set "PSFIND=%PSFIND% $s = $env:NODE_SWITCH;"
set "PSFIND=%PSFIND% $p = @(Get-CimInstance Win32_Process | Where-Object {"
set "PSFIND=%PSFIND% $_.Name -in 'bitcoin-qt.exe','bitcoind.exe' -and"
set "PSFIND=%PSFIND% $_.CommandLine -and ((($_.CommandLine -replace"
set "PSFIND=%PSFIND% ('\\+' + $q), $q) -replace '\\+','\') -match $re) -and"
set "PSFIND=%PSFIND% (-not $s -or $_.CommandLine -match [regex]::Escape($s))});"
set "PSFIND=%PSFIND% if ($p.Count -gt 0) { exit 2 }"
powershell -NoProfile -Command "%PSFIND%"
if "%ERRORLEVEL%"=="2" (
    echo Error: a Bitcoin node is using "%NODE_DATADIR%".
    echo Stop it before a clean start.
    exit /b 1
)
if not "%ERRORLEVEL%"=="0" (
    echo Error: could not tell whether a Bitcoin node is using
    echo "%NODE_DATADIR%". Nothing has been deleted.
    exit /b 1
)
exit /b 0

:require_no_mainnet_node
REM Refuse to start a second mainnet node. A process carrying a network switch
REM is on another chain and does not count, which is what leaves a regtest or
REM testnet node running while mainnet starts.
REM
REM Bitcoin Core takes an exclusive lock on the data directory, so a second
REM node exits by itself with "Cannot obtain a lock on directory"; what this
REM adds is the message arriving in the window the user is looking at. That is
REM also why a check that cannot run is not read as a node here, where the
REM guard above reads it as one: starting a node deletes nothing.
setlocal
set "PSFIND=$ErrorActionPreference = 'Stop';"
set "PSFIND=%PSFIND% $chain = '-(testnet|regtest|signet)' +"
set "PSFIND=%PSFIND% '|-chain=(testnet|testnet3|regtest|signet)';"
set "PSFIND=%PSFIND% $p = @(Get-CimInstance Win32_Process | Where-Object {"
set "PSFIND=%PSFIND% $_.Name -in 'bitcoin-qt.exe','bitcoind.exe' -and"
set "PSFIND=%PSFIND% $_.CommandLine -and $_.CommandLine -notmatch $chain});"
set "PSFIND=%PSFIND% if ($p.Count -gt 0) { exit 2 }"
powershell -NoProfile -Command "%PSFIND%"
if "%ERRORLEVEL%"=="2" (
    echo Error: a Bitcoin Core mainnet node is already running.
    echo Stop it before starting another mainnet instance, or use a different
    echo data directory and ports.
    exit /b 1
)
exit /b 0

:require_deleted
REM Deletes the directory named by the first argument and refuses to go on
REM where it is still there afterward.
REM
REM rmdir exits nonzero when the directory did not exist to begin with, which
REM is the ordinary case on a first clean start, so what this checks is the
REM state left behind rather than rmdir's own exit code. A file another
REM process holds open, a volume gone read-only, or an exFAT directory the
REM driver refuses to remove all leave the directory standing afterward, and
REM that is what a caller sees as the failure -- the running-node guard above
REM catches the common case of the first, and this catches what gets past it
REM and every other cause besides.
setlocal
set "WIPE_DIR=%~1"
rmdir "%WIPE_DIR%" /s /q
if exist "%WIPE_DIR%\" (
    echo Error: could not delete "%WIPE_DIR%".
    exit /b 1
)
exit /b 0
