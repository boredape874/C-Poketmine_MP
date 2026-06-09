@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\create-rollback-package.ps1" %*
exit /b %ERRORLEVEL%
