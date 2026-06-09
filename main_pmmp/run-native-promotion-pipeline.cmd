@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\run-native-promotion-pipeline.ps1" %*
exit /b %ERRORLEVEL%
