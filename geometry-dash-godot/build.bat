@echo off
setlocal
set GODOT="%~dp0Godot_v4.3-stable_win64.exe"
set PROJECT="%~dp0"
set OUT="%~dp0dist\GeometryDash.exe"

echo ============================================
echo  Geometry Dash — Godot 4.3 Build Script
echo ============================================

if not exist %GODOT% (
    echo ERROR: Godot exe not found. Run from project root.
    pause & exit /b 1
)

echo [1/3] Importing project...
%GODOT% --headless --path %PROJECT% --import
if errorlevel 1 ( echo Import failed. & pause & exit /b 1 )

echo [2/3] Exporting Windows build...
if not exist "%~dp0dist" mkdir "%~dp0dist"
%GODOT% --headless --path %PROJECT% --export-release "Windows Desktop" %OUT%
if errorlevel 1 ( echo Export failed — open in editor first to configure export templates. & pause & exit /b 1 )

echo [3/3] Done!
echo Output: %OUT%
pause
