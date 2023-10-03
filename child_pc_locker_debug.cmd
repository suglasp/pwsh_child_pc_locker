@echo off

REM powershell.exe -ExecutionPolicy ByPass -File .\child_pc_locker.ps1 -Verbose -Debug
pwsh.exe -ExecutionPolicy ByPass -File .\child_pc_locker.ps1 -Verbose -Debug

PAUSE > NUL
EXIT