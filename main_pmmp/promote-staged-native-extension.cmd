@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\promote-staged-native-extension.ps1" %*
exit /b %ERRORLEVEL%
