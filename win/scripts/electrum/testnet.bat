REM Launch Electrum for testnet.
REM Data directory: electrum-datadir
REM Network: testnet
REM 
set ROOTDIR=%~dp0..\..\..
echo ROOTDIR is %ROOTDIR%

start %ROOTDIR%\win\bin\electrum.exe ^
--dir %ROOTDIR%\electrum-datadir --testnet
