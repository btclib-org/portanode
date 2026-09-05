@echo off
setlocal disabledelayedexpansion
REM Health check for PortaNode (Windows)

REM Delayed expansion is off from line 2 until it is turned on below,
REM and explicitly disabled rather than merely not enabled, so the
REM guarantee holds regardless of what a caller set. cmd.exe runs its
REM delayed-expansion pass after percent expansion, so with it on an
REM unmatched "!" is stripped out of the expanded "%~dp0" below and out
REM of every path built on ROOTDIR, and a folder mounted at a path
REM holding one is legal on exFAT and NTFS alike (#374). Everything
REM derived from the mount path is resolved in this region, the calls into
REM root.bat and lib.bat among them: a call re-parses its own target
REM and its arguments under that same pass and strips a second time,
REM from a bang-delimited read as readily as from a percent one (#411).
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
call "%SCRIPT_DIR%lib.bat" :rootdir_arg "%ROOTDIR%" ROOTDIR_ARG

pushd "%ROOTDIR%" >nul 2>&1

echo Health Check

tasklist /fi "imagename eq explorer.exe" >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Note: process listing unavailable; detection may be incomplete.
)

set "MOUNT_PATH=%ROOTDIR%"
set FREE_GB=
for /f "usebackq delims=" %%F in (`powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%SCRIPT_DIR%free-space-gb.ps1" -Path "%ROOTDIR_ARG%"`) do set FREE_GB=%%F

REM The client is resolved once here, and every site below reads it out
REM of BTC_CLI rather than naming a path of its own. The folder's own
REM binary comes first; where the folder carries none, a bitcoin-cli
REM found on PATH is borrowed. macos/scripts/utilities/health-check.sh
REM carries what pins a borrowed client to this folder's own datadir.
set "BTC_CLI="
set "BTC_CLI_SHOWN="
set "BTC_BIN=%ROOTDIR%\win\bin\bitcoin-cli.exe"
if exist "%BTC_BIN%" set "BTC_CLI=%BTC_BIN%"
if defined BTC_CLI call "%SCRIPT_DIR%lib.bat" :rootdir_relative "%BTC_BIN%" BTC_CLI_SHOWN
REM "where" is the PATH lookup cmd.exe has, and it prints every match,
REM so the guard inside the loop keeps the first line -- the one the
REM shell itself would run. What it finds sits outside the folder, so
REM BTC_CLI_SHOWN keeps the absolute path "where" returned: a binary
REM outside the folder is outside the ROOTDIR-relative rule rather than
REM an exception to it.
if not defined BTC_CLI (
    for /f "usebackq delims=" %%W in (`where bitcoin-cli.exe 2^>nul`) do (
        if not defined BTC_CLI (
            set "BTC_CLI=%%W"
            set "BTC_CLI_SHOWN=%%W"
        )
    )
)

REM Delayed expansion from here to the endlocal at the foot: the
REM reporting below reads variables it writes inside the same "( )"
REM block, which a percent read cannot see. The mount path reaches it
REM through delayed expansion too, rather than through percent
REM expansion: a delayed-expansion read substitutes a value once
REM instead of re-scanning the result for a bang to strip.
setlocal enabledelayedexpansion

if defined FREE_GB (
    if defined MOUNT_PATH (
        REM Delayed expansion, not percent: percent expansion runs before
        REM cmd.exe matches this block's parentheses, so a closing
        REM parenthesis in the mount point would end the block early.
        echo Disk free: !FREE_GB! GB ^(!MOUNT_PATH!^)
    ) else (
        echo Disk free: !FREE_GB! GB
    )
) else (
    echo Disk free: unknown
)

set BTC_RUNNING=0
set BTC_INFO=
set BTC_METHOD=
set ARTIFACTS=
set ARTIFACT_NOTE=
if defined BTC_CLI (
    REM Built as one physical line -- see :update_checksum in
    REM win/scripts/utilities/lib.bat (#144) on why a caret split across
    REM a powershell -Command block's open quote is not a continuation.
    REM -NoProfile keeps this capture to the client's own answer: for /f
    REM iterates every line the child writes, so a $PROFILE that prints
    REM one -- a prompt framework's banner, an Import-Module that is not
    REM silent -- is an iteration too, and the last one is what BTC_INFO
    REM keeps. Measured on windows-latest, against a profile whose body
    REM is Write-Output 'banner' and a bitcoin-cli that writes nothing:
    REM without the flag the run reports the node running, by
    REM bitcoin-cli, and its sync as that banner; with it, not running.
    REM Where nothing reads a child's stdout the flag saves the
    REM profile's load and decides nothing else.
    for /f "usebackq delims=" %%J in (`powershell -NoProfile -Command "& { try { & '!BTC_CLI!' -datadir='!ROOTDIR!\bitcoin-datadir' getblockchaininfo 2>$null } catch { '' } }"`) do set BTC_INFO=%%J
    if defined BTC_INFO (
        set BTC_RUNNING=1
        set BTC_METHOD=bitcoin-cli
    )
)
if "%BTC_RUNNING%"=="0" (
    tasklist /fi "imagename eq bitcoind.exe" | find /i "bitcoind.exe" >nul
    if !errorlevel!==0 (
        set BTC_RUNNING=1
        set BTC_METHOD=tasklist
    )
    if "!BTC_RUNNING!"=="0" (
        tasklist /fi "imagename eq bitcoin-qt.exe" ^
          | find /i "bitcoin-qt.exe" >nul
        if !errorlevel!==0 (
            set BTC_RUNNING=1
            set BTC_METHOD=tasklist
        )
    )
)
REM Artifact detection below. .lock is intentionally NOT treated as an artifact:
REM Bitcoin Core leaves that empty advisory-lock file in the datadir even after
REM a clean shutdown, so it says nothing about running state (and flagging it
REM produced false "maybe" results). .cookie and bitcoind.pid are removed on a
REM clean shutdown, so they are meaningful leftovers. The bitcoind.pid process
REM is checked to actually be Bitcoin, since a reused PID after a crash would
REM otherwise report a false "running".
if "%BTC_RUNNING%"=="0" (
    if exist "!ROOTDIR!\bitcoin-datadir\.cookie" (
        set ARTIFACTS=!ARTIFACTS! .cookie
    )
    if exist "!ROOTDIR!\bitcoin-datadir\bitcoind.pid" (
        set ARTIFACTS=!ARTIFACTS! bitcoind.pid
        REM One physical line: a caret after in, before the file set's
        REM own opening parenthesis, is not a continuation. cmd.exe reads
        REM the for without a file set and refuses it, inside a
        REM parenthesised block and outside one alike.
        for /f "usebackq delims=" %%P in ("!ROOTDIR!\bitcoin-datadir\bitcoind.pid") do set PID=%%P
        if defined PID (
            tasklist /fi "pid eq !PID!" | find /i "bitcoin" >nul
            if !errorlevel!==0 (
                set BTC_RUNNING=1
                set BTC_METHOD=pid
            ) else (
                set "ARTIFACT_NOTE= (stale pid)"
            )
        )
    )
    if defined ARTIFACTS (
        if "!BTC_RUNNING!"=="0" (
            set BTC_RUNNING=2
            set BTC_METHOD=artifacts
            echo Bitcoin artifacts:!ARTIFACTS!!ARTIFACT_NOTE!
        )
    )
)
if "%BTC_RUNNING%"=="1" (
    if defined BTC_METHOD (
        if /i "%BTC_METHOD%"=="bitcoin-cli" (
            REM BTC_CLI_SHOWN is what the resolution above settled on,
            REM not a second lookup: this arm is reached only where that
            REM resolution produced a client and the client answered, so
            REM a lookup here could only disagree with what ran.
            echo Bitcoin running: yes ^(%BTC_METHOD%: !BTC_CLI_SHOWN!^)
        ) else (
            echo Bitcoin running: yes ^(%BTC_METHOD%^)
        )
    ) else (
        echo Bitcoin running: yes
    )
    if defined BTC_CLI (
        REM Built as one physical line -- see :update_checksum in
        REM lib.bat (#144).
        REM -NoProfile for the reason at the first capture above.
        for /f "usebackq delims=" %%J in (`powershell -NoProfile -Command "& { try { $info = & '!BTC_CLI!' -datadir='!ROOTDIR!\bitcoin-datadir' getblockchaininfo 2>$null | ConvertFrom-Json; if ($info.verificationprogress) { [math]::Round($info.verificationprogress*100,2) } } catch { '' } }"`) do set SYNC=%%J
        if defined SYNC (
            echo Bitcoin sync: !SYNC!%%
        ) else (
            echo Bitcoin sync: unknown
        )
    ) else (
        echo Bitcoin sync: unknown
    )
) else (
    if "%BTC_RUNNING%"=="2" (
        if defined BTC_METHOD (
            echo Bitcoin running: maybe ^(%BTC_METHOD%^)
        ) else (
            echo Bitcoin running: maybe
        )
        echo Bitcoin sync: unknown
    ) else (
        echo Bitcoin running: no
        echo Bitcoin sync: n/a
    )
)

set ELECTRUM_RUNNING=0
set ELECTRUM_METHOD=
REM Built as one physical line -- see :update_checksum in lib.bat (#144).
REM -NoProfile for the reason at the first capture above.
for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "& { $p = Get-Process electrum -ErrorAction SilentlyContinue; if ($p) { $p | Select-Object -ExpandProperty Path } }"`) do (
    echo %%P | find /i "\win\bin\electrum.exe" >nul
    if !errorlevel!==0 (
        set ELECTRUM_RUNNING=1
        set ELECTRUM_METHOD=process-path
    )
)
if "%ELECTRUM_RUNNING%"=="0" (
    tasklist /fi "imagename eq electrum.exe" | find /i "electrum.exe" >nul
    if !errorlevel!==0 (
        set ELECTRUM_RUNNING=1
        set ELECTRUM_METHOD=tasklist
    )
)
if "%ELECTRUM_RUNNING%"=="1" (
    if defined ELECTRUM_METHOD (
        echo Electrum running: yes ^(%ELECTRUM_METHOD%^)
    ) else (
        echo Electrum running: yes
    )
) else (
    echo Electrum running: no
)

REM Back to the outer scope, and to delayed expansion off with it, for
REM the :pause_if_own_console call: its target is built on SCRIPT_DIR,
REM and a call under delayed expansion strips a bang out of it (#411).
endlocal
popd >nul 2>&1
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b 0
