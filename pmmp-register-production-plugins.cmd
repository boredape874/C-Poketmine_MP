@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\register-production-plugins.cmd" %*
exit /b %ERRORLEVEL%
