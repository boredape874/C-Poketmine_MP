@echo off
setlocal
cd /d "%~dp0main_pmmp"
call "%~dp0main_pmmp\start-plugin-server.cmd" %*
endlocal
