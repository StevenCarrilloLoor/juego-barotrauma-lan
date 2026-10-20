@echo off
title Barotrauma LAN - estado (solo mira)
color 0E
if not exist "%~dp0servidor.ps1" goto :falta
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0servidor.ps1" -Accion estado
echo.
pause
goto :fin

:falta
echo.
echo    Falta servidor.ps1 al lado de este .bat.
echo.
pause

:fin
