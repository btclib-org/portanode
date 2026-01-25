REM set ROOTDIR=%~dp0..\..
REM echo ROOTDIR is %ROOTDIR%
REM 
REM rmdir %ROOTDIR%\core_datadir\regtest /s /q
REM 
REM start cmd /k %ROOTDIR%\core_bin\win\bin\bitcoind.exe -uacomment=%~n0 ^
REM -datadir=%ROOTDIR%\core_datadir -regtest -rpcallowip=127.0.0.1 ^
REM -addnode=localhost:18555 -addnode=localhost:18666
REM start cmd /k "cd %~dp0bin & title %~n0 & doskey btc=bitcoin-cli.exe -regtest $*"
