@echo off
REM Shared guard for the Electrum launchers beside this file, called by label:
REM     call "%SCRIPT_DIR%lib.bat" :label [arguments]
REM It prints its own message and returns 1 where the caller must stop, so a
REM caller writes: if errorlevel 1 exit /b 1
set "ACTION=%~1"
set "LIB_DIR=%~dp0"
if "%ACTION%"=="" goto :eof
shift /1
goto %ACTION%

:require_non_portable_build
REM Refuse to start Electrum's portable Windows build, which discards the
REM --dir every launcher beside this file passes. run_electrum assigns
REM electrum_path itself, after the command line has been parsed, whenever the
REM frozen executable carries pyinstaller's is_portable datum, and the value it
REM assigns is electrum_data under the working directory. A .bat opened from
REM Explorer runs with its own directory as the working directory, so an
REM unguarded start writes the wallet under win\scripts\electrum instead of
REM into electrum-datadir; started from a console sitting elsewhere, it writes
REM the wallet off this volume altogether, which is the outcome this folder
REM exists to avoid.
REM
REM Measured on windows-latest with electrum-4.8.1-portable.exe: --dir pointed
REM at an existing empty directory left it empty and created
REM <working directory>\electrum_data\wallets\default_wallet instead, and
REM dropping --dir from the same command line changed nothing. ELECTRUMDIR in
REM the environment does not reach it either, user_dir being consulted only
REM where electrum_path is unset. The standalone build of the same release,
REM given the same argument, created the wallet where --dir named it, which is
REM why update-electrum.bat fetches that one.
REM
REM is_portable is an archive entry name, and pyinstaller stores entry names
REM uncompressed, so it reads out of the portable executable as text and out of
REM the standalone one not at all, measured against both 4.8.1 files. A
REM standalone build that happened to hold the name would be refused here
REM rather than started; that direction fails in the open, where the other
REM one is a wallet written somewhere nobody was told about.
setlocal
set "ELECTRUM_EXE=%~1"
REM The control, and it runs first because the search below is one whose
REM informative answer is a miss: a search that did not read the file answers
REM 1, as one that read it and did not find the string does. So a miss on
REM is_portable says the datum is absent only once something the file
REM certainly holds has been found in it. run_electrum is the frozen main
REM script's own entry name and reads out of both builds of 4.8.1.
REM
REM How every search of a file in the Windows scripts reads it, said once.
REM Each reads the file from standard input, findstr ... < file. Measured on
REM windows-latest, findstr cannot open a file named on its command line where
REM the path holds a letter outside the ANSI code page, such as U+0142 or a CJK
REM letter, whatever chcp says, and answers 1 as for a missing file. cmd.exe
REM opens a redirected file itself, and reads the same file under every path
REM measured. A redirection cmd.exe cannot open leaves the errorlevel as it was,
REM which would read as a found string after a zero, so each search whose answer
REM is read follows "cmd /d /c exit 1", which sets the answer an unread file
REM gives. A line of 131071 bytes or more, before its line end, makes findstr
REM print "FINDSTR: Line N is too long." on standard error and can make it miss
REM a string in that line; a shorter line does not, and a file named on the
REM command line is searched whole. Both searches find the same strings in both
REM builds of 4.8.1. The length of a file's longest line is the Maximum that
REM PowerShell 7 prints for this, with F the file:
REM   (Get-Content -Raw -Encoding Latin1 $F)-split"`n"|measure Length -Max
REM It prints 12599 for electrum-4.8.1-portable.exe.
REM
REM Both searches run with System32 as the current directory, and their
REM answers are read once it is changed back: root.bat's :leave_folder
REM says why.
call "%LIB_DIR%..\root.bat" :leave_folder
if errorlevel 1 exit /b 1
cmd /d /c exit 1
findstr /m /c:"run_electrum" < "%ELECTRUM_EXE%" >nul
set "CONTROL_RC=%ERRORLEVEL%"
cmd /d /c exit 1
findstr /m /c:"is_portable" < "%ELECTRUM_EXE%" >nul
set "PORTABLE_RC=%ERRORLEVEL%"
popd >nul 2>&1
if not "%CONTROL_RC%"=="0" (
    echo Error: "%ELECTRUM_EXE%" could not be read as an Electrum build, so
    echo whether it keeps its data directory in electrum-datadir cannot be
    echo told. Run win\scripts\utilities\update-electrum.bat to install one.
    exit /b 1
)
if not "%PORTABLE_RC%"=="0" exit /b 0
echo Error: "%ELECTRUM_EXE%" is Electrum's portable Windows build.
echo It ignores --dir and keeps its data directory under the directory it
echo is started from, so this launcher cannot hold the wallet in
echo electrum-datadir.
echo Run win\scripts\utilities\update-electrum.bat to install the standalone
echo build, whose data directory is the one --dir names.
exit /b 1
