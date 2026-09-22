@echo off
REM Run the whole headless suite. No Studio required.
cd /d "%~dp0"
set ROKIT=%USERPROFILE%\.rokit\bin
set FAILED=0
REM tests/wiring.luau asserts this list covers every suite file in tests/.
for %%T in (lexicon heuristic operator objectives pursuit round config wiring connected ordering heat layout lifecycle hud readout soak hum log silence lexiconsave escape) do (
    echo(
    echo === %%T ===
    "%ROKIT%\lune.exe" run tests/%%T || set FAILED=1
)
echo(
echo === playtest bots, 2 rounds ===
REM R138: the bots' traces are evidence in LOOP_LOG, and nothing ran them, so a
REM call to a removed API went unnoticed (COACH.md C11). The trace is discarded;
REM `gate` fails the run if the bots win no round at all.
"%ROKIT%\lune.exe" run tools/playtest quiet 2 11 gate > nul || set FAILED=1
echo(
if "%FAILED%"=="1" (echo SUITE FAILED & exit /b 1) else (echo suite passed)
