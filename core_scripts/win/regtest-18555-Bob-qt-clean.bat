REM set ROOTDIR=%~dp0..\..
REM echo ROOTDIR is %ROOTDIR%
REM 
REM rmdir %ROOTDIR%\core_datadir\regtest_bob /s /q
REM mkdir %ROOTDIR%\core_datadir\regtest_bob
REM 
REM start %ROOTDIR%\core_bin\win\bin\bitcoin-qt.exe -uacomment=%~n0 ^
REM -datadir=%ROOTDIR%\core_datadir\regtest_bob -regtest -port=18555 ^
REM -addnode=localhost:18444 -addnode=localhost:18666
