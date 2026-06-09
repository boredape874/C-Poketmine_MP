@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\diagnose-codex-shell.ps1" %*
exit /b %ERRORLEVEL%
