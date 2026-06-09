@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\write-production-deployment-status.ps1" %*
exit /b %ERRORLEVEL%
