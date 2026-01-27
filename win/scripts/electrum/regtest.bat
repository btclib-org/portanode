REM Launch Electrum for regtest.
REM Data directory: electrum-datadir
REM Network: regtest
REM 
set "ROOTDIR=%~dp0..\..\.."
if defined PORTANODE_ROOT set "ROOTDIR=%PORTANODE_ROOT%"
echo ROOTDIR is "%ROOTDIR%"

if not exist "%ROOTDIR%\win\bin\electrum.exe" (
    echo Error: Binary not found at "%ROOTDIR%\win\bin\electrum.exe"
    exit /b 1
)

start "" "%ROOTDIR%\win\bin\electrum.exe" ^
  --dir "%ROOTDIR%\electrum-datadir" ^
  --regtest
