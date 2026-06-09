@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\run-production-soak.ps1" %*
exit /b %ERRORLEVEL%
