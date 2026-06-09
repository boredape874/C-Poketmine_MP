@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\run-production-soak.cmd" %*
exit /b %ERRORLEVEL%
