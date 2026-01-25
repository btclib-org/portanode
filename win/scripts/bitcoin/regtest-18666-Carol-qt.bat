REM Launch Bitcoin Core GUI for regtest as Carol.
REM Data directory: bitcoin-datadir\regtest_carol
REM P2P port: 18666
REM Network: regtest
REM Creates data directory if not exists.
REM Connects to: localhost:18444 (Alice), localhost:18555 (Bob)
REM 
set ROOTDIR=%~dp0..\..\..
echo ROOTDIR is %ROOTDIR%

if not exist %ROOTDIR%\bitcoin-datadir\regtest_carol\ mkdir %ROOTDIR%\bitcoin-datadir\regtest_carol


start %ROOTDIR%\win\bin\bitcoin-qt.exe -uacomment=%~n0 ^
-datadir=%ROOTDIR%\bitcoin-datadir\regtest_carol -regtest -port=18666 ^
-addnode=localhost:18444 -addnode=localhost:18555