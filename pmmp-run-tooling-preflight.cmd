@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\run-tooling-preflight.cmd" %*
exit /b %ERRORLEVEL%
