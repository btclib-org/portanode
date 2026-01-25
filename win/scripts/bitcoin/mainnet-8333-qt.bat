REM Launch Bitcoin Core GUI for mainnet.
REM Data directory: bitcoin-datadir
REM P2P port: 8333
REM 
set ROOTDIR=%~dp0..\..\..
echo ROOTDIR is %ROOTDIR%

start %ROOTDIR%\win\bin\bitcoin-qt.exe -uacomment=%~n0 ^
-datadir=%ROOTDIR%\bitcoin-datadir