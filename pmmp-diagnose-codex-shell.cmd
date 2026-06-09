@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\diagnose-codex-shell.cmd" %*
exit /b %ERRORLEVEL%
