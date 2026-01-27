REM Launch Bitcoin Core GUI for regtest as Alice (clean start).
REM Removes and recreates regtest data directory.
REM Data directory: bitcoin-datadir
REM P2P port: 18444
REM Network: regtest
REM Connects to: localhost:18555 (Bob), localhost:18666 (Carol)
REM 
set "ROOTDIR=%~dp0..\..\.."
if defined PORTANODE_ROOT set "ROOTDIR=%PORTANODE_ROOT%"
echo ROOTDIR is "%ROOTDIR%"

if not exist "%ROOTDIR%\win\bin\bitcoin-qt.exe" (
    echo Error: Binary not found
    exit /b 1
)

echo WARNING: This will delete regtest data. Press any key to continue or Ctrl+C to cancel
pause

rmdir "%ROOTDIR%\bitcoin-datadir\regtest" /s /q

start "" "%ROOTDIR%\win\bin\bitcoin-qt.exe" ^
  -uacomment=%~n0 ^
  -datadir="%ROOTDIR%\bitcoin-datadir" ^
  -regtest ^
  -addnode=localhost:18555 ^
  -addnode=localhost:18666
