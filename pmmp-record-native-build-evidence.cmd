@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\record-native-build-evidence.cmd" %*
exit /b %ERRORLEVEL%
