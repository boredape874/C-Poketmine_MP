@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\summarize-production-evidence.ps1" %*
exit /b %ERRORLEVEL%
