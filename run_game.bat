@echo off
cd /d "%~dp0"
title TowerTock Launcher
echo ========================================================
echo Starting TowerTock (Godot 4.3)...
echo Controls:
echo   - Left Click / Spacebar : Drop Building
echo   - Escape                : Pause Menu
echo ========================================================
start "" "C:\Users\nisth\godot_bin\Godot_v4.3-stable_win64.exe" --path "C:\Users\nisth\towertock"
