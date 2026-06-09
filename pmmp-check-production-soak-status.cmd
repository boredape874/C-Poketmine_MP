@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\check-production-soak-status.cmd" %*
exit /b %ERRORLEVEL%
