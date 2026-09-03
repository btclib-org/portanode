@echo off
setlocal
REM Launch Bitcoin Core daemon for regtest as Alice.
REM Data directory: bitcoin-datadir
REM P2P port: 18444
REM Network: regtest
REM RPC: allowed from 127.0.0.1
REM Starts daemon and CLI command prompts.
REM Connects to: localhost:18555 (Bob), localhost:18666 (Carol)
REM
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
echo ROOTDIR is "%ROOTDIR%"
set "DATADIR=%ROOTDIR%\bitcoin-datadir"
set "NETDIR=%DATADIR%\regtest"
set "BLOCKCHAINDIR=%NETDIR%\blocks"
REM Bitcoin Core creates the wallets subfolder along with the network
REM directory itself, and wallet code then uses it; wallet code never
REM creates one, so the network directory is the wallet directory only
REM where it already exists without a wallets subfolder beside it.
set "WALLETDIR=%NETDIR%\wallets"
if exist "%NETDIR%\" if not exist "%NETDIR%\wallets\" set "WALLETDIR=%NETDIR%"
echo DATADIR is "%DATADIR%"
echo BLOCKCHAINDIR is "%BLOCKCHAINDIR%"
echo WALLETDIR is "%WALLETDIR%"

if not exist "%ROOTDIR%\win\bin\bitcoind.exe" (
    echo Error: Binary not found at "win\bin\bitcoind.exe"
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

REM bitcoin-cli.exe is checked here rather than left to CLI_CMD below,
REM whose doskey macro names the bare binary after a "cd /d" into
REM win\bin: cmd looks in that directory first and in PATH after.
REM Measured on windows-latest with another bitcoin-cli.exe on PATH,
REM "where bitcoin-cli.exe" run from win\bin answers with the folder's
REM copy where there is one and with the PATH copy where there is not,
REM and the bare name runs whichever it answered with -- so without
REM this guard btc would drive this folder's datadir through a binary
REM the folder never verified.
if not exist "%ROOTDIR%\win\bin\bitcoin-cli.exe" (
    echo Error: Binary not found at "win\bin\bitcoin-cli.exe"
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

rem rmdir "%ROOTDIR%\bitcoin-datadir\regtest" /s /q

REM Measured on windows-latest: a "^" at the end of a line continues a
REM batch file's line to the next only while cmd's quote state is closed
REM -- inside an open quote a "^" is a literal character instead, and the
REM logical line ends right there. This block's own quoting leaves the
REM state open partway through, so the caret split below was swallowed as
REM text rather than read as a continuation: cmd ran the fragment that
REM left it with, caret included, instead of bitcoind.exe with its
REM arguments, and no bitcoind process started at all. Built in a
REM variable instead, so the whole argument is one physical line and no
REM "^" is ever read inside an open quote.
REM ROOTDIR/DATADIR quoting (#145): ROOTDIR is not this repository's to
REM choose -- it is wherever the folder is mounted -- and a directory name
REM may legally carry a "&", which cmd.exe reads as a command separator
REM anywhere it is not inside an open quote. Measured on windows-latest
REM with ROOTDIR carrying one: unquoted, BITCOIND_CMD split there and cmd
REM tried to run the fragment after the "&" as its own command; the
REM %ROOTDIR% and %DATADIR% below are each now inside their own quote
REM pair. CLI_CMD's own "&"s are not incidental -- they chain cd, title
REM and doskey for cmd /k to run -- so CLI_CMD stays one continuous quote
REM with no interior close/reopen, which keeps ROOTDIR, DATADIR and both
REM "&"s inside it instead of trying to quote ROOTDIR and DATADIR on their
REM own the way BITCOIND_CMD does: closing and reopening the quote around
REM them left this same "&" unprotected again, splitting the SET line
REM itself before CLI_CMD was even fully assigned.
set BITCOIND_CMD="%ROOTDIR%\win\bin\bitcoind.exe" -uacomment=%~n0
set BITCOIND_CMD=%BITCOIND_CMD% -datadir="%DATADIR%"
set BITCOIND_CMD=%BITCOIND_CMD% -regtest -rpcallowip=127.0.0.1
set BITCOIND_CMD=%BITCOIND_CMD% -addnode=localhost:18555
set BITCOIND_CMD=%BITCOIND_CMD% -addnode=localhost:18666
start "" cmd /k %BITCOIND_CMD%
set CLI_CMD="cd /d %ROOTDIR%\win\bin & title %~n0 & doskey btc=bitcoin-cli.exe -regtest -datadir=%DATADIR% $*"
start "" cmd /k %CLI_CMD%
