@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\check-native-promotion-pipeline-status.ps1" %*
exit /b %ERRORLEVEL%
