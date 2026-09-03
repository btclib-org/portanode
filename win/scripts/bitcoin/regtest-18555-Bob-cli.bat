@echo off
setlocal
REM Launch Bitcoin Core daemon for regtest as Bob.
REM Data directory: bitcoin-datadir\regtest_bob
REM P2P port: 18555
REM RPC port: 18554
REM Network: regtest
REM RPC: allowed from 127.0.0.1
REM Creates data directory if not exists.
REM Starts daemon and CLI command prompts.
REM Connects to: localhost:18444 (Alice), localhost:18666 (Carol)
REM
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%..\root.bat" :resolve_root "%SCRIPT_DIR%" ROOTDIR
echo ROOTDIR is "%ROOTDIR%"
set "DATADIR=%ROOTDIR%\bitcoin-datadir\regtest_bob"
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

if not exist "%ROOTDIR%\win\bin\bitcoin-cli.exe" (
    echo Error: Binary not found at "win\bin\bitcoin-cli.exe"
    call "%SCRIPT_DIR%..\root.bat" :pause_if_own_console "%~nx0"
    exit /b 1
)

if not exist "%ROOTDIR%\bitcoin-datadir\regtest_bob\" (
    mkdir "%ROOTDIR%\bitcoin-datadir\regtest_bob"
)

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
set BITCOIND_CMD=%BITCOIND_CMD% -regtest -port=18555 -rpcport=18554 -rpcallowip=127.0.0.1
set BITCOIND_CMD=%BITCOIND_CMD% -addnode=localhost:18444
set BITCOIND_CMD=%BITCOIND_CMD% -addnode=localhost:18666
start "" cmd /k %BITCOIND_CMD%
start "" cmd /k call "%SCRIPT_DIR%lib.bat" :cli_console "%~n0" "-regtest -rpcport=18554"
