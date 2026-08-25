@echo off
setlocal enabledelayedexpansion
REM Update Electrum version (Windows)

set SCRIPT_DIR=%~dp0
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
exit /b 1
:args_done

pushd "%ROOTDIR%" >nul 2>&1

set "BIN_DIR=%ROOTDIR%\win\bin"
set "BACKUP_DIR=%BIN_DIR%\backup\electrum"
set CHECKSUM_FILE=%ROOTDIR%\win\checksums.sha256
set "TMPDIR=%TEMP%\portanode-electrum"
set STATUS=0

echo Updating Electrum...

tasklist /fi "imagename eq electrum.exe" | find /i "electrum.exe" >nul
if %errorlevel%==0 (
    echo Error: Electrum is running. Stop it before updating.
    popd >nul 2>&1
    exit /b 1
)

if defined VERSION_OVERRIDE (
    set "VERSION=%VERSION_OVERRIDE%"
    echo Requested Electrum version: !VERSION!
) else (
    set VERSION=
    for /f "usebackq delims=" %%V in (`powershell -NoProfile -ExecutionPolicy Bypass ^
      -File "%SCRIPT_DIR%latest-electrum-version.ps1"`) do set VERSION=%%V
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

set FILE=electrum-%VERSION%-portable.exe
set SIG_FILE=%FILE%.asc
set BASE_URL=https://download.electrum.org/%VERSION%/
set URL=%BASE_URL%%FILE%

if "%DRY_RUN%"=="1" (
    call "%SCRIPT_DIR%lib.bat" :installed_version "%BIN_DIR%\electrum.exe" "win/bin/electrum.exe" "%CHECKSUM_FILE%" CURRENT
    echo --dry-run: nothing will be downloaded, verified or installed.
    echo Would install Electrum %VERSION% ^(currently installed: !CURRENT!^).
    echo Would fetch: %URL%
    where gpg >nul 2>&1
    if %errorlevel%==0 (
        echo gpg: found.
        call "%SCRIPT_DIR%lib.bat" :warn_if_no_pubkeys
    ) else (
        echo gpg: not found -- verification would fail closed unless
        echo PORTANODE_ALLOW_UNVERIFIED=1 is set.
    )
    set ARCHIVE_LEN=
    for /f "usebackq delims=" %%L in (`powershell -NoProfile -Command ^
      "& { try { (Invoke-WebRequest -Uri '%URL%' -Method Head ^
      -UseBasicParsing).Headers['Content-Length'] } catch { '' } }"`) ^
      do set ARCHIVE_LEN=%%L
    if defined ARCHIVE_LEN (
        set /a ARCHIVE_MB=!ARCHIVE_LEN!/1024/1024
        echo Archive size: !ARCHIVE_MB! MB ^(downloaded to local temp
        echo storage, not the removable disk^).
    )
    set FREE_GB=
    for /f "usebackq delims=" %%F in (`powershell -NoProfile -ExecutionPolicy Bypass ^
      -File "%SCRIPT_DIR%free-space-gb.ps1" -Path "%ROOTDIR_ARG%"`) do set FREE_GB=%%F
    if defined FREE_GB (
        echo Free space at %ROOTDIR%: !FREE_GB! GB
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

echo Downloading %URL%...
set PGP_OK=0
powershell -Command ^
  "& { $ProgressPreference = 'SilentlyContinue'; ^
  Invoke-WebRequest -Uri '%URL%' -OutFile '%TMPDIR%\%FILE%' }" ^
  || goto :error
powershell -Command ^
  "& { $ProgressPreference = 'SilentlyContinue'; ^
  Invoke-WebRequest -Uri '%URL%.asc' ^
  -OutFile '%TMPDIR%\%SIG_FILE%' }" ^
  || goto :error

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
  echo Warning: PGP signature(s) not verified; skipping checksum update.
)

echo Electrum updated to %VERSION%

goto :cleanup

:error
echo Update failed.
set STATUS=1

:cleanup
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
popd >nul 2>&1
endlocal
exit /b %STATUS%
