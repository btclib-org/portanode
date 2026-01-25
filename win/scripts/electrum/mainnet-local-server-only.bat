REM Launch Electrum for mainnet, connecting only to local server.
REM Data directory: electrum-datadir
REM Network: mainnet
REM Server: localhost:50002:s (one server only)
REM 
set "ROOTDIR=%~dp0..\..\.."
if defined PORTANODE_ROOT set "ROOTDIR=%PORTANODE_ROOT%"
echo ROOTDIR is "%ROOTDIR%"

if not exist "%ROOTDIR%\win\bin\electrum.exe" (
    echo Error: Binary not found at "%ROOTDIR%\win\bin\electrum.exe"
    exit /b 1
)

start "" "%ROOTDIR%\win\bin\electrum.exe" --dir "%ROOTDIR%\electrum-datadir" ^
--oneserver --server localhost:50002:s
