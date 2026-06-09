@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\record-native-build-evidence.ps1" %*
exit /b %ERRORLEVEL%
