@echo off
REM The one check command: every SHIP gate (all suites, the bot and smoke runs,
REM the market check, selene, stylua and the rojo build), ending with a summary
REM of each failing gate, its first failing assertion and file:line.
REM Arguments pass through: a gate name to run only that gate, or "verbose".
cd /d "%~dp0"
"%USERPROFILE%\.rokit\bin\lune.exe" run tools/check %*
exit /b %ERRORLEVEL%
