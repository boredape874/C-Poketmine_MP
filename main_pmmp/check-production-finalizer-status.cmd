@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\check-production-finalizer-status.ps1" %*
exit /b %ERRORLEVEL%
