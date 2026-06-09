@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\summarize-production-evidence.cmd" %*
exit /b %ERRORLEVEL%
