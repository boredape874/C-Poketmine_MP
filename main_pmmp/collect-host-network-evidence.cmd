@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\collect-host-network-evidence.ps1" %*
exit /b %ERRORLEVEL%
