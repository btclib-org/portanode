REM Launch Bitcoin Core GUI for testnet3.
REM Data directory: bitcoin-datadir
REM P2P port: 18333
REM Network: testnet
REM 
set "ROOTDIR=%~dp0..\..\.."
if defined PORTANODE_ROOT set "ROOTDIR=%PORTANODE_ROOT%"
echo ROOTDIR is "%ROOTDIR%"

if not exist "%ROOTDIR%\win\bin\bitcoin-qt.exe" (
    echo Error: Binary not found at "%ROOTDIR%\win\bin\bitcoin-qt.exe"
    exit /b 1
)

start "" "%ROOTDIR%\win\bin\bitcoin-qt.exe" -uacomment=%~n0 ^
-datadir="%ROOTDIR%\bitcoin-datadir" -testnet
