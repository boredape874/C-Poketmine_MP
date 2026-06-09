@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\register-bedrock-login-swarm-evidence.cmd" %*
exit /b %ERRORLEVEL%
