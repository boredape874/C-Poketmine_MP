@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\run-post-native-promotion-validation.ps1" %*
exit /b %ERRORLEVEL%
