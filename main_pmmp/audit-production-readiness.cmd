@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\audit-production-readiness.ps1" %*
exit /b %ERRORLEVEL%
