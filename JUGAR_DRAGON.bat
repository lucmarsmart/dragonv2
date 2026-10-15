@echo off
setlocal
cd /d "%~dp0"
title Simulador de Dragon - Vuelo Biomecanico
echo ========================================================
echo          SIMULADOR DE DRAGON - CARGANDO MUNDO...
echo ========================================================
echo Carpeta: %CD%
echo.

rem Igual que en macOS: DRAGON_GODOT_BIN tiene prioridad sobre la ruta conocida.
if defined DRAGON_GODOT_BIN if exist "%DRAGON_GODOT_BIN%" set "GODOT_EXE=%DRAGON_GODOT_BIN%"
if not defined GODOT_EXE set "GODOT_EXE=C:\Users\Lucas Marsiglia\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

if not exist "%GODOT_EXE%" (
    echo No se encontro Godot en la ruta esperada.
    echo Probando con comando 'godot'...
    set "GODOT_EXE=godot"
)

"%GODOT_EXE%" --path "%~dp0."
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================================
    echo  Hubo un problema al iniciar (Codigo: %ERRORLEVEL%).
    echo ========================================================
    pause
)
