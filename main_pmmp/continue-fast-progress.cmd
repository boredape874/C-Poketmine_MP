@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\continue-fast-progress.ps1" %*
exit /b %ERRORLEVEL%
