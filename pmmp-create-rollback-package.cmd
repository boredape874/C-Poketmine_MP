@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\create-rollback-package.cmd" %*
exit /b %ERRORLEVEL%
