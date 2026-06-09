@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\promote-staged-native-extension.cmd" %*
exit /b %ERRORLEVEL%
