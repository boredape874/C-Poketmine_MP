@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\register-production-plugins.ps1" %*
exit /b %ERRORLEVEL%
