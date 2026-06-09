@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0main_pmmp\tools\run-staged-native-performance-gate.ps1" %*
