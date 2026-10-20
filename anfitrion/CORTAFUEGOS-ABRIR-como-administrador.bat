@echo off
title Barotrauma LAN - abrir el cortafuegos (una vez)
color 0E
echo ==============================================================================
echo    CORTAFUEGOS DE WINDOWS: DEJAR ENTRAR A TUS AMIGOS AL SERVIDOR
echo ==============================================================================
echo.
echo    Anade UNA regla: deja entrar trafico UDP al puerto de tu servidor de
echo    Barotrauma LAN, y solo para ese programa. No toca ninguna otra regla.
echo    Se quita con  CORTAFUEGOS-QUITAR-como-administrador.bat
echo.
echo    Hay que abrirlo con: clic derecho - Ejecutar como administrador.
echo.
if not exist "%~dp0cortafuegos.ps1" goto :falta
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0cortafuegos.ps1" -Accion abrir
echo.
pause
goto :fin

:falta
echo    Falta cortafuegos.ps1 al lado de este .bat.
echo.
pause

:fin
