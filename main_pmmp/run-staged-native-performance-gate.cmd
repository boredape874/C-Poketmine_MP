@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run-staged-native-performance-gate.ps1" %*
