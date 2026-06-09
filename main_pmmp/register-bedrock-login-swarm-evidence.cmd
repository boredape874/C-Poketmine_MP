@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\register-bedrock-login-swarm-evidence.ps1" %*
exit /b %ERRORLEVEL%
