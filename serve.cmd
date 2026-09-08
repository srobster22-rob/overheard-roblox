@echo off
REM Start the Rojo sync server. Leave this window open while working in Studio.
cd /d "%~dp0"
"%USERPROFILE%\.rokit\bin\rojo.exe" serve default.project.json
