:: This script creates a build with profiling enabled.

@echo off

set OUT_DIR=build\profiler

if not exist %OUT_DIR% mkdir %OUT_DIR%

xcopy /y /e /i assets %OUT_DIR%\assets > nul
IF %ERRORLEVEL% NEQ 0 exit /b 1

odin build source\main_profiler -resource:resource.res -out:%OUT_DIR%\game_profiler.exe -strict-style -vet -debug
IF %ERRORLEVEL% NEQ 0 exit /b 1


echo Profiler build created in %OUT_DIR%