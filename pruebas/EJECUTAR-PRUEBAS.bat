@echo off
title Barotrauma LAN - pruebas (no necesitan el juego)
color 0E
if not exist "%~dp0pruebas.ps1" goto :falta
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0pruebas.ps1"
echo.
pause
goto :fin

:falta
echo.
echo    Falta pruebas.ps1 al lado de este .bat.
echo.
pause

:fin
