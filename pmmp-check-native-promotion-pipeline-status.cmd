@echo off
setlocal
cd /d "%~dp0main_pmmp"
call ".\check-native-promotion-pipeline-status.cmd" %*
exit /b %ERRORLEVEL%
