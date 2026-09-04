@echo off
setlocal enabledelayedexpansion
REM Update Bitcoin Core binaries (Windows)

set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
call "%SCRIPT_DIR%lib.bat" :rootdir_arg "%ROOTDIR%" ROOTDIR_ARG

set "VERSION_OVERRIDE="
set "DRY_RUN=0"
:parse_args
if "%~1"=="" goto :args_done
if "%~1"=="--version" (
    set "VERSION_OVERRIDE=%~2"
    shift
    shift
    goto :parse_args
)
if "%~1"=="--dry-run" (
    set "DRY_RUN=1"
    shift
    goto :parse_args
)
echo Usage: %~nx0 [--version ^<v^>] [--dry-run]
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
exit /b 1
:args_done

pushd "%ROOTDIR%" >nul 2>&1

set "BIN_DIR=%ROOTDIR%\win\bin"
set "BACKUP_DIR=%BIN_DIR%\backup\bitcoin"

if defined VERSION_OVERRIDE (
    set "VERSION=%VERSION_OVERRIDE%"
    echo Requested Bitcoin Core version: !VERSION!
) else (
    echo Determining latest Bitcoin Core version...
    set VERSION=
    for /f "usebackq delims=" %%V in (`powershell -NoProfile -ExecutionPolicy Bypass ^
      -File "%SCRIPT_DIR%latest-bitcoin-version.ps1"`) do set VERSION=%%V
    REM latest-bitcoin-version.ps1 prints INDEX_UNREACHABLE when it could
    REM not read the release index, an expired -TimeoutSec included;
    REM PROBE_TIMEOUT when the -TimeoutSec 30 archive HEAD probe expired
    REM on at least one candidate and no candidate's archive was found
    REM either way; and nothing when the index was read, every
    REM candidate's probe answered, and none names a win64 archive. Its
    REM own header says why the three are told apart on stdout. Delayed
    REM expansion, not percent: percent expansion runs when cmd.exe
    REM parses this whole else block, before the for /f above has run.
    if "!VERSION!"=="INDEX_UNREACHABLE" (
        echo Error: failed to fetch the release index from
        echo bitcoincore.org ^(Invoke-WebRequest -TimeoutSec 300^).
        popd >nul 2>&1
        call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
        exit /b 1
    )
    if "!VERSION!"=="PROBE_TIMEOUT" (
        echo Error: bitcoincore.org did not answer a release's win64
        echo archive check within 30 seconds.
        popd >nul 2>&1
        call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
        exit /b 1
    )
    if not defined VERSION (
        echo Error: could not determine a Bitcoin Core release with a win64 build.
        popd >nul 2>&1
        call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
        exit /b 1
    )
    echo Latest Bitcoin Core with a win64 build: !VERSION!
)
REM VERSION reaches here from the scrape, regex-constrained to
REM digits and dots, or from --version, quoted by whoever calls
REM this script -- quoting a caller argument does not stop it
REM holding a "&", so the set and echo below are what ISS 298
REM already quotes and delayed-expands for %ROOTDIR%.
set "FILE=bitcoin-%VERSION%-win64.zip"
set "BASE_URL=https://bitcoincore.org/bin/bitcoin-core-%VERSION%/"
set "URL=%BASE_URL%%FILE%"
set "CHECKSUM_URL=%BASE_URL%SHA256SUMS"
set "CHECKSUM_SIG_URL=%BASE_URL%SHA256SUMS.asc"
set "CHECKSUM_FILE=%ROOTDIR%\win\checksums.sha256"

set STATUS=0

echo Updating Bitcoin Core to !VERSION!...

tasklist /fi "imagename eq bitcoind.exe" | find /i "bitcoind.exe" >nul
if %errorlevel%==0 (
    echo Error: Bitcoin Core is running. Stop it before updating.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)
tasklist /fi "imagename eq bitcoin-qt.exe" | find /i "bitcoin-qt.exe" >nul
if %errorlevel%==0 (
    echo Error: Bitcoin Core is running. Stop it before updating.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

if "%DRY_RUN%"=="1" (
    call "%SCRIPT_DIR%lib.bat" :installed_version "%BIN_DIR%\bitcoin-qt.exe" "win/bin/bitcoin-qt.exe" "%CHECKSUM_FILE%" CURRENT
    echo --dry-run: nothing will be downloaded, verified or installed.
    echo Would install Bitcoin Core !VERSION! ^(currently installed: !CURRENT!^).
    echo Would fetch: !URL!
    echo Would verify against: !CHECKSUM_URL! ^(signed by !CHECKSUM_SIG_URL!^)
    where gpg >nul 2>&1
    REM Delayed expansion, not percent: this block sits inside the
    REM DRY_RUN block opened above, so percent expansion would read
    REM whatever errorlevel held when cmd.exe parsed that whole outer
    REM block, before where gpg ran -- see ISS 383.
    if !errorlevel!==0 (
        echo gpg: found.
        call "%SCRIPT_DIR%lib.bat" :warn_if_no_pubkeys
    ) else (
        echo gpg: not found -- verification would fail closed unless
        echo PORTANODE_ALLOW_UNVERIFIED=1 is set.
    )
    set ARCHIVE_LEN=
    REM Built as one physical line -- see win/scripts/utilities/lib.bat's
    REM :update_checksum comment (#144) on why a "^" split across a
    REM powershell -Command block's open quote is not a continuation.
    REM
    REM -TimeoutSec 30, the value latest-bitcoin-version.ps1 passes on
    REM its own archive HEAD probe: a HEAD the server accepts and then
    REM answers at its leisure holds --dry-run open for as long as the
    REM host chooses, and --dry-run is the side-effect-free preview.
    for /f "usebackq delims=" %%L in (`powershell -NoProfile -Command "& { try { (Invoke-WebRequest -Uri '%URL%' -Method Head -UseBasicParsing -TimeoutSec 30).Headers['Content-Length'] } catch { '' } }"`) do set "ARCHIVE_LEN=%%L"
    if defined ARCHIVE_LEN (
        set /a ARCHIVE_MB=!ARCHIVE_LEN!/1024/1024
        echo Archive size: !ARCHIVE_MB! MB ^(downloaded to local temp
        echo storage, not the removable disk^).
    ) else (
        REM Printed rather than the block falling silent: with no line at
        REM all, an estimate that could not be made reads the same as one
        REM nobody attempted. It names the absence rather than a cause,
        REM since the timeout above, a request that failed and a response
        REM carrying no Content-Length all reach here alike.
        echo Archive size: unknown ^(the HEAD request returned no
        echo Content-Length^).
    )
    set FREE_GB=
    for /f "usebackq delims=" %%F in (`powershell -NoProfile -ExecutionPolicy Bypass ^
      -File "%SCRIPT_DIR%free-space-gb.ps1" -Path "%ROOTDIR_ARG%"`) do set FREE_GB=%%F
    if defined FREE_GB (
        REM Delayed expansion, not percent: percent expansion runs before
        REM cmd.exe matches this block's parentheses, so a closing
        REM parenthesis in the mount point would end the block early.
        echo Free space at !ROOTDIR!: !FREE_GB! GB
    )
    popd >nul 2>&1
    exit /b 0
)

REM Download/verify/extract on the local disk (%TEMP%), never on the removable
REM volume; only the final, verified .exe files are copied onto win\bin.
REM Created here, after the --dry-run exit above, so a dry run never leaves
REM an empty directory behind.
set "TMPDIR=%TEMP%\portanode-bitcoin"
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
mkdir "%TMPDIR%"

echo Downloading !URL!...
set PGP_OK=0
REM Built as one physical line each -- see :update_checksum in lib.bat
REM (#144): a caret split across one of these blocks' open quote was a
REM literal character, not a continuation, so the goto :error guard that
REM follows never ran and a failed download went undetected.
REM
REM The one-line form alone is not enough: powershell.exe exits 0 after
REM an uncaught Invoke-WebRequest error -- measured on windows-latest,
REM a 404 -- so each block also wraps its request in try/catch and
REM calls exit 1 itself (#364). The catch prints the exception's own
REM message first: a catch that only exits leaves a failed download the
REM one failure here that says nothing about itself, where every other
REM failure below reaches :error with a message already printed, whether
REM by this file or by the helper it calls. Write-Host sends it to
REM stdout, so a run that fails this way still writes nothing to stderr.
powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; try { Invoke-WebRequest -Uri '%URL%' -OutFile '%TMPDIR%\%FILE%' -ErrorAction Stop } catch { Write-Host $_.Exception.Message; exit 1 } }" || goto :error
powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; try { Invoke-WebRequest -Uri '%CHECKSUM_URL%' -OutFile '%TMPDIR%\SHA256SUMS' -ErrorAction Stop } catch { Write-Host $_.Exception.Message; exit 1 } }" || goto :error
powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; try { Invoke-WebRequest -Uri '%CHECKSUM_SIG_URL%' -OutFile '%TMPDIR%\SHA256SUMS.asc' -ErrorAction Stop } catch { Write-Host $_.Exception.Message; exit 1 } }" || goto :error

call "%SCRIPT_DIR%lib.bat" :verify_pgp_signature "%TMPDIR%\SHA256SUMS.asc" "%TMPDIR%\SHA256SUMS" "SHA256SUMS" PGP_OK "%ROOTDIR%\keys\bitcoin-core.fingerprints"
if errorlevel 1 goto :error

REM One backslash, not two: cmd.exe passes a backslash through untouched,
REM and powershell.exe splits its command line by the Windows argument
REM rules, where a backslash is literal unless it precedes a double
REM quote. A doubled \\s+ therefore reaches the .NET regex engine as a
REM literal backslash followed by one or more s, and no SHA256SUMS line
REM holds a backslash.
REM Built as one physical line -- see :update_checksum in lib.bat (#144).
powershell -Command "& { $sum = Get-Content '%TMPDIR%\SHA256SUMS' | Select-String -Pattern '%FILE%' | Select-Object -First 1; if (-not $sum) { Write-Host 'Checksum entry not found.'; exit 1 } $expected = ($sum -split '\s+')[0].ToLower(); $actual = (Get-FileHash -Algorithm SHA256 '%TMPDIR%\%FILE%').Hash.ToLower(); if ($expected -ne $actual) { Write-Host 'Checksum failed.'; exit 1 } Write-Host '%FILE%: OK' }" || goto :error

REM Expand-Archive writes a non-terminating error and leaves
REM powershell.exe exiting 0 -- measured on windows-latest, an archive
REM that is absent and one whose central directory is corrupt -- so this
REM block carries the try/catch and the exit 1 of the downloads above
REM (#368). Without them the backup block below runs on a failed
REM extraction and overwrites win\bin\backup\bitcoin with the binaries
REM currently installed, leaving rollback-bitcoin.bat the version already
REM there to restore.
REM Built as one physical line -- see :update_checksum in lib.bat (#144).
powershell -Command "& { try { Expand-Archive -Force '%TMPDIR%\%FILE%' '%TMPDIR%\' -ErrorAction Stop } catch { Write-Host $_.Exception.Message; exit 1 } }" || goto :error

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
REM One physical line each, matching update-electrum.bat's own backup
REM line: a caret continuation between "if exist" and "copy" wrote
REM "' ' is not recognized" once per pair on windows-latest (#363).
if exist "%BIN_DIR%\bitcoin-qt.exe" copy /y "%BIN_DIR%\bitcoin-qt.exe" "%BACKUP_DIR%\" >nul
if exist "%BIN_DIR%\bitcoind.exe" copy /y "%BIN_DIR%\bitcoind.exe" "%BACKUP_DIR%\" >nul
if exist "%BIN_DIR%\bitcoin-cli.exe" copy /y "%BIN_DIR%\bitcoin-cli.exe" "%BACKUP_DIR%\" >nul
if exist "%BIN_DIR%\bitcoin-wallet.exe" copy /y "%BIN_DIR%\bitcoin-wallet.exe" "%BACKUP_DIR%\" >nul
if exist "%BIN_DIR%\bitcoin-tx.exe" copy /y "%BIN_DIR%\bitcoin-tx.exe" "%BACKUP_DIR%\" >nul
if exist "%BIN_DIR%\bitcoin-util.exe" copy /y "%BIN_DIR%\bitcoin-util.exe" "%BACKUP_DIR%\" >nul
if exist "%BIN_DIR%\bitcoin.exe" copy /y "%BIN_DIR%\bitcoin.exe" "%BACKUP_DIR%\" >nul

if not exist "%TMPDIR%\bitcoin-%VERSION%\bin\bitcoin-qt.exe" (
    echo Error: extracted binaries not found.
    goto :error
)
copy /y "%TMPDIR%\bitcoin-%VERSION%\bin\*.exe" "%BIN_DIR%\" >nul
if errorlevel 1 (
    echo Error: failed to install Bitcoin Core binaries.
    goto :error
)

if "%PGP_OK%"=="1" (
  call "%SCRIPT_DIR%lib.bat" :update_checksum "win/bin/bitcoin-qt.exe" "%VERSION%"
  call "%SCRIPT_DIR%lib.bat" :update_checksum "win/bin/bitcoind.exe" "%VERSION%"
  call "%SCRIPT_DIR%lib.bat" :update_checksum "win/bin/bitcoin-cli.exe" "%VERSION%"
  call "%SCRIPT_DIR%lib.bat" :update_checksum "win/bin/bitcoin-wallet.exe" "%VERSION%"
  call "%SCRIPT_DIR%lib.bat" :update_checksum "win/bin/bitcoin-tx.exe" "%VERSION%"
  call "%SCRIPT_DIR%lib.bat" :update_checksum "win/bin/bitcoin-util.exe" "%VERSION%"
  call "%SCRIPT_DIR%lib.bat" :update_checksum "win/bin/bitcoin.exe" "%VERSION%"
) else (
  echo Warning: PGP signature^(s^) not verified; skipping checksum update.
)

if "%PGP_OK%"=="1" (
  echo Verifying installed binaries against checksums.sha256...
  set "VERR=0"
  for %%E in (bitcoin-qt bitcoind bitcoin-cli bitcoin-wallet bitcoin-tx bitcoin-util bitcoin) do (
    call "%SCRIPT_DIR%lib.bat" :verify_checksum "win/bin/%%E.exe" "win/bin/%%E.exe"
    if errorlevel 1 set "VERR=1"
  )
  if "!VERR!"=="1" (
    echo Error: post-install verification failed ^(filesystem corruption?^).
    goto :error
  )
  echo All Bitcoin binaries verified.
)

echo Bitcoin Core updated to !VERSION!

goto :cleanup

:error
echo Update failed.
set STATUS=1

:cleanup
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
popd >nul 2>&1
REM Above endlocal, which discards SCRIPT_DIR: measured on
REM windows-latest, one line below it the same call answers
REM '"..\root.bat"' is not recognized as an internal or external
REM command, and no wait happens.
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
REM One physical line: cmd.exe expands %STATUS% when it reads this
REM line, before the endlocal on the same line runs, where a separate
REM "exit /b %STATUS%" line would read it after endlocal had already
REM discarded it -- measured on windows-latest, a failed run then
REM exiting 0 (#362).
endlocal & exit /b %STATUS%
