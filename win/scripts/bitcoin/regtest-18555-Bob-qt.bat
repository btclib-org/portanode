REM Launch Bitcoin Core GUI for regtest as Bob.
REM Data directory: bitcoin-datadir\regtest_bob
REM P2P port: 18555
REM Network: regtest
REM Creates data directory if not exists.
REM Connects to: localhost:18444 (Alice), localhost:18666 (Carol)
REM 
set "ROOTDIR=%~dp0..\..\.."
if defined PORTANODE_ROOT set "ROOTDIR=%PORTANODE_ROOT%"
echo ROOTDIR is "%ROOTDIR%"

if not exist "%ROOTDIR%\win\bin\bitcoin-qt.exe" (
    echo Error: Binary not found
    exit /b 1
)

if not exist "%ROOTDIR%\bitcoin-datadir\regtest_bob\" (
    mkdir "%ROOTDIR%\bitcoin-datadir\regtest_bob"
)

start "" "%ROOTDIR%\win\bin\bitcoin-qt.exe" ^
  -uacomment=%~n0 ^
  -datadir="%ROOTDIR%\bitcoin-datadir\regtest_bob" ^
  -regtest ^
  -port=18555 ^
  -addnode=localhost:18444 ^
  -addnode=localhost:18666
