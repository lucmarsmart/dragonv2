@echo off
setlocal
cd /d "%~dp0"
title Editor Godot 4 - Dragon Project
echo ========================================================
echo        ABRIENDO PROYECTO EN EL EDITOR GODOT 4...
echo ========================================================
echo.

set "GODOT_EXE=C:\Users\Lucas Marsiglia\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

if not exist "%GODOT_EXE%" (
    set "GODOT_EXE=godot"
)

"%GODOT_EXE%" -e
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================================
    echo  Hubo un problema al abrir el editor (Codigo: %ERRORLEVEL%).
    echo ========================================================
    pause
)
