# ==============================================================================================================
# sondear.ps1  -  Barotrauma LAN 0.1  -  la sonda suelta, para que el LABORATORIO la mida contra el servidor real
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File pruebas\sondear.ps1 -Direccion 127.0.0.1 -Puerto 29015
#   ... -Modo limpia   (por omision) saludo Connect con identificador equivocado. Es la que usan los lanzadores.
#   ... -Modo completa SOLO LABORATORIO: saludo con el identificador del juego. El servidor crea un cliente pendiente
#                      y apunta "Incoming connection"; al contestar se le manda un Disconnect para soltarlo.
#   ... -Modo ping     ping normal (solo dice que el PC esta).
#   -Veces N           repite N veces (cada vez desde un puerto de origen nuevo)      -PausaMs entre repeticiones
#   -EsperaMs / -Intentos   espera de cada intento y numero de envios por repeticion
#
# Ninguno de los modos manda mensajes de datos (tipos 1 a 98 de Lidgren), que son los unicos por los que el
# servidor veta una IP. Escribe una linea por repeticion y un resumen. Codigo de salida: 0 si contesto siempre,
# 1 si alguna vez no.
#
# QUE HAY QUE MIRAR EN EL SERVIDOR para dar la sonda limpia por buena (ver AGENTS.md):
#   que no aparece ninguna linea nueva en su consola ni en ServerLogs, que clientlist sigue vacio, que
#   Data\bannedplayers.xml no cambia y que despues entra un cliente de verdad desde la misma IP.
#   OJO: 127.0.0.1 no sirve para descartar el veto (el servidor nunca veta el bucle local): hay que repetirlo
#   contra una IP de la red local o de la VPN.
# ==============================================================================================================
param(
    [Parameter(Mandatory = $true)][string]$Direccion,
    [int]$Puerto = 27715,
    [ValidateSet('limpia', 'completa', 'ping')][string]$Modo = 'limpia',
    [int]$Veces = 1,
    [int]$EsperaMs = 450,
    [int]$Intentos = 2,
    [int]$PausaMs = 100
)
$ErrorActionPreference = 'Stop'
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Join-Path (Split-Path -Parent $aqui) 'amigo') 'barolan-comun.ps1')

if (-not (Test-BLIpLiteral $Direccion)) { Write-Host ('La direccion tiene que ser una IP: ' + $Direccion); exit 2 }
$destino = @(@{ direccion = $Direccion; puerto = $Puerto })
$bien = 0
$tiempos = New-Object System.Collections.ArrayList
Write-Host ('SONDA {0} a {1}:{2}  ({3} veces, {4} intento(s) de {5} ms)' -f $Modo, $Direccion, $Puerto, $Veces, $Intentos, $EsperaMs)
for ($i = 1; $i -le $Veces; $i++) {
    if ($Modo -eq 'completa') { $r = @(Invoke-BLSondaLidgren -Destinos $destino -EsperaMs $EsperaMs -Intentos $Intentos -Completa) }
    else { $r = @(Invoke-BLSonda -Modo $Modo -Destinos $destino -EsperaMs $EsperaMs -Intentos $Intentos) }
    $x = $r[0]
    Write-Host ('{0,3}  {1,-15} {2,5} ms  enviados={3}  {4}' -f $i, $x.Estado, $x.Ms, $x.Enviados, $x.Detalle)
    if ($x.Estado -eq 'contesta') { $bien++; if ($x.Ms -ge 0) { [void]$tiempos.Add([int]$x.Ms) } }
    if ($i -lt $Veces) { Start-Sleep -Milliseconds $PausaMs }
}
$media = -1
if ($tiempos.Count -gt 0) { $media = [int](($tiempos | Measure-Object -Average).Average) }
Write-Host ('RESUMEN: {0}/{1} contestadas, media {2} ms' -f $bien, $Veces, $media)
if ($bien -eq $Veces) { exit 0 }
exit 1
