@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\start-production-finalizer-watcher.ps1" %*
exit /b %ERRORLEVEL%
