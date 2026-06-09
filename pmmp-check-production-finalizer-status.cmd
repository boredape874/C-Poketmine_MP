@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\check-production-finalizer-status.cmd" %*
exit /b %ERRORLEVEL%
