@ECHO OFF

SET Args=

:: First argument is always notepad.exe
SHIFT

:Loop
IF "%1"=="" GOTO Continue
    SET Args=%Args% %1
SHIFT
GOTO Loop
:Continue

start "Notepad Redirect" "%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe" %Args%