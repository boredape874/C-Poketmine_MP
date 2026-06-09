@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\continue-fast-progress.cmd" %*
exit /b %ERRORLEVEL%
