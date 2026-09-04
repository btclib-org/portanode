@echo off
setlocal enabledelayedexpansion
REM Update Electrum version (Windows)

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
set "BACKUP_DIR=%BIN_DIR%\backup\electrum"
set "CHECKSUM_FILE=%ROOTDIR%\win\checksums.sha256"
set "TMPDIR=%TEMP%\portanode-electrum"
set STATUS=0

echo Updating Electrum...

tasklist /fi "imagename eq electrum.exe" | find /i "electrum.exe" >nul
if %errorlevel%==0 (
    echo Error: Electrum is running. Stop it before updating.
    popd >nul 2>&1
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

if defined VERSION_OVERRIDE (
    set "VERSION=%VERSION_OVERRIDE%"
    echo Requested Electrum version: !VERSION!
) else (
    set VERSION=
    for /f "usebackq delims=" %%V in (`powershell -NoProfile -ExecutionPolicy Bypass ^
      -File "%SCRIPT_DIR%latest-electrum-version.ps1"`) do set VERSION=%%V
    REM latest-electrum-version.ps1 prints INDEX_UNREACHABLE when it
    REM could not read the release index, an expired -TimeoutSec
    REM included, and nothing when it read the index and found no version
    REM listed in it; its own header says why the two are told apart on
    REM stdout. Delayed expansion here for the reason the REM below the
    REM block gives.
    if "!VERSION!"=="INDEX_UNREACHABLE" (
        echo Error: failed to fetch the release index from
        echo download.electrum.org ^(Invoke-WebRequest -TimeoutSec 300^).
        goto :error
    )
    REM "if not defined", not a string test on an expanded VERSION:
    REM cmd.exe expands a percent variable when it parses the whole else
    REM block, before the for /f above has run, so a string test reads
    REM what VERSION held on entry and takes this branch whatever the
    REM scrape returned. Clearing VERSION above is what leaves "defined"
    REM answering for the scrape and not for an inherited environment.
    if not defined VERSION (
        echo Error: Failed to determine latest Electrum version.
        goto :error
    )
    echo Latest Electrum version: !VERSION!
)

REM The standalone build, not electrum-<version>-portable.exe. The portable
REM one assigns its own data directory -- electrum_data under the working
REM directory -- after the command line has been parsed, discarding the --dir
REM every launcher under win\scripts\electrum\ passes, so the wallet lands
REM wherever the launcher was started from rather than in electrum-datadir on
REM this volume. Measured on windows-latest with 4.8.1: the portable build
REM left the directory --dir named empty and wrote the wallet under the
REM working directory, and the standalone build of the same release wrote it
REM where --dir named. The .asc beside the standalone file carries a signature
REM from the key keys\electrum.fingerprints pins, as the portable one's does,
REM so the verification below is unchanged. win\scripts\electrum\lib.bat
REM refuses a portable build already installed, this file's change reaching
REM only an installation made after it.
REM VERSION reaches here from the scrape, regex-constrained to
REM digits and dots, or from --version, quoted by whoever calls
REM this script -- quoting a caller argument does not stop it
REM holding a "&", so the set and echo below are what ISS 298
REM already quotes and delayed-expands for %ROOTDIR%.
set "FILE=electrum-%VERSION%.exe"
set "SIG_FILE=%FILE%.asc"
set "BASE_URL=https://download.electrum.org/%VERSION%/"
set "URL=%BASE_URL%%FILE%"

if "%DRY_RUN%"=="1" (
    call "%SCRIPT_DIR%lib.bat" :installed_version "%BIN_DIR%\electrum.exe" "win/bin/electrum.exe" "%CHECKSUM_FILE%" CURRENT
    echo --dry-run: nothing will be downloaded, verified or installed.
    echo Would install Electrum !VERSION! ^(currently installed: !CURRENT!^).
    echo Would fetch: !URL!
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
    REM Built as one physical line -- see :update_checksum in lib.bat
    REM (#144) on why a caret split across an open quote is not a
    REM continuation.
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

REM Download/verify on the local disk (%TEMP%), never on the removable volume;
REM only the final, verified electrum.exe is copied onto win\bin. Created
REM here, after the --dry-run exit above, so a dry run never leaves an empty
REM directory behind.
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
REM a 404, on update-bitcoin.bat's own downloads -- so each block also
REM wraps its request in try/catch and calls exit 1 itself (#364). The
REM catch prints the exception's own message first: a catch that only
REM exits leaves a failed download the one failure here that says
REM nothing about itself, where every other failure below reaches
REM :error with a message already printed, whether by this file or by
REM the helper it calls. Write-Host sends it to stdout, so a run that
REM fails this way still writes nothing to stderr.
powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; try { Invoke-WebRequest -Uri '%URL%' -OutFile '%TMPDIR%\%FILE%' -ErrorAction Stop } catch { Write-Host $_.Exception.Message; exit 1 } }" || goto :error
powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; try { Invoke-WebRequest -Uri '%URL%.asc' -OutFile '%TMPDIR%\%SIG_FILE%' -ErrorAction Stop } catch { Write-Host $_.Exception.Message; exit 1 } }" || goto :error

call "%SCRIPT_DIR%lib.bat" :verify_pgp_signature "%TMPDIR%\%SIG_FILE%" "%TMPDIR%\%FILE%" "Electrum" PGP_OK "%ROOTDIR%\keys\electrum.fingerprints"
if errorlevel 1 goto :error

if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
if exist "%BIN_DIR%\electrum.exe" copy /y "%BIN_DIR%\electrum.exe" "%BACKUP_DIR%\" >nul

if not exist "%TMPDIR%\%FILE%" (
    echo Error: downloaded file not found.
    goto :error
)
copy /y "%TMPDIR%\%FILE%" "%BIN_DIR%\electrum.exe" >nul
if errorlevel 1 (
    echo Error: failed to install Electrum.
    goto :error
)

if "%PGP_OK%"=="1" (
  call "%SCRIPT_DIR%lib.bat" :update_checksum "win/bin/electrum.exe" "%VERSION%"
  echo Verifying installed Electrum against checksums.sha256...
  call "%SCRIPT_DIR%lib.bat" :verify_checksum "win/bin/electrum.exe" "win/bin/electrum.exe"
  if errorlevel 1 (
    echo Error: post-install verification failed ^(filesystem corruption?^).
    goto :error
  )
  echo Electrum verified.
) else (
  echo Warning: PGP signature^(s^) not verified; skipping checksum update.
)

echo Electrum updated to !VERSION!

goto :cleanup

:error
echo Update failed.
set STATUS=1

:cleanup
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
popd >nul 2>&1
REM Above endlocal, for the reason update-bitcoin.bat's :cleanup gives.
call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
REM One physical line, for the reason update-bitcoin.bat's own
REM endlocal & exit /b line gives (#362).
endlocal & exit /b %STATUS%
