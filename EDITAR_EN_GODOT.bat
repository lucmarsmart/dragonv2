@echo off
setlocal
cd /d "%~dp0"
title Editor Godot 4 - Dragon Project
echo ========================================================
echo        ABRIENDO PROYECTO EN EL EDITOR GODOT 4...
echo ========================================================
echo.

set "GODOT_EXE="
if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" (
    set "GODOT_EXE=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
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
"%GODOT_EXE%" -e --path "%~dp0"
if errorlevel 1 (
    echo.
    echo ========================================================
    echo  Hubo un problema al abrir el editor (Codigo: %ERRORLEVEL%).
    echo ========================================================
    pause
)
