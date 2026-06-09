@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\start-production-finalizer-watcher.cmd" %*
exit /b %ERRORLEVEL%
