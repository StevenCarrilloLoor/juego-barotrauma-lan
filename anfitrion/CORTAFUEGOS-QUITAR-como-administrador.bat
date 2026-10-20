@echo off
title Barotrauma LAN - quitar la regla del cortafuegos
color 0E
echo ==============================================================================
echo    CORTAFUEGOS DE WINDOWS: QUITAR LA REGLA DE BAROTRAUMA LAN
echo ==============================================================================
echo.
echo    Quita la regla que puso CORTAFUEGOS-ABRIR (las del grupo "Barotrauma LAN")
echo    y ninguna otra. Te las ensena antes y te pregunta.
echo.
echo    Hay que abrirlo con: clic derecho - Ejecutar como administrador.
echo.
if not exist "%~dp0cortafuegos.ps1" goto :falta
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0cortafuegos.ps1" -Accion quitar
echo.
pause
goto :fin

:falta
echo    Falta cortafuegos.ps1 al lado de este .bat.
echo.
pause

:fin
