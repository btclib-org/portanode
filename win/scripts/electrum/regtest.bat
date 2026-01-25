REM Launch Electrum for regtest.
REM Data directory: electrum-datadir
REM Network: regtest
REM 
set ROOTDIR=%~dp0..\..\..
echo ROOTDIR is %ROOTDIR%

start %ROOTDIR%\win\bin\electrum.exe --dir %ROOTDIR%\electrum-datadir --reg
