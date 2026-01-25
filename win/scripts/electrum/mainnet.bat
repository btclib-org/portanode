REM Launch Electrum for mainnet.
REM Data directory: electrum-datadir
REM Network: mainnet
REM 
set ROOTDIR=%~dp0..\..\..
echo ROOTDIR is %ROOTDIR%

start %ROOTDIR%\win\bin\electrum.exe --dir %ROOTDIR%\electrum-datadir
