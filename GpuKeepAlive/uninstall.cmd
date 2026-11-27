@echo off
rem Stops the keep-alive and removes it from your Startup folder.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
echo.
pause
