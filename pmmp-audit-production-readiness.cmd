@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\audit-production-readiness.cmd" %*
exit /b %ERRORLEVEL%
