REM set ROOTDIR=%~dp0..\..
REM echo ROOTDIR is %ROOTDIR%
REM 
REM if not exist %ROOTDIR%\core_datadir\regtest_carol\ mkdir %ROOTDIR%\core_datadir\regtest_carol
REM 
REM 
REM start %ROOTDIR%\core_bin\win\bin\bitcoin-qt.exe -uacomment=%~n0 ^
REM -datadir=%ROOTDIR%\core_datadir\regtest_carol -regtest -port=18666 ^
REM -addnode=localhost:18444 -addnode=localhost:18555