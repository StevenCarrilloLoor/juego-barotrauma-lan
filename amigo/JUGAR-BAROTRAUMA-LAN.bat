@echo off
title Barotrauma LAN
color 0B
if not exist "%~dp0jugar.ps1" goto :falta
if not exist "%~dp0barolan-comun.ps1" goto :falta
if not exist "%~dp0servidor.json" goto :faltadatos
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0jugar.ps1"
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
echo    Faltan ficheros al lado de este .bat (jugar.ps1 y barolan-comun.ps1).
echo    Saca la carpeta ENTERA del .zip antes de abrirlo (clic derecho - Extraer todo).
echo    No lo abras desde dentro del .zip.
echo.
pause
goto :fin

:faltadatos
echo.
echo    Falta el fichero servidor.json (las direcciones del servidor).
echo    Pidele al anfitrion que te mande otra vez la carpeta entera.
echo.
pause

:fin
