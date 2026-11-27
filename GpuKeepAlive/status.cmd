@echo off
rem Shows whether the keep-alive is running and holding the card.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0status.ps1"
echo.
pause
