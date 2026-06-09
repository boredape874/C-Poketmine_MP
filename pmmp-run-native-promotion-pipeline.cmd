@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\run-native-promotion-pipeline.cmd" %*
exit /b %ERRORLEVEL%
