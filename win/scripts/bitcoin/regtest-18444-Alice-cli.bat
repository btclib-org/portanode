REM Launch Bitcoin Core daemon for regtest as Alice.
REM Data directory: bitcoin-datadir
REM P2P port: 18444
REM Network: regtest
REM RPC: allowed from 127.0.0.1
REM Starts daemon and CLI command prompts.
REM Connects to: localhost:18555 (Bob), localhost:18666 (Carol)
REM 
set "ROOTDIR=%~dp0..\..\.."
if defined PORTANODE_ROOT set "ROOTDIR=%PORTANODE_ROOT%"
echo ROOTDIR is "%ROOTDIR%"

if not exist "%ROOTDIR%\win\bin\bitcoind.exe" (
    echo Error: Binary not found at "%ROOTDIR%\win\bin\bitcoind.exe"
    exit /b 1
)

rem rmdir "%ROOTDIR%\bitcoin-datadir\regtest" /s /q

start "" cmd /k ^
  "\"%ROOTDIR%\\win\\bin\\bitcoind.exe\" -uacomment=%~n0 ^
  -datadir=\"%ROOTDIR%\\bitcoin-datadir\" ^
  -regtest -rpcallowip=127.0.0.1 ^
  -addnode=localhost:18555 ^
  -addnode=localhost:18666"
start "" cmd /k ^
  "cd /d \"%ROOTDIR%\\win\\bin\" ^& ^
  title %~n0 ^& ^
  doskey btc=bitcoin-cli.exe -regtest -datadir=\"%ROOTDIR%\\bitcoin-datadir\" $*"
