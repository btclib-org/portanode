@echo off
setlocal
REM Launch Bitcoin Core daemon for regtest as Alice (clean start).
REM Removes regtest data directory.
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

if not exist "%ROOTDIR%\win\bin\bitcoind.exe" (
    echo Error: Binary not found at "win\bin\bitcoind.exe"
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

if not exist "%ROOTDIR%\win\bin\bitcoin-cli.exe" (
    echo Error: Binary not found at "win\bin\bitcoin-cli.exe"
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

call "%SCRIPT_DIR%lib.bat" :require_datadir_free ^
  "bitcoin-datadir" -regtest
if errorlevel 1 (
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

echo WARNING: This will delete regtest data.
echo Press Enter to continue or Ctrl+C to cancel.
pause

call "%SCRIPT_DIR%lib.bat" :require_deleted "bitcoin-datadir\regtest"
if errorlevel 1 (
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

set "DATADIR=%ROOTDIR%\bitcoin-datadir"
set "NETDIR=%DATADIR%\regtest"
set "BLOCKCHAINDIR=%NETDIR%\blocks"
REM Bitcoin Core creates the wallets subfolder along with the network
REM directory itself, and wallet code then uses it; wallet code never
REM creates one, so the network directory is the wallet directory only
REM where it already exists without a wallets subfolder beside it.
REM Computed after the wipe above rather than beside the ROOTDIR echo: a
REM network directory standing there without a wallets subfolder is the one
REM state that answers with the directory itself, and the wipe is what takes
REM that state away, so reading it earlier would answer for a directory about
REM to be deleted.
set "WALLETDIR=%NETDIR%\wallets"
if exist "%NETDIR%\" if not exist "%NETDIR%\wallets\" set "WALLETDIR=%NETDIR%"
echo DATADIR is "%DATADIR%"
echo BLOCKCHAINDIR is "%BLOCKCHAINDIR%"
echo WALLETDIR is "%WALLETDIR%"

REM Measured on windows-latest: see regtest-18444-Alice-cli.bat for why a
REM "^" split here is swallowed as literal text inside an open quote, and
REM no bitcoind process starts. Built in a variable instead, so the whole
REM argument is one physical line.
REM ROOTDIR/DATADIR quoting: see regtest-18444-Alice-cli.bat (#145) for why
REM each is wrapped in its own quote pair here, and lib.bat's :cli_console
REM for why the CLI console below is a routine there -- ROOTDIR is not this
REM repository's to choose, and a mount path can carry a "&" or a space.
set BITCOIND_CMD="%ROOTDIR%\win\bin\bitcoind.exe" -uacomment=%~n0
set BITCOIND_CMD=%BITCOIND_CMD% -datadir="%DATADIR%"
set BITCOIND_CMD=%BITCOIND_CMD% -regtest -rpcallowip=127.0.0.1
set BITCOIND_CMD=%BITCOIND_CMD% -addnode=localhost:18555
set BITCOIND_CMD=%BITCOIND_CMD% -addnode=localhost:18666
start "" cmd /k %BITCOIND_CMD%
start "" cmd /k call "%SCRIPT_DIR%lib.bat" :cli_console "%~n0" "-regtest"
