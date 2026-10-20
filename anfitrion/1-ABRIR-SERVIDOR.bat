@echo off
title Barotrauma LAN - abrir el servidor
color 0B
if not exist "%~dp0servidor.ps1" goto :falta
if not exist "%~dp0..\amigo\barolan-comun.ps1" goto :falta
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0servidor.ps1" -Accion abrir
echo.
pause
goto :fin

:falta
echo.
echo    Faltan ficheros: este .bat necesita servidor.ps1 a su lado y la carpeta "amigo" junto a "anfitrion".
echo    Abrelo desde la carpeta completa de Barotrauma LAN.
echo.
pause

:fin
