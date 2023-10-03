@echo off

set WORKDIR=%~dp0

REM powershell.exe -ExecutionPolicy ByPass -File %WORKDIR%\child_pc_locker.ps1
pwsh.exe -ExecutionPolicy ByPass -File %WORKDIR%\child_pc_locker.ps1

EXIT