@echo off
REM Run the whole headless suite. No Studio required.
cd /d "%~dp0"
set ROKIT=%USERPROFILE%\.rokit\bin
set FAILED=0
for %%T in (lexicon operator objectives pursuit round config) do (
    echo(
    echo === %%T ===
    "%ROKIT%\lune.exe" run tests/%%T || set FAILED=1
)
echo(
if "%FAILED%"=="1" (echo SUITE FAILED & exit /b 1) else (echo suite passed)
