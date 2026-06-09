@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\finalize-production-readiness-after-soak.cmd" %*
exit /b %ERRORLEVEL%
