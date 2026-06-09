@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\collect-host-network-evidence.cmd" %*
exit /b %ERRORLEVEL%
