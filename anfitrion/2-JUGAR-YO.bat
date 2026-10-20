@echo off
title Barotrauma LAN - jugar en mi propio servidor
color 0B
if not exist "%~dp0..\amigo\jugar.ps1" goto :falta
if not exist "%~dp0servidor-actual.json" goto :faltadatos
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\amigo\jugar.ps1" -Local -DatosServidor "%~dp0servidor-actual.json"
if errorlevel 1 goto :parar
echo.
echo    Esta ventana se cierra sola.
timeout /t 15 >nul
goto :fin

:parar
echo.
pause
goto :fin

:falta
echo.
echo    Falta la carpeta "amigo" junto a "anfitrion". Abre este .bat desde la carpeta completa de Barotrauma LAN.
echo.
pause
goto :fin

:faltadatos
echo.
echo    Todavia no has abierto el servidor: abre antes  1-ABRIR-SERVIDOR.bat
echo.
pause

:fin
