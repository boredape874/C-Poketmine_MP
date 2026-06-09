@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\run-tooling-preflight.ps1" %*
exit /b %ERRORLEVEL%
