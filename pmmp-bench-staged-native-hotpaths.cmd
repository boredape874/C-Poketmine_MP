@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0main_pmmp\tools\bench-staged-native-hotpaths.ps1" %*
