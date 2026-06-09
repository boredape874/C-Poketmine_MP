@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\run-post-native-promotion-validation.cmd" %*
exit /b %ERRORLEVEL%
