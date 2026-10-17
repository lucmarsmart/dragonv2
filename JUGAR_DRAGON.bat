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
set "GODOT_EXE="
if defined DRAGON_GODOT_BIN if exist "%DRAGON_GODOT_BIN%" set "GODOT_EXE=%DRAGON_GODOT_BIN%"

if not defined GODOT_EXE if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" (
    set "GODOT_EXE=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
)

if not defined GODOT_EXE if exist "C:\Users\Lucas Marsiglia\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" (
    set "GODOT_EXE=C:\Users\Lucas Marsiglia\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
)

if not defined GODOT_EXE (
    for /f "delims=" %%I in ('where godot_console.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%I"
)
if not defined GODOT_EXE (
    for /f "delims=" %%I in ('where godot.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%I"
)
if not defined GODOT_EXE (
    for /f "delims=" %%I in ('where godot 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%I"
)

if not defined GODOT_EXE (
    echo ========================================================
    echo  No se encontro Godot en el sistema.
    echo  Instalalo con: winget install GodotEngine.GodotEngine
    echo ========================================================
    pause
    exit /b 1
)

echo Ejecutando: "%GODOT_EXE%"
"%GODOT_EXE%" --path "%~dp0."
if errorlevel 1 (
    echo.
    echo ========================================================
    echo  Hubo un problema al iniciar (Codigo: %ERRORLEVEL%).
    echo ========================================================
    pause
)
