@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SignalRGBProxy.ps1" -Action Uninstall
pause
