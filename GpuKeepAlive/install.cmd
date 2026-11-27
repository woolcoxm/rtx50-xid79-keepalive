@echo off
rem Adds the keep-alive to your Startup folder and starts it now. No administrator rights needed.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
pause
