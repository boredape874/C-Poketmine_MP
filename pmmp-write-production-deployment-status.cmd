@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\write-production-deployment-status.cmd" %*
exit /b %ERRORLEVEL%
