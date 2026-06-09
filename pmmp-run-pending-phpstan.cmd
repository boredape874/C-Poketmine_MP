@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\run-pending-phpstan.cmd" %*
exit /b %ERRORLEVEL%
