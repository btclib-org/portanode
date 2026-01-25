REM Launch Bitcoin Core GUI for testnet3.
REM Data directory: bitcoin-datadir
REM P2P port: 18333
REM Network: testnet
REM 
set ROOTDIR=%~dp0..\..\..
echo ROOTDIR is %ROOTDIR%

start %ROOTDIR%\win\bin\bitcoin-qt.exe -uacomment=%~n0 ^
-datadir=%ROOTDIR%\bitcoin-datadir -testnet