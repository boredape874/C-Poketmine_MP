@echo off
cd /d "%~dp0main_pmmp"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0main_pmmp\tools\run-bedrock-login-swarm.ps1" %*
