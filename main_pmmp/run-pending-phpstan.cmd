@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\run-pending-phpstan.ps1" -IncludeTooling %*
exit /b %ERRORLEVEL%
