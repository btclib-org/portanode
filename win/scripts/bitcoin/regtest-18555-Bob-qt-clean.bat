REM Launch Bitcoin Core GUI for regtest as Bob (clean start).
REM Removes and recreates regtest_bob data directory.
REM Data directory: bitcoin-datadir\regtest_bob
REM P2P port: 18555
REM Network: regtest
REM Connects to: localhost:18444 (Alice), localhost:18666 (Carol)
REM 
set ROOTDIR=%~dp0..\..\..
echo ROOTDIR is %ROOTDIR%

rmdir %ROOTDIR%\bitcoin-datadir\regtest_bob /s /q
mkdir %ROOTDIR%\bitcoin-datadir\regtest_bob

start %ROOTDIR%\win\bin\bitcoin-qt.exe -uacomment=%~n0 ^
-datadir=%ROOTDIR%\bitcoin-datadir\regtest_bob -regtest -port=18555 ^
-addnode=localhost:18444 -addnode=localhost:18666
