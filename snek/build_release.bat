:: This script creates an optimized release build.

@echo off

set OUT_DIR=build\release

if not exist %OUT_DIR% mkdir %OUT_DIR%

xcopy /y /e /i assets %OUT_DIR%\assets > nul
IF %ERRORLEVEL% NEQ 0 exit /b 1

odin build source\main_release -resource:resource.rc -out:%OUT_DIR%\game_release.exe -strict-style -vet -no-bounds-check -o:speed -subsystem:windows
IF %ERRORLEVEL% NEQ 0 exit /b 1


echo Release build created in %OUT_DIR%