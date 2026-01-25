REM Launch Electrum for mainnet, connecting only to local server.
REM Data directory: electrum-datadir
REM Network: mainnet
REM Server: localhost:50002:s (one server only)
REM 
set ROOTDIR=%~dp0..\..\..
echo ROOTDIR is %ROOTDIR%

start %ROOTDIR%\win\bin\electrum.exe --dir %ROOTDIR%\electrum-datadir ^
--oneserver --server localhost:50002:s
