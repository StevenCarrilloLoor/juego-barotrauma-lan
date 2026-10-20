# ==============================================================================================================
# pruebas.ps1  -  Barotrauma LAN 0.1  -  pruebas que NO necesitan el juego
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File pruebas\pruebas.ps1            todas
#   powershell -NoProfile -ExecutionPolicy Bypass -File pruebas\pruebas.ps1 -Solo sonda   solo las que lleven "sonda" en el nombre
#   -Conservar   no borra pruebas\_tmp al acabar (para mirar lo que se genero)
#
# QUE ACREDITAN Y QUE NO:
#   - Acreditan la logica de los guiones: leer ficheros de Steam, comparar versiones, ordenar direcciones, escribir
#     el XML, montar la carpeta del servidor, generar el paquete, construir las ordenes.
#   - La sonda se prueba contra un servidor UDP DE MENTIRA (servidor-udp-falso.ps1) que imita lo leido en el codigo
#     de Lidgren. Eso NO acredita nada del juego real: lo tiene que medir el laboratorio.
#   - Aqui NO se lanza Barotrauma.exe ni DedicatedServer.exe. Los "juegos" de estas pruebas son carpetas de pega
#     con ficheros de texto y dos .dll vacias compiladas al vuelo solo para llevar un numero de version.
#   - No se toca el cortafuegos (solo se lee), ni la instalacion real (solo se lee su version).
#   - Toda la red de las pruebas es 127.0.0.1, en puertos libres que elige Windows.
#
# Todo lo que escriben va a pruebas\_tmp\ (se borra al acabar). Sale con codigo 0 si no falla ninguna.
# ==============================================================================================================
param([string]$Solo = '', [switch]$Conservar)

$ErrorActionPreference = 'Stop'
$P_Aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$P_Proyecto = Split-Path -Parent $P_Aqui
$P_Amigo = Join-Path $P_Proyecto 'amigo'
$P_Anfitrion = Join-Path $P_Proyecto 'anfitrion'
. (Join-Path $P_Amigo 'barolan-comun.ps1')
. (Join-Path $P_Anfitrion 'anfitrion-lib.ps1')
. (Join-Path $P_Aqui 'servidor-udp-falso.ps1')
# IP de ejemplo del rango de Tailscale, escritas por octetos: el repositorio es publico y ninguna es de un equipo
# real. Las de Radmin, Hamachi y ZeroTier de estas pruebas tambien son inventadas.
function IpTs([int]$b, [int]$c, [int]$d) { return (@(100, $b, $c, $d) -join '.') }
Set-StrictMode -Version 2

$script:P_Resultados = New-Object System.Collections.ArrayList
$script:P_Uniones = New-Object System.Collections.ArrayList
$script:P_Tmp = Join-Path $P_Aqui ('_tmp\' + [guid]::NewGuid().ToString('N').Substring(0, 8))
[void](New-Item -ItemType Directory -Path $script:P_Tmp -Force)
$script:P_PowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Prueba {
    param([string]$Nombre, [scriptblock]$Cuerpo)
    if ($Solo -and $Nombre -notmatch [regex]::Escape($Solo)) { return }
    $estado = 'OK'; $detalle = ''
    try { & $Cuerpo } catch {
        $m = $_.Exception.Message
        if ($m -like 'OMITIDA:*') { $estado = 'OMITIDA'; $detalle = $m.Substring(8).Trim() }
        else { $estado = 'FALLA'; $detalle = $m + '  [linea ' + $_.InvocationInfo.ScriptLineNumber + ']' }
    }
    [void]$script:P_Resultados.Add((New-Object psobject -Property @{ Nombre = $Nombre; Estado = $estado; Detalle = $detalle }))
    $color = 'Green'
    if ($estado -eq 'FALLA') { $color = 'Red' } elseif ($estado -eq 'OMITIDA') { $color = 'Yellow' }
    Write-Host ('  [{0,-7}] {1}' -f $estado, $Nombre) -ForegroundColor $color
    if ($detalle) { Write-Host ('            ' + $detalle) -ForegroundColor $color }
}
function Afirmar { param($Condicion, [string]$Mensaje) if (-not $Condicion) { throw $Mensaje } }
function AfirmarIgual { param($Esperado, $Obtenido, [string]$Que = 'valor') if ([string]$Esperado -cne [string]$Obtenido) { throw ($Que + ': esperaba [' + $Esperado + '] y salio [' + $Obtenido + ']') } }
function Omitir { param([string]$Motivo) throw ('OMITIDA: ' + $Motivo) }

# ----------------------------------------------------------------------------------------------- utilidades
$script:P_Dlls = @{}
function Get-DllConVersion {
    # Compila (una vez por version) una .dll vacia que solo lleva ese numero de version. No es un fichero del juego.
    param([string]$Version)
    if ($script:P_Dlls.ContainsKey($Version)) { return $script:P_Dlls[$Version] }
    $ruta = Join-Path $script:P_Tmp ('dll-' + $Version + '.dll')
    $codigo = '[assembly: System.Reflection.AssemblyVersion("' + $Version + '")] public class BLPega' + ([guid]::NewGuid().ToString('N')) + ' { }'
    Add-Type -TypeDefinition $codigo -OutputAssembly $ruta -OutputType Library
    $script:P_Dlls[$Version] = $ruta
    return $ruta
}

function New-JuegoFalso {
    # Carpeta que se parece a una instalacion de Barotrauma. Todo son ficheros de texto menos las dos .dll de version.
    param([string]$Carpeta, [string]$Version = '1.13.4.0', [switch]$SinServidor)
    foreach ($d in @('', 'Content\ContentPackages', 'Content\Items', 'Data', 'x64', 'LocalMods', 'ServerLogs')) {
        [void](New-Item -ItemType Directory -Path (Join-Path $Carpeta $d) -Force)
    }
    $dll = Get-DllConVersion $Version
    Copy-Item -LiteralPath $dll -Destination (Join-Path $Carpeta 'Barotrauma.dll') -Force
    $texto = @{
        'Barotrauma.exe'                      = 'esto no es el juego'
        'steam_api64.dll'                     = 'pega'
        'EOSSDK-Win64-Shipping.dll'           = 'pega'
        'Lidgren.NetStandard.dll'             = 'pega'
        'DedicatedServer.runtimeconfig.json'  = '{}'
        'config_player.xml'                   = '<config language="Spanish"><player name="SECRETO-DEL-DUENO" /></config>'
        'serversettings.xml'                  = '<serversettings port="27015" queryport="27016" password="" ServerName="SALA DEL DUENO" IsPublic="True" RequireAuthentication="True" RespawnInterval="20" BanAfterWrongPassword="False"><campaignsettings PresetName="" /></serversettings>'
        'crashreport.log'                     = 'estado del dueno'
        'creature_metrics.xml'                = '<x />'
        'Data\clientpermissions.xml'          = '<ClientPermissions><Client name="Dueno" accountid="STEAM64_1" permissions="All" /></ClientPermissions>'
        'Data\bannedplayers.xml'              = '<x />'
        'Data\karmasettings.xml'              = '<karma />'
        'Data\permissionpresets.xml'          = '<presets />'
        'x64\SDL2.dll'                        = 'pega'
        'Content\ContentPackages\Vanilla.xml' = ('<contentpackage name="Vanilla" gameversion="' + $Version + '"></contentpackage>')
        'Content\Items\cosa.xml'              = '<Items />'
        'ServerLogs\viejo.txt'                = 'registro del dueno'
        'LocalMods\info.txt'                  = 'info'
    }
    foreach ($k in $texto.Keys) { [System.IO.File]::WriteAllText((Join-Path $Carpeta $k), $texto[$k]) }
    if (-not $SinServidor) {
        [System.IO.File]::WriteAllText((Join-Path $Carpeta 'DedicatedServer.exe'), 'esto no es el servidor')
        Copy-Item -LiteralPath $dll -Destination (Join-Path $Carpeta 'DedicatedServer.dll') -Force
    }
    return $Carpeta
}

function Get-HuellaCarpeta {
    # Nombre + tamano + fecha de todos los ficheros: para demostrar que una carpeta no se toco.
    param([string]$Carpeta)
    $l = foreach ($f in (Get-ChildItem -LiteralPath $Carpeta -Recurse -File -Force | Sort-Object FullName)) {
        '{0}|{1}|{2}' -f $f.FullName.Substring($Carpeta.Length), $f.Length, $f.LastWriteTimeUtc.Ticks
    }
    return (@($l) -join "`n")
}

function Invoke-Guion {
    # Lanza un guion en un PowerShell 5.1 aparte, sin ventana y sin poder preguntar. Devuelve Codigo y Salida.
    param([string]$Guion, [string[]]$Argumentos = @())
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:P_PowerShell
    $partes = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', (ConvertTo-BLArgumento $Guion))
    foreach ($x in $Argumentos) { $partes += (ConvertTo-BLArgumento $x) }
    $psi.Arguments = ($partes -join ' ')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $salida = $p.StandardOutput.ReadToEnd()
    $errores = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return @{ Codigo = $p.ExitCode; Salida = ($salida + $errores) }
}

function New-DatosServidorDePrueba {
    # Escribe un servidor.json y devuelve su ruta.
    param([string]$Nombre, [object[]]$Direcciones, [int]$Puerto = 27015, [string]$Version = '1.13.4.0', [string]$Sonda = 'limpia', [string]$Contrasena = '')
    $d = New-ALDatosServidor -Nombre 'Sala de prueba' -Puerto $Puerto -Version $Version -Anfitrion 'Anfi' -Contrasena $Contrasena -Sonda $Sonda -Direcciones $Direcciones
    $ruta = Join-Path $script:P_Tmp ($Nombre + '.json')
    Write-BLJson $ruta $d
    return $ruta
}

$P_InterfacesDelDueno = @(
    (New-Object psobject -Property @{ Alias = 'Radmin VPN'; Descripcion = 'Famatech Radmin VPN Ethernet Adapter'; Clase = 'Ethernet'; Ip = '26.10.20.30'; Prefijo = 8; TienePuerta = $true }),
    (New-Object psobject -Property @{ Alias = 'Tailscale'; Descripcion = 'Tailscale Tunnel'; Clase = '53'; Ip = (IpTs 77 10 20); Prefijo = 32; TienePuerta = $false }),
    (New-Object psobject -Property @{ Alias = 'Hamachi'; Descripcion = 'LogMeIn Hamachi Virtual Ethernet Adapter'; Clase = 'Ethernet'; Ip = '25.10.20.30'; Prefijo = 8; TienePuerta = $false }),
    (New-Object psobject -Property @{ Alias = 'vEthernet (WSL (Hyper-V firewall))'; Descripcion = 'Hyper-V Virtual Ethernet Adapter'; Clase = 'Ethernet'; Ip = '172.22.0.1'; Prefijo = 20; TienePuerta = $false }),
    (New-Object psobject -Property @{ Alias = 'ZeroTier One [0123456789abcdef]'; Descripcion = 'ZeroTier Virtual Port'; Clase = 'Ethernet'; Ip = '10.144.10.20'; Prefijo = 16; TienePuerta = $true }),
    (New-Object psobject -Property @{ Alias = 'Ethernet'; Descripcion = 'Intel(R) Ethernet Controller I226-V'; Clase = 'Ethernet'; Ip = '169.254.153.215'; Prefijo = 16; TienePuerta = $false }),
    (New-Object psobject -Property @{ Alias = 'Wi-Fi'; Descripcion = 'Intel(R) Wi-Fi 7 BE200 320MHz'; Clase = 'Wireless80211'; Ip = '10.10.10.103'; Prefijo = 24; TienePuerta = $true }),
    (New-Object psobject -Property @{ Alias = 'Loopback Pseudo-Interface 1'; Descripcion = 'Software Loopback Interface 1'; Clase = 'Loopback'; Ip = '127.0.0.1'; Prefijo = 8; TienePuerta = $false })
)

Write-Host ''
Write-Host ('  PRUEBAS DE BAROTRAUMA LAN ' + $script:BL_Version + '   (PowerShell ' + $PSVersionTable.PSVersion + ')') -ForegroundColor Cyan
Write-Host ('  temporales en ' + $script:P_Tmp)
Write-Host ''

# =================================================================================================== ficheros de Steam
Prueba 'vdf: libraryfolders con el formato nuevo' {
    $t = "`"libraryfolders`"`n{`n`t`"0`"`n`t{`n`t`t`"path`"`t`t`"C:\\Program Files (x86)\\Steam`"`n`t`t`"apps`"`n`t`t{`n`t`t`t`"228980`"`t`t`"1`"`n`t`t}`n`t}`n`t`"1`"`n`t{`n`t`t`"path`"`t`t`"D:\\SteamLibrary`"`n`t`t`"apps`" { `"602960`" `"1235018205`" }`n`t}`n}`n"
    $b = @(Get-BLBibliotecasSteam $t)
    AfirmarIgual 2 $b.Count 'numero de bibliotecas'
    AfirmarIgual 'C:\Program Files (x86)\Steam' $b[0] 'biblioteca 0'
    AfirmarIgual 'D:\SteamLibrary' $b[1] 'biblioteca 1'
    $doc = ConvertFrom-BLVdf $t
    AfirmarIgual '1235018205' $doc['LIBRARYFOLDERS']['1']['apps']['602960'] 'clave anidada, sin distinguir mayusculas'
}
Prueba 'vdf: libraryfolders con el formato viejo, comentarios y claves sin comillas' {
    $t = "// comentario`n`"LibraryFolders`"`n{`n`t`"TimeNextStatsReport`"`t`"123`"`n`tContentStatsID`t`"-5`"`n`t`"1`"`t`"E:\\Juegos\\Steam`"`n`t`"2`"`t`"F:/Otra`"`n}`n"
    $b = @(Get-BLBibliotecasSteam $t)
    AfirmarIgual 2 $b.Count 'numero de bibliotecas'
    AfirmarIgual 'E:\Juegos\Steam' $b[0] 'biblioteca 1'
    AfirmarIgual 'F:\Otra' $b[1] 'biblioteca 2 (barras normalizadas)'
}
Prueba 'vdf: texto roto no revienta' {
    AfirmarIgual 0 @(Get-BLBibliotecasSteam '"a" { { "b" }').Count 'bibliotecas de un vdf roto'
    AfirmarIgual 0 @(Get-BLBibliotecasSteam '').Count 'bibliotecas de un vdf vacio'
    $m = Get-BLDatosManifiestoSteam '}}}'
    Afirmar ($null -eq $m.InstallDir) 'installdir de un acf roto'
}
Prueba 'vdf: appmanifest (installdir y buildid)' {
    $m = Get-BLDatosManifiestoSteam "`"AppState`"`n{`n`t`"appid`"`t`"602960`"`n`t`"installdir`"`t`"Barotrauma`"`n`t`"buildid`"`t`"23799131`"`n`t`"InstalledDepots`" { `"602961`" { `"manifest`" `"1`" } }`n}"
    AfirmarIgual 'Barotrauma' $m.InstallDir 'installdir'
    AfirmarIgual '23799131' $m.BuildId 'buildid'
}
Prueba 'juego: lo encuentra en una biblioteca secundaria de un Steam de pega' {
    $steam = Join-Path $script:P_Tmp 'steam1'
    $bib = Join-Path $script:P_Tmp 'bib2'
    [void](New-Item -ItemType Directory -Path (Join-Path $steam 'steamapps') -Force)
    [void](New-Item -ItemType Directory -Path (Join-Path $bib 'steamapps\common') -Force)
    $juego = New-JuegoFalso (Join-Path $bib 'steamapps\common\Baro Raro')
    [System.IO.File]::WriteAllText((Join-Path $steam 'steamapps\libraryfolders.vdf'), ('"libraryfolders" { "0" { "path" "' + $steam.Replace('\', '\\') + '" } "1" { "path" "' + $bib.Replace('\', '\\') + '" "apps" { "602960" "1" } } }'))
    [System.IO.File]::WriteAllText((Join-Path $bib 'steamapps\appmanifest_602960.acf'), '"AppState" { "appid" "602960" "installdir" "Baro Raro" "buildid" "777" }')
    $r = Find-BLJuego -RaicesSteam @($steam) -SinSistema
    Afirmar ($null -ne $r) 'no lo encontro'
    AfirmarIgual $juego $r.Carpeta 'carpeta encontrada'
    AfirmarIgual '777' (Get-BLBuildIdSteam $juego) 'buildid leido desde la carpeta del juego'
}
Prueba 'juego: la carpeta recordada manda si vale, y se ignora si ya no vale' {
    $a = New-JuegoFalso (Join-Path $script:P_Tmp 'recordado')
    $r = Find-BLJuego -Recordada $a -SinSistema
    AfirmarIgual $a $r.Carpeta 'recordada valida'
    $r = Find-BLJuego -Recordada (Join-Path $script:P_Tmp 'no-existe') -SinSistema
    Afirmar ($null -eq $r) 'una carpeta que no existe no vale'
    Remove-Item -LiteralPath (Join-Path $a 'Content\ContentPackages\Vanilla.xml')
    Afirmar (-not (Test-BLCarpetaJuego $a)) 'sin Vanilla.xml no es una instalacion valida'
}
Prueba 'juego: limpia lo que arrastra una persona' {
    AfirmarIgual 'C:\Juegos\Barotrauma' (ConvertTo-BLCarpetaJuego '  "C:\Juegos\Barotrauma\Barotrauma.exe"  ') 'ruta del exe entre comillas'
    AfirmarIgual 'C:\Juegos\Barotrauma' (ConvertTo-BLCarpetaJuego 'C:\Juegos\Barotrauma\') 'carpeta con barra final'
    AfirmarIgual '' (ConvertTo-BLCarpetaJuego '   ') 'vacio'
}

# =================================================================================================== versiones
Prueba 'version: se compara como el juego (la revision no cuenta)' {
    AfirmarIgual 'igual' (Compare-BLVersion '1.13.4.0' '1.13.4.9') 'revision distinta'
    AfirmarIgual 'igual' (Compare-BLVersion '1.13.4' '1.13.4.0+6029cd01') 'con sufijo'
    AfirmarIgual 'mia-mas-vieja' (Compare-BLVersion '1.13.3.9' '1.13.4.0') 'compilacion menor'
    AfirmarIgual 'mia-mas-vieja' (Compare-BLVersion '1.9.9.0' '1.13.0.0') 'menor comparado como numero, no como texto'
    AfirmarIgual 'mia-mas-nueva' (Compare-BLVersion '2.0.0.0' '1.13.4.0') 'mayor'
    AfirmarIgual 'desconocida' (Compare-BLVersion $null '1.13.4.0') 'sin version'
    AfirmarIgual 'desconocida' (Compare-BLVersion 'hola' '1.13.4.0') 'basura'
}
Prueba 'version: se lee de la .dll sin cargarla, y la del contenido de Vanilla.xml' {
    $j = New-JuegoFalso (Join-Path $script:P_Tmp 'ver1') -Version '1.14.2.0'
    AfirmarIgual '1.14.2.0' (Get-BLVersionJuego $j) 'version del juego de pega'
    AfirmarIgual '1.14.2.0' (Get-BLVersionContenido $j) 'gameversion de Vanilla.xml'
    Afirmar ($null -eq (Get-BLVersionEnsamblado (Join-Path $j 'no-existe.dll'))) 'una dll que no existe'
    Afirmar ($null -eq (Get-BLVersionEnsamblado (Join-Path $j 'steam_api64.dll'))) 'un fichero que no es una dll'
}
Prueba 'version: instalacion REAL de este PC (solo lectura)' {
    $r = Find-BLJuego
    if ($null -eq $r) { Omitir 'en este PC no hay Barotrauma instalado' }
    $v = Get-BLVersionJuego $r.Carpeta
    Afirmar ($null -ne $v) ('no pude leer la version de ' + $r.Carpeta)
    $vs = Get-BLVersionEnsamblado (Join-Path $r.Carpeta 'DedicatedServer.dll')
    Afirmar ($null -ne $vs) 'no pude leer la version del servidor dedicado'
    AfirmarIgual 'igual' (Compare-BLVersion $v $vs) 'juego y servidor de la misma version'
    Write-Host ('            leido: ' + $r.Carpeta + '  juego ' + $v + '  servidor ' + $vs + '  (por ' + $r.Origen + ')') -ForegroundColor DarkGray
}

# =================================================================================================== nombres y ordenes
Prueba 'nombres: reglas del servidor para el nombre de jugador' {
    foreach ($bueno in @('Pepe', 'Pepe Luis', 'El_Capitan-2', ('Mu' + [char]0xF1 + 'oz'), "O'Brien")) { AfirmarIgual '' (Test-BLNombreJugador $bueno) ('deberia valer: ' + $bueno) }
    foreach ($malo in @('', '   ', 'a;b', 'a<b', 'a/b', 'a\b', 'a"b', 'a?b', '[clan]Pepe', 'Pepe:1', 'a@b', '-skipintro', ('x' * 33))) { Afirmar ((Test-BLNombreJugador $malo) -ne '') ('no deberia valer: ' + $malo) }
    AfirmarIgual '' (Test-BLNombreJugador ('x' * 32)) '32 letras justas'
    AfirmarIgual '' (Test-BLNombreServidor 'BAROVERGA') 'nombre de servidor normal'
    Afirmar ((Test-BLNombreServidor 'con "comillas"') -ne '') 'servidor con comillas'
    Afirmar ((Test-BLNombreServidor ('x' * 61)) -ne '') 'servidor de 61 letras'
}
Prueba 'orden del cliente: -connect es lo primero y la direccion es una IP con puerto' {
    $o = Get-BLArgumentosCliente -NombreServidor 'Sala de Steven' -Direccion '10.144.10.20' -Puerto 27015 -Jugador 'Pepe Luis'
    AfirmarIgual '-connect "Sala de Steven" 10.144.10.20:27015 -username "Pepe Luis" -skipintro' $o 'orden sin saludo tolerante'
    $o = Get-BLArgumentosCliente -NombreServidor 'S' -Direccion '127.0.0.1' -Puerto 29015 -Jugador 'A' -SaludoTolerante
    AfirmarIgual '-connect "S" 127.0.0.1:29015 -username "A" -skipintro -lenienthandshake' $o 'orden con saludo tolerante'
    $falla = $false
    try { [void](Get-BLArgumentosCliente -NombreServidor 'S' -Direccion 'mi.servidor.net' -Puerto 27015 -Jugador 'A') } catch { $falla = $true }
    Afirmar $falla 'un nombre DNS no puede llegar a la orden (el juego no los resuelve)'
    $falla = $false
    try { [void](Get-BLArgumentosCliente -NombreServidor 'S' -Direccion '10.0.0.1' -Puerto 70000 -Jugador 'A') } catch { $falla = $true }
    Afirmar $falla 'puerto fuera de rango'
}
Prueba 'orden del servidor: privado, con su puerto, y contrasena solo si la hay' {
    $o = Get-ALArgumentosServidor -Nombre 'Sala de Steven' -Puerto 27015 -MaxJugadores 8 -SaludoTolerante
    AfirmarIgual '-name "Sala de Steven" -port 27015 -queryport 27016 -public false -maxplayers 8 -nopassword -lenienthandshake' $o 'sin contrasena'
    $o = Get-ALArgumentosServidor -Nombre 'S' -Puerto 29015 -MaxJugadores 4 -Contrasena 'pez'
    AfirmarIgual '-name "S" -port 29015 -queryport 29016 -public false -maxplayers 4 -password "pez"' $o 'con contrasena'
}
Prueba 'comillas: argumentos con espacios, comillas y barras finales' {
    AfirmarIgual 'abc' (ConvertTo-BLArgumento 'abc') 'sin espacios'
    AfirmarIgual '"a b"' (ConvertTo-BLArgumento 'a b') 'con espacio'
    AfirmarIgual '"C:\con espacio\\"' (ConvertTo-BLArgumento 'C:\con espacio\') 'barra final doblada'
    AfirmarIgual '"di \"hola\""' (ConvertTo-BLArgumento 'di "hola"') 'comillas escapadas'
    AfirmarIgual '""' (ConvertTo-BLArgumento '') 'vacio'
}

# =================================================================================================== direcciones
Prueba 'red: pertenencia a una red e IP literales' {
    Afirmar (Test-BLMismaRed '10.10.10.5' '10.10.10.103' 24) 'misma /24'
    Afirmar (-not (Test-BLMismaRed '10.10.11.5' '10.10.10.103' 24)) 'otra /24'
    Afirmar (Test-BLMismaRed '10.144.1.1' '10.144.10.20' 16) 'misma /16'
    Afirmar (Test-BLMismaRed (IpTs 99 1 1) $script:BL_RangoTailscale 10) 'rango de Tailscale'
    Afirmar (-not (Test-BLMismaRed (IpTs 128 0 1) $script:BL_RangoTailscale 10)) 'fuera del rango de Tailscale'
    Afirmar (Test-BLMismaRed '200.1.2.3' '200.1.2.3' 32) '/32 igual'
    Afirmar (Test-BLIpLiteral '192.168.1.5') 'IP normal'
    foreach ($no in @('192.168.1', '192.168.1.256', 'localhost', '1', '0x7f.1', 'fd00::1', '10.0.0.1:27015', '')) { Afirmar (-not (Test-BLIpLiteral $no)) ('no es IP literal: ' + $no) }
}
Prueba 'red: clasifica las interfaces del dueno (medidas el 2026-10-08)' {
    $t = @{}
    foreach ($i in $P_InterfacesDelDueno) { $t[$i.Alias] = Get-BLTipoDeRed $i.Alias $i.Descripcion $i.Clase $i.Ip }
    AfirmarIgual 'radmin' $t['Radmin VPN'] 'Radmin'
    AfirmarIgual 'tailscale' $t['Tailscale'] 'Tailscale'
    AfirmarIgual 'hamachi' $t['Hamachi'] 'Hamachi'
    AfirmarIgual 'zerotier' $t['ZeroTier One [0123456789abcdef]'] 'ZeroTier'
    AfirmarIgual 'lan' $t['Wi-Fi'] 'Wi-Fi'
    AfirmarIgual 'descartar' $t['vEthernet (WSL (Hyper-V firewall))'] 'WSL'
    AfirmarIgual 'descartar' $t['Ethernet'] 'cable sin direccion (169.254)'
    AfirmarIgual 'descartar' $t['Loopback Pseudo-Interface 1'] 'bucle local'
    AfirmarIgual 'publica' (Get-BLTipoDeRed 'Ethernet' 'Realtek' 'Ethernet' '83.45.1.2') 'IP de internet directa en el PC'
    AfirmarIgual 'otra' (Get-BLTipoDeRed 'wg0' 'WireGuard Tunnel' 'Ethernet' '10.8.0.2') 'otra VPN'
    AfirmarIgual 'tailscale' (Get-BLTipoDeRed 'Raro' 'Adaptador' 'Ethernet' (IpTs 80 1 1)) 'por rango, sin nombre'
}
Prueba 'red: orden por defecto = red local y luego cada VPN; internet apagado' {
    $d = @(Get-BLDireccionesServidor -Interfaces $P_InterfacesDelDueno)
    AfirmarIgual 'lan,zerotier,radmin,hamachi,tailscale' (@($d | ForEach-Object { $_.red }) -join ',') 'orden de redes'
    AfirmarIgual '10.10.10.103' $d[0].direccion 'la primera es la red local'
    AfirmarIgual 'lan' $d[0].tipo 'tipo de la primera'
    AfirmarIgual 'vpn' $d[1].tipo 'tipo de ZeroTier'
    AfirmarIgual 16 $d[1].prefijo 'prefijo de ZeroTier'
    Afirmar (@($d | Where-Object { $_.tipo -eq 'internet' }).Count -eq 0) 'no debe salir ninguna direccion de internet por defecto'
    Afirmar (@($d | Where-Object { $_.direccion -like '172.22.*' -or $_.direccion -like '169.254.*' -or $_.direccion -like '127.*' }).Count -eq 0) 'no deben salir WSL, 169.254 ni bucle local'
}
Prueba 'red: orden a medida, exclusiones e internet puesto a mano (al final)' {
    $d = @(Get-BLDireccionesServidor -Interfaces $P_InterfacesDelDueno -Orden @('tailscale', 'lan') -Excluidas @() -Internet 'mi.casa.example' -PuertoInternet 30000)
    AfirmarIgual 'tailscale,lan,internet' (@($d | ForEach-Object { $_.red }) -join ',') 'orden a medida'
    AfirmarIgual 30000 $d[2].puerto 'puerto propio de internet'
    $d = @(Get-BLDireccionesServidor -Interfaces $P_InterfacesDelDueno -Excluidas @('hamachi', '26.10.20.30'))
    AfirmarIgual 'lan,zerotier,tailscale' (@($d | ForEach-Object { $_.red }) -join ',') 'excluir por nombre de red y por IP'
    $dos = @($P_InterfacesDelDueno) + @((New-Object psobject -Property @{ Alias = 'Ethernet 9'; Descripcion = 'Realtek'; Clase = 'Ethernet'; Ip = '192.168.50.2'; Prefijo = 24; TienePuerta = $false }))
    $d = @(Get-BLDireccionesServidor -Interfaces $dos)
    AfirmarIgual '10.10.10.103' $d[0].direccion 'entre dos redes locales, primero la que tiene puerta de enlace'
    AfirmarIgual '192.168.50.2' $d[1].direccion 'y despues la otra'
    AfirmarIgual 0 @(Get-BLDireccionesServidor -Interfaces @()).Count 'sin interfaces no hay direcciones'
}
Prueba 'red: el amigo sabe que redes del servidor tiene el y cuales no' {
    $amigo = @(
        (New-Object psobject -Property @{ Alias = 'Wi-Fi'; Descripcion = 'x'; Clase = 'Wireless80211'; Ip = '192.168.1.40'; Prefijo = 24; TienePuerta = $true }),
        (New-Object psobject -Property @{ Alias = 'ZeroTier One'; Descripcion = 'ZeroTier Virtual Port'; Clase = 'Ethernet'; Ip = '10.144.20.9'; Prefijo = 16; TienePuerta = $false }),
        (New-Object psobject -Property @{ Alias = 'Tailscale'; Descripcion = 'Tailscale Tunnel'; Clase = '53'; Ip = (IpTs 88 30 40); Prefijo = 32; TienePuerta = $false })
    )
    AfirmarIgual $false (Test-BLTengoEsaRed @{ red = 'lan'; direccion = '10.10.10.103'; prefijo = 24 } $amigo) 'red local de otra casa'
    AfirmarIgual $true (Test-BLTengoEsaRed @{ red = 'zerotier'; direccion = '10.144.10.20'; prefijo = 16 } $amigo) 'misma red de ZeroTier'
    AfirmarIgual $true (Test-BLTengoEsaRed @{ red = 'tailscale'; direccion = (IpTs 77 10 20); prefijo = 32 } $amigo) 'Tailscale (/32: se mira el rango)'
    AfirmarIgual $false (Test-BLTengoEsaRed @{ red = 'hamachi'; direccion = '25.10.20.30'; prefijo = 8 } $amigo) 'no tiene Hamachi'
    Afirmar ($null -eq (Test-BLTengoEsaRed @{ red = 'internet'; direccion = '83.1.2.3'; prefijo = 0 } $amigo)) 'de internet no se puede saber'
    AfirmarIgual $true (Test-BLTengoEsaRed @{ red = 'local'; direccion = '127.0.0.1'; prefijo = 8 } @()) 'este mismo PC'
}
Prueba 'red: lectura de las interfaces reales de este PC (solo lectura)' {
    $i = @(Get-BLInterfaces)
    Afirmar ($i.Count -ge 1) 'deberia haber al menos el bucle local'
    Afirmar (@($i | Where-Object { $_.Ip -eq '127.0.0.1' }).Count -eq 1) 'falta 127.0.0.1'
    foreach ($x in $i) { Afirmar (Test-BLIpLiteral $x.Ip) ('IP rara: ' + $x.Ip); Afirmar ($x.Prefijo -ge 0 -and $x.Prefijo -le 32) ('prefijo raro en ' + $x.Ip) }
}

# =================================================================================================== sonda
Prueba 'sonda: el saludo es byte a byte el de Lidgren (ejemplo del estudio)' {
    $b = New-BLDatagramaSaludo 'barolan?'
    AfirmarIgual 26 $b.Length 'largo total'
    AfirmarIgual '83 00 00 A8 00 08 62 61 72 6F 6C 61 6E 3F' ((@($b[0..13]) | ForEach-Object { $_.ToString('X2') }) -join ' ') 'cabecera + identificador'
    AfirmarIgual '00 00 80 3F' ((@($b[22..25]) | ForEach-Object { $_.ToString('X2') }) -join ' ') 'hora como float 1.0'
    $b = New-BLDatagramaSaludo
    AfirmarIgual 31 $b.Length 'largo con el identificador de la sonda'
    AfirmarIgual 208 ([int]$b[3] + [int]$b[4] * 256) 'largo de la carga en bits'
    Afirmar ($script:BL_IdSonda -ne $script:BL_IdJuego) 'la sonda limpia NO puede usar el identificador del juego'
    $falla = $false
    try { [void](Invoke-BLSondaLidgren -Destinos @(@{ direccion = '127.0.0.1'; puerto = 9 }) -Identificador 'barotrauma') } catch { $falla = $true }
    Afirmar $falla 'la sonda limpia debe negarse a usar "barotrauma"'
}
Prueba 'sonda: entiende las respuestas (Disconnect con texto, truncadas, basura)' {
    $t = [System.Text.Encoding]::ASCII.GetBytes('Wrong application identifier!')
    $d = [byte[]](@(0x87, 0, 0, 0xF0, 0, 0x1D) + $t)
    $m = Read-BLDatagramaLidgren $d $d.Length
    Afirmar $m.Valido 'deberia ser valido'
    AfirmarIgual 135 $m.Tipo 'tipo Disconnect'
    AfirmarIgual 'Wrong application identifier!' $m.Texto 'texto'
    $m = Read-BLDatagramaLidgren $d ($d.Length - 3)
    Afirmar (-not $m.Valido) 'truncado: no valido'
    $m = Read-BLDatagramaLidgren ([byte[]](1, 2, 3)) 3
    Afirmar (-not $m.Valido) 'tres bytes: no valido'
    $m = Read-BLDatagramaLidgren ([byte[]](0x87, 0, 0, 16, 0, 200, 65)) 7
    Afirmar ($m.Valido -and $null -eq $m.Texto) 'largo de texto mentiroso: sin texto y sin reventar'
}
Prueba 'sonda (servidor de mentira): contesta, y solo le llega UN saludo y ningun dato' {
    $s = Start-BLServidorFalso -Modo lidgren
    $r = @(Invoke-BLSonda -Modo limpia -Destinos @(@{ direccion = '127.0.0.1'; puerto = $s.Puerto }))
    $rec = Stop-BLServidorFalso $s
    AfirmarIgual 'contesta' $r[0].Estado 'estado'
    AfirmarIgual 'Wrong application identifier!' $r[0].Detalle 'texto de la respuesta'
    Afirmar ($r[0].Ms -ge 0 -and $r[0].Ms -lt 450) ('tiempo de respuesta raro: ' + $r[0].Ms)
    AfirmarIgual 1 $rec.Count 'datagramas que recibio el servidor'
    AfirmarIgual 131 ([int]$rec[0][0]) 'tipo del datagrama (Connect)'
    AfirmarIgual 31 $rec[0].Length 'largo del datagrama'
    AfirmarIgual 'barolan-sonda' ([System.Text.Encoding]::ASCII.GetString($rec[0], 6, [int]$rec[0][5])) 'identificador enviado'
}
Prueba 'sonda (servidor de mentira): si no contesta, exactamente 2 saludos y nada mas' {
    $s = Start-BLServidorFalso -Modo mudo
    $reloj = [System.Diagnostics.Stopwatch]::StartNew()
    $r = @(Invoke-BLSonda -Modo limpia -Destinos @(@{ direccion = '127.0.0.1'; puerto = $s.Puerto }) -EsperaMs 200 -Intentos 2)
    $ms = $reloj.ElapsedMilliseconds
    $rec = Stop-BLServidorFalso $s
    AfirmarIgual 'silencio' $r[0].Estado 'estado'
    AfirmarIgual 2 $rec.Count 'saludos enviados'
    foreach ($x in $rec) { AfirmarIgual 131 ([int]$x[0]) 'solo saludos Connect' }
    Afirmar ($ms -ge 380 -and $ms -lt 1500) ('deberia tardar unos 400 ms y tardo ' + $ms)
}
Prueba 'sonda (servidor de mentira): NUNCA manda mensajes de datos (tipos 1 a 98), en ningun caso' {
    $total = 0
    foreach ($modo in @('lidgren', 'lleno', 'mudo', 'basura', 'texto')) {
        $s = Start-BLServidorFalso -Modo $modo
        [void](Invoke-BLSonda -Modo limpia -Destinos @(@{ direccion = '127.0.0.1'; puerto = $s.Puerto }) -EsperaMs 120 -Intentos 3)
        $rec = Stop-BLServidorFalso $s
        foreach ($x in $rec) { $total++; Afirmar ([int]$x[0] -eq 131) ('en modo ' + $modo + ' se mando un datagrama de tipo ' + [int]$x[0]) }
    }
    Afirmar ($total -ge 5) 'no llego nada a los servidores de mentira'
}
Prueba 'sonda (servidor de mentira): servidor lleno, respuestas raras y puerto cerrado' {
    $lleno = Start-BLServidorFalso -Modo lleno
    $basura = Start-BLServidorFalso -Modo basura
    $texto = Start-BLServidorFalso -Modo texto
    $cerrado = Get-BLPuertoCerrado
    $r = @(Invoke-BLSonda -Modo limpia -EsperaMs 300 -Destinos @(
            @{ direccion = '127.0.0.1'; puerto = $lleno.Puerto }, @{ direccion = '127.0.0.1'; puerto = $basura.Puerto },
            @{ direccion = '127.0.0.1'; puerto = $texto.Puerto }, @{ direccion = '127.0.0.1'; puerto = $cerrado }, @{ direccion = 'no-es-ip'; puerto = 1 }))
    [void](Stop-BLServidorFalso $lleno); [void](Stop-BLServidorFalso $basura); [void](Stop-BLServidorFalso $texto)
    AfirmarIgual 'contesta' $r[0].Estado 'lleno: el servidor esta'
    AfirmarIgual 'Server full' $r[0].Detalle 'lleno: texto'
    AfirmarIgual 'raro' $r[1].Estado 'basura'
    AfirmarIgual 'raro' $r[2].Estado 'texto que no es Lidgren'
    Afirmar (@('puerto-cerrado', 'silencio') -contains $r[3].Estado) ('puerto cerrado: salio ' + $r[3].Estado)
    AfirmarIgual 'error' $r[4].Estado 'direccion que no es IP'
    Write-Host ('            puerto cerrado en 127.0.0.1 -> ' + $r[3].Estado) -ForegroundColor DarkGray
}
Prueba 'sonda (servidor de mentira): varias a la vez; gana la primera POR ORDEN que contesta' {
    $mudo = Start-BLServidorFalso -Modo mudo
    $a = Start-BLServidorFalso -Modo lidgren
    $b = Start-BLServidorFalso -Modo lidgren
    $c = @(
        (New-Object psobject -Property @{ Direccion = '127.0.0.1'; Puerto = $mudo.Puerto; Estado = ''; Detalle = ''; Ms = -1; EnMiRed = $true }),
        (New-Object psobject -Property @{ Direccion = '127.0.0.1'; Puerto = $a.Puerto; Estado = ''; Detalle = ''; Ms = -1; EnMiRed = $true }),
        (New-Object psobject -Property @{ Direccion = '127.0.0.1'; Puerto = $b.Puerto; Estado = ''; Detalle = ''; Ms = -1; EnMiRed = $true })
    )
    $reloj = [System.Diagnostics.Stopwatch]::StartNew()
    $r = @(Invoke-BLSonda -Modo limpia -Destinos $c -EsperaMs 250 -Intentos 2)
    $ms = $reloj.ElapsedMilliseconds
    [void](Stop-BLServidorFalso $mudo); [void](Stop-BLServidorFalso $a); [void](Stop-BLServidorFalso $b)
    for ($i = 0; $i -lt 3; $i++) { $c[$i].Estado = $r[$i].Estado }
    AfirmarIgual 'silencio,contesta,contesta' (@($r | ForEach-Object { $_.Estado }) -join ',') 'estados en el mismo orden'
    AfirmarIgual 1 (Select-BLDestino $c) 'elegida'
    Afirmar ($ms -lt 1200) ('tres direcciones a la vez no deben sumar esperas: tardo ' + $ms + ' ms')
}
Prueba 'sonda: sin sonda se elige la primera red que este PC tiene; con todo en silencio, ninguna' {
    $c = @(
        (New-Object psobject -Property @{ Direccion = '10.0.0.1'; Puerto = 1; Estado = 'sin-sondear'; EnMiRed = $false }),
        (New-Object psobject -Property @{ Direccion = '10.0.0.2'; Puerto = 1; Estado = 'sin-sondear'; EnMiRed = $null }),
        (New-Object psobject -Property @{ Direccion = '10.0.0.3'; Puerto = 1; Estado = 'sin-sondear'; EnMiRed = $true })
    )
    AfirmarIgual 2 (Select-BLDestino $c) 'sin sonda'
    foreach ($x in $c) { $x.Estado = 'silencio' }
    AfirmarIgual -1 (Select-BLDestino $c) 'todo en silencio'
    $c[1].Estado = 'puerto-cerrado'; $c[2].Estado = 'raro'
    AfirmarIgual -1 (Select-BLDestino $c) 'ni puerto cerrado ni respuesta rara se eligen solos'
    $r = @(Invoke-BLSonda -Modo ninguna -Destinos @(@{ direccion = '10.0.0.1'; puerto = 5 }))
    AfirmarIgual 'sin-sondear' $r[0].Estado 'modo ninguna'
    AfirmarIgual 0 $r[0].Enviados 'modo ninguna no manda nada'
}
Prueba 'sonda COMPLETA (solo laboratorio; servidor de mentira): saludo, respuesta y un Disconnect de cierre' {
    $s = Start-BLServidorFalso -Modo lidgren
    $r = @(Invoke-BLSondaLidgren -Destinos @(@{ direccion = '127.0.0.1'; puerto = $s.Puerto }) -Completa)
    $rec = Stop-BLServidorFalso $s
    AfirmarIgual 'contesta' $r[0].Estado 'estado'
    AfirmarIgual 2 $rec.Count 'datagramas'
    AfirmarIgual 131 ([int]$rec[0][0]) 'primero el saludo'
    AfirmarIgual 135 ([int]$rec[1][0]) 'despues el Disconnect de cierre'
    foreach ($x in $rec) { Afirmar ([int]$x[0] -ge 128) 'ningun mensaje de datos' }
}
Prueba 'sonda suelta para el laboratorio (sondear.ps1, contra el servidor de mentira)' {
    $s = Start-BLServidorFalso -Modo lidgren
    $r = Invoke-Guion (Join-Path $P_Aqui 'sondear.ps1') @('-Direccion', '127.0.0.1', '-Puerto', ([string]$s.Puerto), '-Veces', '3', '-PausaMs', '10')
    $rec = Stop-BLServidorFalso $s
    AfirmarIgual 0 $r.Codigo ('codigo. Salida: ' + $r.Salida)
    Afirmar ($r.Salida -match 'RESUMEN: 3/3 contestadas') ('resumen inesperado: ' + $r.Salida)
    AfirmarIgual 3 $rec.Count 'un saludo por repeticion'
    $r = Invoke-Guion (Join-Path $P_Aqui 'sondear.ps1') @('-Direccion', '127.0.0.1', '-Puerto', ([string](Get-BLPuertoCerrado)), '-EsperaMs', '100')
    AfirmarIgual 1 $r.Codigo 'si no contesta, codigo 1'
}
Prueba 'diagnostico: frases segun lo que se sabe de cada direccion' {
    $c = @(
        (New-Object psobject -Property @{ Etiqueta = 'Red local'; Direccion = '10.10.10.103'; Puerto = 27015; Tipo = 'lan'; Estado = 'silencio'; EnMiRed = $false; Ping = $false; Detalle = '' }),
        (New-Object psobject -Property @{ Etiqueta = 'ZeroTier'; Direccion = '10.144.10.20'; Puerto = 27015; Tipo = 'vpn'; Estado = 'silencio'; EnMiRed = $false; Ping = $false; Detalle = '' }),
        (New-Object psobject -Property @{ Etiqueta = 'Radmin VPN'; Direccion = '26.10.20.30'; Puerto = 27015; Tipo = 'vpn'; Estado = 'silencio'; EnMiRed = $true; Ping = $true; Detalle = '' }),
        (New-Object psobject -Property @{ Etiqueta = 'Hamachi'; Direccion = '25.10.20.30'; Puerto = 27015; Tipo = 'vpn'; Estado = 'puerto-cerrado'; EnMiRed = $true; Ping = $false; Detalle = '' }),
        (New-Object psobject -Property @{ Etiqueta = 'Tailscale'; Direccion = (IpTs 77 10 20); Puerto = 27015; Tipo = 'vpn'; Estado = 'silencio'; EnMiRed = $true; Ping = $false; Detalle = '' })
    )
    $l = @(Get-BLDiagnostico -Candidatas $c -Anfitrion 'Steven')
    AfirmarIgual 6 $l.Count 'una frase por direccion y la pregunta final'
    Afirmar ($l[0] -match 'no esta en la red local de Steven') 'red local de otra casa'
    Afirmar ($l[1] -match 'no tiene ZeroTier conectado') 'VPN sin conectar'
    Afirmar ($l[2] -match 'contesta, pero el servidor no') 'ping si, servidor no'
    Afirmar ($l[3] -match 'servidor NO esta abierto') 'puerto cerrado'
    Afirmar ($l[4] -match 'cortafuegos de Steven') 'silencio con la red puesta'
    Afirmar ($l[5] -match 'servidor abierto') 'pregunta final'
}

# =================================================================================================== datos
Prueba 'servidor.json: ida y vuelta, y se descarta 127.x (seria el PC del propio amigo)' {
    $dir = @(Get-BLDireccionesServidor -Interfaces $P_InterfacesDelDueno)
    $dir += [ordered]@{ red = 'lan'; tipo = 'lan'; direccion = '127.0.0.1'; prefijo = 8; etiqueta = 'Bucle' }
    $ruta = New-DatosServidorDePrueba -Nombre 'ida-y-vuelta' -Direcciones $dir -Puerto 27015 -Contrasena 'pez'
    $s = Read-BLDatosServidor $ruta
    Afirmar $s.Ok ('deberia leerse: ' + $s.Error)
    AfirmarIgual 'Sala de prueba' $s.Nombre 'nombre'
    AfirmarIgual 27015 $s.Puerto 'puerto'
    AfirmarIgual '1.13.4.0' $s.Version 'version'
    AfirmarIgual 'Anfi' $s.Anfitrion 'anfitrion'
    AfirmarIgual 'pez' $s.Contrasena 'contrasena'
    AfirmarIgual 'vpn' $s.SaludoTolerante 'saludo tolerante'
    AfirmarIgual 5 @($s.Direcciones).Count 'direcciones (sin la 127.x)'
    AfirmarIgual 27015 $s.Direcciones[0].puerto 'cada direccion hereda el puerto'
    $s = Read-BLDatosServidor -Ruta $ruta -PermitirBucle
    AfirmarIgual 6 @($s.Direcciones).Count 'con -PermitirBucle se queda la 127.x'
}
Prueba 'servidor.json: con una sola direccion sigue siendo una lista; la contrasena puede no viajar' {
    $d = New-ALDatosServidor -Nombre 'S' -Puerto 27015 -Version '1.13.4.0' -Anfitrion 'A' -Contrasena 'pez' -IncluirContrasena $false -SaludoTolerante $false -Direcciones @([ordered]@{ red = 'lan'; tipo = 'lan'; direccion = '192.168.1.5'; prefijo = 24; etiqueta = 'Red local' })
    $ruta = Join-Path $script:P_Tmp 'una.json'
    Write-BLJson $ruta $d
    $crudo = [System.IO.File]::ReadAllText($ruta)
    Afirmar ($crudo -match '"direcciones":\s*\[') 'direcciones debe escribirse como lista'
    Afirmar ($crudo -notmatch 'pez') 'la contrasena no debe estar en el fichero'
    $s = Read-BLDatosServidor $ruta
    Afirmar $s.Ok $s.Error
    Afirmar $s.TieneContrasena 'pero se sabe que hay contrasena'
    AfirmarIgual '' $s.Contrasena 'contrasena vacia'
    AfirmarIgual 'nunca' $s.SaludoTolerante 'saludo tolerante apagado'
}
Prueba 'servidor.json: los ficheros malos se rechazan con una frase' {
    $casos = @{
        'no-json'      = 'esto no es json'
        'otro-formato' = '{"formato":99,"servidor":{"nombre":"S","puerto":27015,"version":"1.13.4.0"},"direcciones":[{"red":"lan","direccion":"10.0.0.1"}]}'
        'sin-version'  = '{"formato":1,"servidor":{"nombre":"S","puerto":27015},"direcciones":[{"red":"lan","direccion":"10.0.0.1"}]}'
        'puerto-malo'  = '{"formato":1,"servidor":{"nombre":"S","puerto":0,"version":"1.13.4.0"},"direcciones":[{"red":"lan","direccion":"10.0.0.1"}]}'
        'sin-dirs'     = '{"formato":1,"servidor":{"nombre":"S","puerto":27015,"version":"1.13.4.0"},"direcciones":[]}'
        'dns-en-lan'   = '{"formato":1,"servidor":{"nombre":"S","puerto":27015,"version":"1.13.4.0"},"direcciones":[{"red":"lan","direccion":"mipc"}]}'
        'nombre-malo'  = '{"formato":1,"servidor":{"nombre":"S\"x","puerto":27015,"version":"1.13.4.0"},"direcciones":[{"red":"lan","direccion":"10.0.0.1"}]}'
        'sonda-rara'   = '{"formato":1,"sonda":"bomba","servidor":{"nombre":"S","puerto":27015,"version":"1.13.4.0"},"direcciones":[{"red":"lan","direccion":"10.0.0.1"}]}'
    }
    foreach ($k in $casos.Keys) {
        $ruta = Join-Path $script:P_Tmp ('malo-' + $k + '.json')
        [System.IO.File]::WriteAllText($ruta, $casos[$k])
        $s = Read-BLDatosServidor $ruta
        Afirmar (-not $s.Ok) ('deberia rechazarse: ' + $k)
        Afirmar ($s.Error.Length -gt 5) ('sin explicacion: ' + $k)
    }
    $s = Read-BLDatosServidor (Join-Path $script:P_Tmp 'no-existe.json')
    Afirmar (-not $s.Ok) 'un fichero que no existe'
}
Prueba 'jugador: nombre y carpeta se recuerdan fuera del juego' {
    $c = Join-Path $script:P_Tmp 'datos-jugador'
    $d = Read-BLDatosJugador $c
    AfirmarIgual '' $d.Jugador 'al principio no hay nombre'
    Afirmar (Save-BLDatosJugador -Carpeta $c -Jugador ('Mu' + [char]0xF1 + 'oz') -CarpetaJuego 'D:\Juegos\Barotrauma') 'deberia guardarse'
    $d = Read-BLDatosJugador $c
    AfirmarIgual ('Mu' + [char]0xF1 + 'oz') $d.Jugador 'nombre con letra no ASCII'
    AfirmarIgual 'D:\Juegos\Barotrauma' $d.CarpetaJuego 'carpeta'
    Afirmar ((Get-BLCarpetaDatos '') -like '*\BarotraumaLAN') 'por omision va a %APPDATA%\BarotraumaLAN'
}

# =================================================================================================== anfitrion
Prueba 'ajustes: se crean con valores de fabrica, se completan y se validan' {
    $ruta = Join-Path $script:P_Tmp 'aj1\ajustes-anfitrion.json'
    $r = Read-ALAjustes -Ruta $ruta
    Afirmar (-not (Test-Path -LiteralPath $ruta)) 'sin -Crear no debe escribir'
    $r = Read-ALAjustes -Ruta $ruta -Crear
    Afirmar (Test-Path -LiteralPath $ruta) 'con -Crear debe escribirlo'
    AfirmarIgual 27715 $r.Ajustes.puerto 'puerto de fabrica (no el 27015 del juego)'
    AfirmarIgual '' $r.Ajustes.direccionInternet 'internet apagado de fabrica'
    AfirmarIgual 'pendiente' $r.Ajustes.identidad 'identidad pendiente de la medida del laboratorio'
    AfirmarIgual 'lan,zerotier,radmin,hamachi,tailscale,otra' (@($r.Ajustes.ordenRedes) -join ',') 'orden: red local y luego cada VPN'
    AfirmarIgual 0 @(Test-ALAjustes $r.Ajustes).Count 'los de fabrica valen'
    [System.IO.File]::WriteAllText($ruta, '{ "puerto": 29015, "nombreServidor": "Mi sala", "ordenRedes": ["tailscale"], "saludoTolerante": false }')
    $r = Read-ALAjustes -Ruta $ruta
    AfirmarIgual 29015 $r.Ajustes.puerto 'puerto leido'
    AfirmarIgual 'tailscale' (@($r.Ajustes.ordenRedes) -join ',') 'lista de un solo elemento'
    AfirmarIgual $false $r.Ajustes.saludoTolerante 'booleano leido'
    AfirmarIgual 8 $r.Ajustes.maxJugadores 'lo que falta se rellena'
    AfirmarIgual 'propios' $r.Ajustes.datos 'datos del servidor propios de fabrica'
    $r.Ajustes.puerto = 80; $r.Ajustes.maxJugadores = 40; $r.Ajustes.contrasena = 'con espacio'; $r.Ajustes.identidad = 'rara'; $r.Ajustes.recetaPorNombre = @('..\x.dll'); $r.Ajustes.datos = 'otros'
    AfirmarIgual 6 @(Test-ALAjustes $r.Ajustes).Count 'seis ajustes malos, seis pegas'
    [System.IO.File]::WriteAllText($ruta, 'roto {')
    $falla = $false
    try { [void](Read-ALAjustes -Ruta $ruta) } catch { $falla = $true }
    Afirmar $falla 'un JSON roto debe avisar, no usar los de fabrica en silencio'
}
Prueba 'carpeta del servidor: sitios donde NO se puede poner' {
    $juego = 'D:\SteamLibrary\steamapps\common\Barotrauma'
    AfirmarIgual '' (Test-ALRaizSegura 'D:\BarotraumaLAN' $juego) 'sitio normal'
    AfirmarIgual 'D:\BarotraumaLAN' (Get-ALRaizServidor @{ carpetaServidor = '' } $juego) 'por omision, en la unidad del juego'
    AfirmarIgual 'E:\Otra' (Get-ALRaizServidor @{ carpetaServidor = 'E:\Otra\' } $juego) 'la de los ajustes'
    foreach ($mala in @('', 'D:\', 'relativa\carpeta', ($juego + '\servidor'), $juego, 'D:\SteamLibrary', 'D:\SteamLibrary\steamapps\otra', (Join-Path $env:LOCALAPPDATA 'Daedalic Entertainment GmbH\Barotrauma\x'))) {
        Afirmar ((Test-ALRaizSegura $mala $juego) -ne '') ('deberia rechazarse: ' + $mala)
    }
}
Prueba 'carpeta del servidor: se crea con copias + union a Content, sin el estado del dueno, y el juego no se toca' {
    $juego = New-JuegoFalso (Join-Path $script:P_Tmp 'j-sync\steamapps\common\Barotrauma')
    $raiz = Join-Path $script:P_Tmp 'srv-sync'
    $antes = Get-HuellaCarpeta $juego
    $m = Sync-ALCarpetaServidor -CarpetaJuego $juego -Raiz $raiz -SoloMirar
    Afirmar ($m.Nuevo -and $m.Pendientes -gt 0) 'mirando: deberia decir que es nueva y que faltan ficheros'
    Afirmar (-not (Test-Path -LiteralPath $raiz)) 'mirando no debe crear nada'
    $r = Sync-ALCarpetaServidor -CarpetaJuego $juego -Raiz $raiz
    [void]$script:P_Uniones.Add((Join-Path $r.Destino 'Content'))
    Afirmar $r.Nuevo 'deberia ser nueva'
    AfirmarIgual '1.13.4.0' $r.VersionAhora 'version'
    AfirmarIgual 'creada' $r.Union 'union'
    foreach ($debe in @('DedicatedServer.exe', 'DedicatedServer.dll', 'Barotrauma.dll', 'steam_api64.dll', 'Lidgren.NetStandard.dll', 'x64\SDL2.dll', 'Data\karmasettings.xml', 'Data\permissionpresets.xml', 'Content\ContentPackages\Vanilla.xml', 'Content\Items\cosa.xml', 'barolan-carpeta.json')) {
        Afirmar (Test-Path -LiteralPath (Join-Path $r.Destino $debe) -PathType Leaf) ('falta en la carpeta del servidor: ' + $debe)
    }
    Afirmar (Test-Path -LiteralPath (Join-Path $r.Destino 'LocalMods') -PathType Container) 'falta LocalMods'
    foreach ($nodebe in @('config_player.xml', 'serversettings.xml', 'crashreport.log', 'creature_metrics.xml', 'Data\clientpermissions.xml', 'Data\bannedplayers.xml', 'ServerLogs\viejo.txt', 'LocalMods\info.txt')) {
        Afirmar (-not (Test-Path -LiteralPath (Join-Path $r.Destino $nodebe))) ('NO deberia haberse copiado: ' + $nodebe)
    }
    $u = Get-Item -LiteralPath (Join-Path $r.Destino 'Content') -Force
    Afirmar ([bool]($u.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) 'Content deberia ser una union, no una copia'
    AfirmarIgual (Join-Path $juego 'Content') (Get-ALDestinoUnion (Join-Path $r.Destino 'Content')) 'destino de la union'
    AfirmarIgual $antes (Get-HuellaCarpeta $juego) 'la carpeta del juego debe quedar identica'
    $r2 = Sync-ALCarpetaServidor -CarpetaJuego $juego -Raiz $raiz
    Afirmar (-not $r2.Nuevo -and -not $r2.Actualizado) 'la segunda pasada no es nueva ni actualizada'
    AfirmarIgual 0 $r2.Copiados 'la segunda pasada no copia nada'
    AfirmarIgual 'estaba' $r2.Union 'la union ya estaba'
}
Prueba 'carpeta del servidor: detecta que el juego se actualizo, la rehace y guarda antes lo del servidor' {
    $juego = New-JuegoFalso (Join-Path $script:P_Tmp 'j-act\steamapps\common\Barotrauma') -Version '1.13.4.0'
    $raiz = Join-Path $script:P_Tmp 'srv-act'
    $r = Sync-ALCarpetaServidor -CarpetaJuego $juego -Raiz $raiz
    [void]$script:P_Uniones.Add((Join-Path $r.Destino 'Content'))
    # el servidor "ha escrito" su estado
    [System.IO.File]::WriteAllText((Join-Path $r.Destino 'serversettings.xml'), '<serversettings ServerName="Lo mio" />')
    [System.IO.File]::WriteAllText((Join-Path $r.Destino 'Data\clientpermissions.xml'), '<ClientPermissions />')
    [System.IO.File]::WriteAllText((Join-Path $r.Destino 'Data\karmasettings.xml'), '<karma tocado="si" />')
    [System.IO.File]::WriteAllText((Join-Path $r.Destino 'fichero-mio.txt'), 'no lo copio la herramienta')
    # "actualizacion" del juego: version nueva, un fichero cambia, uno desaparece, uno aparece
    $dll = Get-DllConVersion '1.14.0.0'
    Copy-Item -LiteralPath $dll -Destination (Join-Path $juego 'Barotrauma.dll') -Force
    Copy-Item -LiteralPath $dll -Destination (Join-Path $juego 'DedicatedServer.dll') -Force
    [System.IO.File]::WriteAllText((Join-Path $juego 'Lidgren.NetStandard.dll'), 'pega mas larga, version nueva')
    Remove-Item -LiteralPath (Join-Path $juego 'EOSSDK-Win64-Shipping.dll')
    [System.IO.File]::WriteAllText((Join-Path $juego 'Nueva.dll'), 'nueva')
    $m = Sync-ALCarpetaServidor -CarpetaJuego $juego -Raiz $raiz -SoloMirar
    Afirmar $m.Actualizado 'mirando: deberia detectar la actualizacion'
    AfirmarIgual '1.13.4.0' $m.VersionAntes 'version anterior'
    AfirmarIgual '1.14.0.0' $m.VersionAhora 'version nueva'
    $r = Sync-ALCarpetaServidor -CarpetaJuego $juego -Raiz $raiz
    Afirmar $r.Actualizado 'deberia rehacerse'
    AfirmarIgual '1.14.0.0' (Get-BLVersionEnsamblado (Join-Path $r.Destino 'DedicatedServer.dll')) 'version del servidor tras rehacer'
    AfirmarIgual 'pega mas larga, version nueva' ([System.IO.File]::ReadAllText((Join-Path $r.Destino 'Lidgren.NetStandard.dll'))) 'fichero cambiado'
    Afirmar (Test-Path -LiteralPath (Join-Path $r.Destino 'Nueva.dll')) 'fichero nuevo'
    Afirmar (-not (Test-Path -LiteralPath (Join-Path $r.Destino 'EOSSDK-Win64-Shipping.dll'))) 'el fichero que ya no trae el juego se quita'
    AfirmarIgual 1 $r.Borrados 'solo se borra lo que copio la herramienta'
    Afirmar (Test-Path -LiteralPath (Join-Path $r.Destino 'fichero-mio.txt')) 'un fichero que no copio la herramienta NO se borra'
    AfirmarIgual '<serversettings ServerName="Lo mio" />' ([System.IO.File]::ReadAllText((Join-Path $r.Destino 'serversettings.xml'))) 'serversettings.xml del servidor se conserva'
    Afirmar (Test-Path -LiteralPath (Join-Path $r.Destino 'Data\clientpermissions.xml')) 'los permisos del servidor se conservan'
    Afirmar ($r.Respaldo -and (Test-Path -LiteralPath (Join-Path $r.Respaldo 'serversettings.xml'))) 'falta el respaldo de serversettings.xml'
    AfirmarIgual '<karma tocado="si" />' ([System.IO.File]::ReadAllText((Join-Path $r.Respaldo 'Data\karmasettings.xml'))) 'el respaldo guarda lo que el servidor habia escrito'
    AfirmarIgual '<karma />' ([System.IO.File]::ReadAllText((Join-Path $r.Destino 'Data\karmasettings.xml'))) 'tras la actualizacion, los datos de fabrica nuevos'
    $r3 = Sync-ALCarpetaServidor -CarpetaJuego $juego -Raiz $raiz
    Afirmar (-not $r3.Actualizado -and $r3.Copiados -eq 0) 'despues ya esta al dia'
}
Prueba 'carpeta del servidor: receta "por nombre" (SIN MEDIR) = no copiar steam_api64.dll, y vuelta atras' {
    $juego = New-JuegoFalso (Join-Path $script:P_Tmp 'j-id\steamapps\common\Barotrauma')
    $raiz = Join-Path $script:P_Tmp 'srv-id'
    $r = Sync-ALCarpetaServidor -CarpetaJuego $juego -Raiz $raiz
    [void]$script:P_Uniones.Add((Join-Path $r.Destino 'Content'))
    Afirmar (Test-Path -LiteralPath (Join-Path $r.Destino 'steam_api64.dll')) 'de fabrica se copia'
    $r = Sync-ALCarpetaServidor -CarpetaJuego $juego -Raiz $raiz -NoCopiar @('STEAM_API64.dll')
    Afirmar (-not (Test-Path -LiteralPath (Join-Path $r.Destino 'steam_api64.dll'))) 'con la receta, se quita de la carpeta del servidor'
    Afirmar (Test-Path -LiteralPath (Join-Path $juego 'steam_api64.dll')) 'pero NUNCA del juego'
    $r = Sync-ALCarpetaServidor -CarpetaJuego $juego -Raiz $raiz
    Afirmar (Test-Path -LiteralPath (Join-Path $r.Destino 'steam_api64.dll')) 'sin la receta, vuelve'
}
Prueba 'carpeta del servidor: no pisa una carpeta ajena ni una Content que no sea una union' {
    $juego = New-JuegoFalso (Join-Path $script:P_Tmp 'j-ajena\steamapps\common\Barotrauma')
    $raiz = Join-Path $script:P_Tmp 'srv-ajena'
    [void](New-Item -ItemType Directory -Path (Join-Path $raiz 'servidor') -Force)
    [System.IO.File]::WriteAllText((Join-Path $raiz 'servidor\algo.txt'), 'de otro')
    $falla = $false
    try { [void](Sync-ALCarpetaServidor -CarpetaJuego $juego -Raiz $raiz) } catch { $falla = $true }
    Afirmar $falla 'una carpeta con cosas y sin manifiesto no se toca'
    $raiz2 = Join-Path $script:P_Tmp 'srv-content-real'
    [void](New-Item -ItemType Directory -Path (Join-Path $raiz2 'servidor\Content') -Force)
    [System.IO.File]::WriteAllText((Join-Path $raiz2 'servidor\Content\importante.txt'), 'no borrar')
    [System.IO.File]::WriteAllText((Join-Path $raiz2 'servidor\barolan-carpeta.json'), '{"formato":1,"versionJuego":"1.13.4.0","ficheros":[]}')
    $falla = $false
    try { [void](Sync-ALCarpetaServidor -CarpetaJuego $juego -Raiz $raiz2) } catch { $falla = $true }
    Afirmar $falla 'una Content que es carpeta de verdad no se toca'
    Afirmar (Test-Path -LiteralPath (Join-Path $raiz2 'servidor\Content\importante.txt')) 'y su contenido sigue ahi'
    $sin = New-JuegoFalso (Join-Path $script:P_Tmp 'j-sinservidor') -SinServidor
    $falla = $false
    try { [void](Sync-ALCarpetaServidor -CarpetaJuego $sin -Raiz (Join-Path $script:P_Tmp 'srv-sin')) } catch { $falla = $true }
    Afirmar $falla 'sin DedicatedServer.exe en el juego debe avisar'
}
Prueba 'union: quitarla NO borra lo que hay detras; si el juego se muda, se rehace' {
    $juegoA = New-JuegoFalso (Join-Path $script:P_Tmp 'j-unionA')
    $juegoB = New-JuegoFalso (Join-Path $script:P_Tmp 'j-unionB')
    $destino = Join-Path $script:P_Tmp 'srv-union'
    [void](New-Item -ItemType Directory -Path $destino -Force)
    [void]$script:P_Uniones.Add((Join-Path $destino 'Content'))
    AfirmarIgual 'creada' (Set-ALUnionContent -CarpetaJuego $juegoA -Destino $destino) 'primera vez'
    AfirmarIgual 'estaba' (Set-ALUnionContent -CarpetaJuego $juegoA -Destino $destino) 'segunda vez'
    $antesA = Get-HuellaCarpeta $juegoA
    AfirmarIgual 'rehecha' (Set-ALUnionContent -CarpetaJuego $juegoB -Destino $destino) 'el juego se mudo'
    AfirmarIgual (Join-Path $juegoB 'Content') (Get-ALDestinoUnion (Join-Path $destino 'Content')) 'ahora apunta al nuevo'
    AfirmarIgual $antesA (Get-HuellaCarpeta $juegoA) 'el Content del juego anterior sigue intacto'
    $antesB = Get-HuellaCarpeta $juegoB
    Afirmar (Remove-ALUnion (Join-Path $destino 'Content')) 'deberia quitarla'
    Afirmar (-not (Test-Path -LiteralPath (Join-Path $destino 'Content'))) 'la union ya no esta'
    AfirmarIgual $antesB (Get-HuellaCarpeta $juegoB) 'y el Content del juego sigue intacto'
    Afirmar (-not (Remove-ALUnion (Join-Path $juegoB 'Content'))) 'una carpeta de verdad NO se quita con Remove-ALUnion'
    Afirmar (Test-Path -LiteralPath (Join-Path $juegoB 'Content\Items\cosa.xml')) 'y sigue con sus ficheros'
}
Prueba 'serversettings.xml: nuevo, con lo imprescindible (privado, sin autenticacion, mods desde el servidor)' {
    $ruta = Join-Path $script:P_Tmp 'xml1\serversettings.xml'
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $ruta) -Force)
    $v = Get-ALValoresServidor -Nombre 'Mi sala' -Puerto 29015 -MaxJugadores 6 -Contrasena ''
    $r = Set-ALAjustesServidorXml -Ruta $ruta -Forzados $v -Iniciales @{ BanAfterWrongPassword = 'False' }
    Afirmar ($r.Creado -and $r.Cambiado -and -not $r.Sembrado) 'creado de cero'
    $x = New-Object System.Xml.XmlDocument
    $x.Load($ruta)
    $e = $x.DocumentElement
    AfirmarIgual 'serversettings' $e.Name 'raiz'
    $esperado = @{ port = '29015'; queryport = '29016'; password = ''; enableupnp = 'false'; ServerName = 'Mi sala'; IsPublic = 'False'; RequireAuthentication = 'False'
        AllowModDownloads = 'True'; AllowFileTransfers = 'True'; MaxPlayers = '6'; SaveServerLogs = 'True'; BanAfterWrongPassword = 'False' }
    foreach ($k in $esperado.Keys) { AfirmarIgual $esperado[$k] $e.GetAttribute($k) ('atributo ' + $k) }
    $r = Set-ALAjustesServidorXml -Ruta $ruta -Forzados $v
    Afirmar (-not $r.Cambiado) 'repetirlo no cambia nada'
}
Prueba 'serversettings.xml: parte del tuyo, conserva tus ajustes de partida y corrige lo peligroso' {
    $juego = New-JuegoFalso (Join-Path $script:P_Tmp 'j-xml')
    $ruta = Join-Path $script:P_Tmp 'xml2\serversettings.xml'
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $ruta) -Force)
    $semilla = Join-Path $juego 'serversettings.xml'
    $antes = [System.IO.File]::ReadAllText($semilla)
    AfirmarIgual 'SALA DEL DUENO' (Get-ALNombreServidorDeSemilla $semilla) 'nombre de la semilla'
    $v = Get-ALValoresServidor -Nombre 'SALA DEL DUENO' -Puerto 27015 -MaxJugadores 8 -Contrasena 'pez'
    $r = Set-ALAjustesServidorXml -Ruta $ruta -Forzados $v -Iniciales @{ BanAfterWrongPassword = 'True' } -Semilla $semilla
    Afirmar $r.Sembrado 'deberia partir de la semilla'
    AfirmarIgual $antes ([System.IO.File]::ReadAllText($semilla)) 'el fichero del juego NO se toca'
    $x = New-Object System.Xml.XmlDocument
    $x.Load($ruta)
    $e = $x.DocumentElement
    AfirmarIgual 'False' $e.GetAttribute('IsPublic') 'IsPublic corregido'
    AfirmarIgual 'False' $e.GetAttribute('RequireAuthentication') 'RequireAuthentication corregido'
    AfirmarIgual '20' $e.GetAttribute('RespawnInterval') 'ajuste de partida conservado'
    AfirmarIgual 'False' $e.GetAttribute('BanAfterWrongPassword') 'los iniciales no pisan los de la semilla'
    AfirmarIgual 'pez' $e.GetAttribute('password') 'contrasena'
    Afirmar ($null -ne $e.SelectSingleNode('campaignsettings')) 'el hijo campaignsettings se conserva'
}
Prueba 'serversettings.xml: no duplica atributos que solo difieren en mayusculas, y guarda copia al cambiar' {
    $carpeta = Join-Path $script:P_Tmp 'xml3'
    [void](New-Item -ItemType Directory -Path $carpeta -Force)
    $ruta = Join-Path $carpeta 'serversettings.xml'
    [System.IO.File]::WriteAllText($ruta, '<serversettings Port="27015" servername="Vieja" ISPUBLIC="True" Otro="se queda" />')
    $v = Get-ALValoresServidor -Nombre 'Nueva' -Puerto 29015 -MaxJugadores 8 -Contrasena ''
    $r = Set-ALAjustesServidorXml -Ruta $ruta -Forzados $v -CarpetaRespaldo (Join-Path $carpeta 'respaldos')
    Afirmar ($r.Cambiado -and -not $r.Creado) 'cambiado, no creado'
    Afirmar ($r.Respaldo -and (Test-Path -LiteralPath $r.Respaldo)) 'falta la copia del anterior'
    Afirmar ([System.IO.File]::ReadAllText($r.Respaldo) -match 'Vieja') 'la copia es la del anterior'
    $x = New-Object System.Xml.XmlDocument
    $x.Load($ruta)
    $nombres = @($x.DocumentElement.Attributes | ForEach-Object { $_.Name.ToLowerInvariant() })
    AfirmarIgual $nombres.Count @($nombres | Select-Object -Unique).Count 'atributos duplicados'
    AfirmarIgual '29015' (Get-ALAtributoXml $x.DocumentElement 'port') 'puerto'
    AfirmarIgual 'Nueva' (Get-ALAtributoXml $x.DocumentElement 'ServerName') 'nombre'
    AfirmarIgual 'False' (Get-ALAtributoXml $x.DocumentElement 'IsPublic') 'IsPublic'
    AfirmarIgual 'se queda' (Get-ALAtributoXml $x.DocumentElement 'Otro') 'atributo ajeno'
    [System.IO.File]::WriteAllText($ruta, '<otracosa />')
    $falla = $false
    try { [void](Set-ALAjustesServidorXml -Ruta $ruta -Forzados $v) } catch { $falla = $true }
    Afirmar $falla 'un XML que no es serversettings debe avisar'
}
Prueba 'config_player.xml y permisos del servidor: se crean una vez y no pisan lo que haya' {
    $carpeta = Join-Path $script:P_Tmp 'cfg1'
    [void](New-Item -ItemType Directory -Path $carpeta -Force)
    $cfg = Join-Path $carpeta 'config_player.xml'
    AfirmarIgual 'igual' (Set-ALConfigServidor -Ruta $cfg -CarpetaPartidas '') 'sin partidas propias no se crea'
    Afirmar (-not (Test-Path -LiteralPath $cfg)) 'no deberia existir'
    AfirmarIgual 'creado' (Set-ALConfigServidor -Ruta $cfg -CarpetaPartidas 'D:\BarotraumaLAN\partidas') 'creado'
    $x = New-Object System.Xml.XmlDocument
    $x.Load($cfg)
    AfirmarIgual 'D:\BarotraumaLAN\partidas' $x.DocumentElement.GetAttribute('savepath') 'savepath'
    AfirmarIgual 'Content/ContentPackages/Vanilla.xml' $x.SelectSingleNode('/config/contentpackages/corepackage').GetAttribute('path') 'paquete base'
    AfirmarIgual 'igual' (Set-ALConfigServidor -Ruta $cfg -CarpetaPartidas 'D:\BarotraumaLAN\partidas') 'repetir no cambia'
    [System.IO.File]::WriteAllText($cfg, '<config language="Spanish" SavePath="C:\otra"><contentpackages><corepackage path="x" /><regularpackages><package path="mod" /></regularpackages></contentpackages></config>')
    AfirmarIgual 'cambiado' (Set-ALConfigServidor -Ruta $cfg -CarpetaPartidas '') 'vuelve a las del juego'
    $x.Load($cfg)
    AfirmarIgual '' (Get-ALAtributoXml $x.DocumentElement 'savepath') 'savepath vaciado sin duplicar'
    AfirmarIgual 'Spanish' $x.DocumentElement.GetAttribute('language') 'el resto se conserva'
    Afirmar ($null -ne $x.SelectSingleNode('/config/contentpackages/regularpackages/package')) 'los mods activados se conservan'
    $perm = Join-Path $carpeta 'Data\clientpermissions.xml'
    Afirmar (Set-ALPermisosAnfitrion $perm) 'deberia crearlo'
    $x.Load($perm)
    $c = $x.SelectSingleNode('/ClientPermissions/Client')
    AfirmarIgual '127.0.0.1' $c.GetAttribute('address') 'direccion'
    AfirmarIgual 'All' $c.GetAttribute('permissions') 'permisos'
    Afirmar ($c.GetAttribute('name').Length -gt 0) 'el juego exige un nombre'
    [System.IO.File]::WriteAllText($perm, '<ClientPermissions><Client name="x" accountid="y" permissions="None" /></ClientPermissions>')
    Afirmar (-not (Set-ALPermisosAnfitrion $perm)) 'si ya existe no se toca'
    Afirmar ([System.IO.File]::ReadAllText($perm) -match 'accountid') 'sigue siendo el del servidor'
}
Prueba 'datos propios: el servidor se lanzaria con SU perfil, y el entorno de este proceso queda como estaba' {
    $perfil = Join-Path $script:P_Tmp 'perfil-1'
    $e = Get-ALEntornoServidor $perfil
    AfirmarIgual 'USERPROFILE,LOCALAPPDATA,APPDATA,TEMP,TMP' (@($e.Keys) -join ',') 'variables que se cambian'
    AfirmarIgual $perfil $e.USERPROFILE 'USERPROFILE'
    AfirmarIgual (Join-Path $perfil 'AppData\Local') $e.LOCALAPPDATA 'LOCALAPPDATA'
    Initialize-ALPerfil $perfil
    Afirmar (Test-Path -LiteralPath (Join-Path $perfil 'AppData\Local') -PathType Container) 'AppData\Local creada'
    Afirmar (Test-Path -LiteralPath (Join-Path $perfil 'Temp') -PathType Container) 'Temp creada'
    # Se lanza cmd.exe (NO el juego) con ese entorno y se mira lo que ve el proceso hijo.
    $antes = @{ U = $env:USERPROFILE; L = $env:LOCALAPPDATA; A = $env:APPDATA; T = $env:TEMP }
    $salida = Join-Path $script:P_Tmp 'entorno hijo.txt'
    $p = Start-ALProceso -Exe (Join-Path $env:SystemRoot 'System32\cmd.exe') -Argumentos ('/c "(echo U=%USERPROFILE%& echo L=%LOCALAPPDATA%& echo T=%TEMP%& cd) > "' + $salida + '""') -Carpeta $perfil -Entorno $e -Oculto
    Afirmar ($p.WaitForExit(15000)) 'cmd.exe no termino'
    AfirmarIgual 0 $p.ExitCode 'codigo de salida del hijo'
    $visto = [System.IO.File]::ReadAllText($salida)
    Afirmar ($visto.Contains('U=' + $perfil)) ('el hijo no vio el USERPROFILE cambiado: ' + $visto)
    Afirmar ($visto.Contains('L=' + (Join-Path $perfil 'AppData\Local'))) ('el hijo no vio el LOCALAPPDATA cambiado: ' + $visto)
    Afirmar ($visto.Contains('T=' + (Join-Path $perfil 'Temp'))) ('el hijo no vio el TEMP cambiado: ' + $visto)
    Afirmar ($visto.TrimEnd().EndsWith($perfil)) ('el hijo no arranco en su carpeta: ' + $visto)
    AfirmarIgual $antes.U $env:USERPROFILE 'USERPROFILE de este proceso, restaurado'
    AfirmarIgual $antes.L $env:LOCALAPPDATA 'LOCALAPPDATA de este proceso, restaurado'
    AfirmarIgual $antes.A $env:APPDATA 'APPDATA de este proceso, restaurado'
    AfirmarIgual $antes.T $env:TEMP 'TEMP de este proceso, restaurado'
}
Prueba 'cortafuegos: la regla que se propone (solo se construye el texto; aqui no se toca nada)' {
    $exe = 'D:\BarotraumaLAN\servidor\DedicatedServer.exe'
    $p = Get-ALParametrosRegla -Puerto 27015 -Exe $exe
    AfirmarIgual 'Inbound' $p.Direction 'direccion'
    AfirmarIgual 'Allow' $p.Action 'accion'
    AfirmarIgual 'UDP' $p.Protocol 'protocolo'
    AfirmarIgual '27015' $p.LocalPort 'puerto'
    AfirmarIgual $exe $p.Program 'programa'
    AfirmarIgual 'Any' (@($p.RemoteAddress) -join ',') 'alcance por defecto'
    AfirmarIgual 'Barotrauma LAN' $p.Group 'grupo (por el se quita)'
    $t = Get-ALTextoRegla $p
    Afirmar ($t -like "New-NetFirewallRule *-Direction 'Inbound'*-Action 'Allow'*-Protocol 'UDP'*-LocalPort '27015'*-Program '$exe'*") ('texto de la orden: ' + $t)
    $p = Get-ALParametrosRegla -Puerto 27015 -Exe $exe -Alcance 'subred' -Interfaces $P_InterfacesDelDueno
    AfirmarIgual ('LocalSubnet,' + $script:BL_RangoTailscale + '/10') (@($p.RemoteAddress) -join ',') 'alcance "subred" con Tailscale'
}
Prueba 'cortafuegos y puertos: LEER el estado real no cambia nada' {
    $antes = @(Get-NetFirewallRule -Group $script:AL_GrupoCortafuegos -ErrorAction SilentlyContinue).Count
    $e = Get-ALEstadoCortafuegos -Puerto 27715 -Exe 'Z:\no-existe\DedicatedServer.exe'
    if (-not $e.Comprobado) { Omitir ('no se puede leer el cortafuegos en este PC: ' + $e.Detalle) }
    if ($antes -eq 0) { AfirmarIgual 0 @($e.Permiten).Count 'para un programa que no existe no puede haber regla que permita' }
    AfirmarIgual 0 @($e.Bloquean).Count 'ni que bloquee'
    AfirmarIgual $antes @(Get-NetFirewallRule -Group $script:AL_GrupoCortafuegos -ErrorAction SilentlyContinue).Count 'las reglas siguen igual'
    $cerrado = Get-BLPuertoCerrado
    AfirmarIgual $true (Test-ALPuertoUdpLibre $cerrado) 'un puerto que no escucha nadie esta libre'
    $s = Start-BLServidorFalso -Modo mudo
    AfirmarIgual $false (Test-ALPuertoUdpLibre $s.Puerto) 'un puerto en uso esta ocupado'
    [void](Stop-BLServidorFalso $s)
}
Prueba 'paquete del amigo: lleva SOLO los guiones y servidor.json; nada del juego' {
    $salida = Join-Path $script:P_Tmp 'salida1'
    [void](New-Item -ItemType Directory -Path $salida -Force)
    $dir = @(Get-BLDireccionesServidor -Interfaces $P_InterfacesDelDueno)
    AfirmarIgual 'Sala_ de_Steven_' (ConvertTo-ALNombreFichero 'Sala: de/Steven?') 'caracteres que no valen en un nombre de fichero'
    $datos = New-ALDatosServidor -Nombre 'Sala de Steven.' -Puerto 27015 -Version '1.13.4.0' -Anfitrion 'Steven' -Direcciones $dir
    $p = New-ALPaqueteAmigo -CarpetaAmigo $P_Amigo -Salida $salida -Datos $datos
    Afirmar (Test-Path -LiteralPath $p.Zip -PathType Leaf) 'falta el zip'
    AfirmarIgual 'Barotrauma LAN - Sala de Steven.zip' (Split-Path -Leaf $p.Zip) 'nombre del zip'
    $esperados = @(@('COMPROBAR-SIN-ABRIR-EL-JUEGO.bat', 'JUGAR-BAROTRAUMA-LAN.bat', 'LEEME.txt', 'barolan-comun.ps1', 'jugar.ps1', 'servidor.json') | Sort-Object)
    $enCarpeta = @(Get-ChildItem -LiteralPath $p.Carpeta -Recurse -File | ForEach-Object { $_.Name } | Sort-Object)
    AfirmarIgual ($esperados -join ',') ($enCarpeta -join ',') 'ficheros de la carpeta'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z = [System.IO.Compression.ZipFile]::OpenRead($p.Zip)
    try { $enZip = @($z.Entries | ForEach-Object { $_.FullName } | Sort-Object) } finally { $z.Dispose() }
    AfirmarIgual 6 $enZip.Count 'entradas del zip'
    foreach ($x in $enZip) {
        Afirmar ($x -like 'Barotrauma LAN - Sala de Steven/*') ('entrada fuera de su carpeta: ' + $x)
        Afirmar ($x -notmatch '(?i)\.(exe|dll|pdb|xml)$') ('el paquete no puede llevar ficheros del juego: ' + $x)
    }
    $s = Read-BLDatosServidor (Join-Path $p.Carpeta 'servidor.json')
    Afirmar $s.Ok ('el servidor.json generado no se lee: ' + $s.Error)
    AfirmarIgual 5 @($s.Direcciones).Count 'direcciones dentro del paquete'
    AfirmarIgual '10.10.10.103' $s.Direcciones[0].direccion 'primera direccion'
    foreach ($n in @('jugar.ps1', 'barolan-comun.ps1')) {
        AfirmarIgual ([System.IO.File]::ReadAllText((Join-Path $P_Amigo $n))) ([System.IO.File]::ReadAllText((Join-Path $p.Carpeta $n))) ('copia identica de ' + $n)
    }
}

# =================================================================================================== de punta a punta, en seco
Prueba 'EN SECO amigo: encuentra el juego, elige la direccion que contesta y ensena la orden (no lanza nada)' {
    $juego = New-JuegoFalso (Join-Path $script:P_Tmp 'e2e juego 1')
    $mudo = Start-BLServidorFalso -Modo mudo
    $vivo = Start-BLServidorFalso -Modo lidgren
    $datos = New-DatosServidorDePrueba -Nombre 'e2e1' -Puerto 27015 -Direcciones @(
        [ordered]@{ red = 'lan'; tipo = 'lan'; direccion = '127.0.0.1'; puerto = $mudo.Puerto; prefijo = 24; etiqueta = 'Red local' },
        [ordered]@{ red = 'zerotier'; tipo = 'vpn'; direccion = '127.0.0.1'; puerto = $vivo.Puerto; prefijo = 16; etiqueta = 'ZeroTier' },
        [ordered]@{ red = 'tailscale'; tipo = 'vpn'; direccion = '127.0.0.1'; puerto = (Get-BLPuertoCerrado); prefijo = 32; etiqueta = 'Tailscale' })
    $r = Invoke-Guion (Join-Path $P_Amigo 'jugar.ps1') @('-EnSeco', '-NoPreguntar', '-PermitirBucle', '-CarpetaJuego', $juego, '-Jugador', 'Pepe Luis', '-DatosServidor', $datos, '-CarpetaDatos', (Join-Path $script:P_Tmp 'e2e-datos-1'), '-EsperaMs', '250')
    $recMudo = Stop-BLServidorFalso $mudo
    $recVivo = Stop-BLServidorFalso $vivo
    AfirmarIgual 0 $r.Codigo ('codigo de salida. Salida: ' + $r.Salida)
    Afirmar ($r.Salida -match ('ELEGIDA: zerotier 127\.0\.0\.1:' + $vivo.Puerto)) ('no eligio la que contesta: ' + $r.Salida)
    $orden = 'ORDEN: "' + (Join-Path $juego 'Barotrauma.exe') + '" -connect "Sala de prueba" 127.0.0.1:' + $vivo.Puerto + ' -username "Pepe Luis" -skipintro -lenienthandshake'
    Afirmar ($r.Salida.Contains($orden)) ("la orden no es la esperada.`nEsperada: " + $orden + "`nSalida: " + $r.Salida)
    AfirmarIgual 2 $recMudo.Count 'saludos a la direccion muda'
    AfirmarIgual 1 $recVivo.Count 'saludos a la que contesta'
    Afirmar (-not (Test-Path -LiteralPath (Join-Path $script:P_Tmp 'e2e-datos-1'))) 'con -Jugador y -CarpetaJuego no se guarda nada'
    Afirmar ($r.Salida -notmatch 'Abriendo Barotrauma') 'en seco no debe decir que abre el juego'
}
Prueba 'EN SECO amigo: por red local no lleva -lenienthandshake; recuerda nombre y carpeta; sonda apagada' {
    $juego = New-JuegoFalso (Join-Path $script:P_Tmp 'e2e-juego-2')
    $datosJugador = Join-Path $script:P_Tmp 'e2e-datos-2'
    Afirmar (Save-BLDatosJugador -Carpeta $datosJugador -Jugador 'Recordado' -CarpetaJuego $juego) 'no pude preparar los datos del jugador'
    $vivo = Start-BLServidorFalso -Modo lidgren
    $datos = New-DatosServidorDePrueba -Nombre 'e2e2' -Puerto $vivo.Puerto -Direcciones @([ordered]@{ red = 'lan'; tipo = 'lan'; direccion = '127.0.0.1'; prefijo = 24; etiqueta = 'Red local' })
    $r = Invoke-Guion (Join-Path $P_Amigo 'jugar.ps1') @('-EnSeco', '-NoPreguntar', '-PermitirBucle', '-DatosServidor', $datos, '-CarpetaDatos', $datosJugador)
    $rec = Stop-BLServidorFalso $vivo
    AfirmarIgual 0 $r.Codigo ('codigo de salida. Salida: ' + $r.Salida)
    $orden = 'ORDEN: "' + (Join-Path $juego 'Barotrauma.exe') + '" -connect "Sala de prueba" 127.0.0.1:' + $vivo.Puerto + ' -username "Recordado" -skipintro'
    Afirmar ($r.Salida.TrimEnd().EndsWith($orden)) ("orden inesperada.`nEsperada: " + $orden + "`nSalida: " + $r.Salida)
    AfirmarIgual 1 $rec.Count 'saludos'
    $r = Invoke-Guion (Join-Path $P_Amigo 'jugar.ps1') @('-EnSeco', '-NoPreguntar', '-PermitirBucle', '-DatosServidor', $datos, '-CarpetaDatos', $datosJugador, '-Sonda', 'ninguna')
    AfirmarIgual 0 $r.Codigo ('sonda apagada: codigo. Salida: ' + $r.Salida)
    Afirmar ($r.Salida -match 'sonda apagada') 'deberia decir que la sonda esta apagada'
    Afirmar ($r.Salida -match 'ELEGIDA: lan 127\.0\.0\.1') 'sin sonda elige la primera red que este PC tiene'
    $r = Invoke-Guion (Join-Path $P_Amigo 'jugar.ps1') @('-EnSeco', '-NoPreguntar', '-DatosServidor', $datos, '-CarpetaDatos', $datosJugador)
    AfirmarIgual 5 $r.Codigo 'sin -PermitirBucle, un servidor.json con solo 127.x no trae direcciones'
}
Prueba 'EN SECO amigo: version distinta = no se abre el juego y se dice quien tiene que actualizar' {
    $viejo = New-JuegoFalso (Join-Path $script:P_Tmp 'e2e-juego-viejo') -Version '1.13.3.0'
    $nuevo = New-JuegoFalso (Join-Path $script:P_Tmp 'e2e-juego-nuevo') -Version '1.14.0.0'
    $datos = New-DatosServidorDePrueba -Nombre 'e2e3' -Puerto 27015 -Version '1.13.4.0' -Direcciones @([ordered]@{ red = 'lan'; tipo = 'lan'; direccion = '127.0.0.1'; prefijo = 24; etiqueta = 'Red local' })
    $r = Invoke-Guion (Join-Path $P_Amigo 'jugar.ps1') @('-EnSeco', '-NoPreguntar', '-PermitirBucle', '-CarpetaJuego', $viejo, '-Jugador', 'A', '-DatosServidor', $datos)
    AfirmarIgual 3 $r.Codigo ('codigo con juego viejo. Salida: ' + $r.Salida)
    Afirmar ($r.Salida -match 'mas VIEJO' -and $r.Salida -match '1\.13\.3\.0' -and $r.Salida -match '1\.13\.4\.0') 'mensaje de juego viejo con las dos versiones'
    Afirmar ($r.Salida -notmatch 'ORDEN:') 'con version distinta no hay orden'
    $r = Invoke-Guion (Join-Path $P_Amigo 'jugar.ps1') @('-EnSeco', '-NoPreguntar', '-PermitirBucle', '-CarpetaJuego', $nuevo, '-Jugador', 'A', '-DatosServidor', $datos)
    AfirmarIgual 3 $r.Codigo 'codigo con juego nuevo'
    Afirmar ($r.Salida -match 'mas NUEVO' -and $r.Salida -match 'Anfi') 'mensaje de juego nuevo nombrando al anfitrion'
}
Prueba 'EN SECO amigo: si no contesta ninguna, diagnostico y codigo 4; datos malos, 5; sin juego, 2; sin nombre, 6' {
    $juego = New-JuegoFalso (Join-Path $script:P_Tmp 'e2e-juego-4')
    $mudo = Start-BLServidorFalso -Modo mudo
    $datos = New-DatosServidorDePrueba -Nombre 'e2e4' -Puerto 27015 -Direcciones @(
        [ordered]@{ red = 'lan'; tipo = 'lan'; direccion = '127.0.0.1'; puerto = $mudo.Puerto; prefijo = 24; etiqueta = 'Red local' },
        [ordered]@{ red = 'hamachi'; tipo = 'vpn'; direccion = '127.0.0.1'; puerto = (Get-BLPuertoCerrado); prefijo = 8; etiqueta = 'Hamachi' })
    $r = Invoke-Guion (Join-Path $P_Amigo 'jugar.ps1') @('-EnSeco', '-NoPreguntar', '-PermitirBucle', '-CarpetaJuego', $juego, '-Jugador', 'A', '-DatosServidor', $datos, '-EsperaMs', '150')
    [void](Stop-BLServidorFalso $mudo)
    AfirmarIgual 4 $r.Codigo ('codigo. Salida: ' + $r.Salida)
    Afirmar ($r.Salida -match 'NO CONTESTA NINGUNA DIRECCION') 'titulo del diagnostico'
    Afirmar ($r.Salida -match 'Preguntale a Anfi') 'pregunta final del diagnostico'
    Afirmar ($r.Salida -notmatch 'ORDEN:') 'sin direccion no hay orden'
    $r = Invoke-Guion (Join-Path $P_Amigo 'jugar.ps1') @('-EnSeco', '-NoPreguntar', '-DatosServidor', (Join-Path $script:P_Tmp 'no-hay.json'))
    AfirmarIgual 5 $r.Codigo 'sin servidor.json'
    $r = Invoke-Guion (Join-Path $P_Amigo 'jugar.ps1') @('-EnSeco', '-NoPreguntar', '-PermitirBucle', '-CarpetaJuego', (Join-Path $script:P_Tmp 'aqui-no-hay-juego'), '-Jugador', 'A', '-DatosServidor', $datos)
    AfirmarIgual 2 $r.Codigo 'carpeta sin juego'
    $r = Invoke-Guion (Join-Path $P_Amigo 'jugar.ps1') @('-EnSeco', '-NoPreguntar', '-PermitirBucle', '-CarpetaJuego', $juego, '-Jugador', 'a/b', '-DatosServidor', $datos)
    AfirmarIgual 6 $r.Codigo 'nombre que el servidor rechazaria'
    $r = Invoke-Guion (Join-Path $P_Amigo 'jugar.ps1') @('-EnSeco', '-NoPreguntar', '-PermitirBucle', '-CarpetaJuego', $juego, '-Jugador', 'A', '-DatosServidor', $datos, '-Forzar', '10.9.8.7')
    AfirmarIgual 0 $r.Codigo 'forzar una direccion'
    Afirmar ($r.Salida -match '-connect "Sala de prueba" 10\.9\.8\.7:27015 ') 'orden con la direccion forzada'
}
Prueba 'EN SECO anfitrion: "estado" no escribe NADA' {
    $juego = New-JuegoFalso (Join-Path $script:P_Tmp 'h-estado\steamapps\common\Barotrauma')
    $carpeta = Join-Path $script:P_Tmp 'h-estado-aj'
    [void](New-Item -ItemType Directory -Path $carpeta -Force)
    $aj = Join-Path $carpeta 'ajustes-anfitrion.json'
    $raiz = Join-Path $script:P_Tmp 'h-estado-srv'
    Write-BLJson $aj ([ordered]@{ carpetaJuego = $juego; carpetaServidor = $raiz; puerto = (Get-BLPuertoCerrado); nombreServidor = 'Sala de prueba' })
    $antesJuego = Get-HuellaCarpeta $juego
    $antesAj = Get-HuellaCarpeta $carpeta
    $salida = Join-Path $script:P_Tmp 'h-estado-salida'
    $r = Invoke-Guion (Join-Path $P_Anfitrion 'servidor.ps1') @('-Accion', 'estado', '-NoPreguntar', '-Ajustes', $aj, '-CarpetaSalida', $salida)
    AfirmarIgual 0 $r.Codigo ('codigo. Salida: ' + $r.Salida)
    Afirmar (-not (Test-Path -LiteralPath $raiz)) 'no debe crear la carpeta del servidor'
    Afirmar (-not (Test-Path -LiteralPath $salida)) 'no debe crear el paquete'
    AfirmarIgual $antesJuego (Get-HuellaCarpeta $juego) 'el juego intacto'
    AfirmarIgual $antesAj (Get-HuellaCarpeta $carpeta) 'la carpeta de ajustes intacta'
    Afirmar ($r.Salida -match 'todavia no existe') 'deberia decir que la carpeta del servidor no existe aun'
    Afirmar ($r.Salida -match 'ORDEN: ') 'ensena la orden que se usaria'
}
Prueba 'EN SECO anfitrion: "abrir -EnSeco" lo prepara todo, genera el paquete y ensena la orden sin arrancar nada' {
    $juego = New-JuegoFalso (Join-Path $script:P_Tmp 'h abrir\steamapps\common\Barotrauma')
    $carpeta = Join-Path $script:P_Tmp 'h-abrir-aj'
    [void](New-Item -ItemType Directory -Path $carpeta -Force)
    $aj = Join-Path $carpeta 'ajustes-anfitrion.json'
    $raiz = Join-Path $script:P_Tmp 'h abrir srv'
    $puerto = Get-BLPuertoCerrado
    Write-BLJson $aj ([ordered]@{ carpetaJuego = $juego; carpetaServidor = $raiz; puerto = $puerto; nombreServidor = ''; nombreAnfitrion = 'Anfi'; maxJugadores = 5; contrasena = 'pez' })
    [void]$script:P_Uniones.Add((Join-Path $raiz 'servidor\Content'))
    $antesJuego = Get-HuellaCarpeta $juego
    $salida = Join-Path $script:P_Tmp 'h-abrir-salida'
    $r = Invoke-Guion (Join-Path $P_Anfitrion 'servidor.ps1') @('-Accion', 'abrir', '-EnSeco', '-NoPreguntar', '-Ajustes', $aj, '-CarpetaSalida', $salida)
    AfirmarIgual 0 $r.Codigo ('codigo. Salida: ' + $r.Salida)
    # (No se cuentan procesos en total: el laboratorio puede tener los suyos abiertos. Se mira que no haya ninguno NUESTRO.)
    $nuestros = @(Get-Process -Name 'DedicatedServer', 'Barotrauma' -ErrorAction SilentlyContinue | Where-Object { $ruta = ''; try { $ruta = [string]$_.Path } catch { }; $ruta -like ($script:P_Tmp + '*') })
    AfirmarIgual 0 $nuestros.Count 'no debe haber arrancado ningun proceso desde las carpetas de la prueba'
    AfirmarIgual $antesJuego (Get-HuellaCarpeta $juego) 'el juego intacto'
    $orden = 'ORDEN: "' + (Join-Path $raiz 'servidor\DedicatedServer.exe') + '" -name "SALA DEL DUENO" -port ' + $puerto + ' -queryport ' + ($puerto + 1) + ' -public false -maxplayers 5 -password "pez" -lenienthandshake'
    Afirmar ($r.Salida.Contains($orden)) ("orden inesperada.`nEsperada: " + $orden + "`nSalida: " + $r.Salida)
    $x = New-Object System.Xml.XmlDocument
    $x.Load((Join-Path $raiz 'servidor\serversettings.xml'))
    AfirmarIgual 'False' $x.DocumentElement.GetAttribute('IsPublic') 'IsPublic'
    AfirmarIgual 'False' $x.DocumentElement.GetAttribute('RequireAuthentication') 'RequireAuthentication'
    AfirmarIgual ([string]$puerto) $x.DocumentElement.GetAttribute('port') 'puerto'
    AfirmarIgual 'SALA DEL DUENO' $x.DocumentElement.GetAttribute('ServerName') 'nombre heredado del juego'
    AfirmarIgual '20' $x.DocumentElement.GetAttribute('RespawnInterval') 'ajuste de partida heredado'
    $x.Load((Join-Path $raiz 'servidor\config_player.xml'))
    AfirmarIgual (Join-Path $raiz 'partidas') $x.DocumentElement.GetAttribute('savepath') 'partidas propias'
    Afirmar ($r.Salida.Contains('ENTORNO: USERPROFILE=' + (Join-Path $raiz 'perfil'))) 'el servidor debe lanzarse con su propio perfil'
    Afirmar ($r.Salida.Contains('ENTORNO: LOCALAPPDATA=' + (Join-Path $raiz 'perfil\AppData\Local'))) 'y con su LOCALAPPDATA'
    Afirmar ($r.Salida.IndexOf('ENTORNO: USERPROFILE=') -lt $r.Salida.IndexOf('ORDEN: ')) 'el entorno se ensena antes que la orden'
    Afirmar (Test-Path -LiteralPath (Join-Path $raiz 'perfil\AppData\Local') -PathType Container) 'la carpeta AppData\Local del perfil debe existir ANTES de arrancar'
    $datosReales = Join-Path $env:LOCALAPPDATA 'Daedalic Entertainment GmbH'
    Afirmar ($r.Salida -notmatch [regex]::Escape($datosReales)) 'la carpeta de datos real del dueno no debe aparecer en ningun sitio'
    Afirmar ([System.IO.File]::ReadAllText((Join-Path $raiz 'servidor\config_player.xml')) -notmatch 'SECRETO') 'el config_player.xml del dueno no se copia'
    Afirmar ([System.IO.File]::ReadAllText((Join-Path $raiz 'servidor\Data\clientpermissions.xml')) -match '127\.0\.0\.1') 'permisos del anfitrion por 127.0.0.1'
    Afirmar ([System.IO.File]::ReadAllText((Join-Path $raiz 'servidor\Data\clientpermissions.xml')) -notmatch 'STEAM64_1') 'los permisos del dueno no se copian'
    Afirmar (Test-Path -LiteralPath (Join-Path $carpeta 'servidor-actual.json')) 'falta servidor-actual.json (para 2-JUGAR-YO.bat)'
    $interfaces = @(Get-BLDireccionesServidor -Interfaces @(Get-BLInterfaces))
    if ($interfaces.Count -eq 0) {
        Afirmar ($r.Salida -match 'No genero el paquete') 'sin red, deberia decir que no genera el paquete'
    } else {
        Afirmar ($r.Salida -match 'PAQUETE: (.+\.zip)') 'no dice donde dejo el paquete'
        $zip = Join-Path $salida 'Barotrauma LAN - SALA DEL DUENO.zip'
        Afirmar (Test-Path -LiteralPath $zip) ('falta ' + $zip)
        $s = Read-BLDatosServidor (Join-Path $salida 'Barotrauma LAN - SALA DEL DUENO\servidor.json')
        Afirmar $s.Ok $s.Error
        AfirmarIgual '1.13.4.0' $s.Version 'version dentro del paquete'
        AfirmarIgual $puerto $s.Puerto 'puerto dentro del paquete'
        AfirmarIgual 'pez' $s.Contrasena 'contrasena dentro del paquete'
        AfirmarIgual $interfaces.Count @($s.Direcciones).Count 'direcciones dentro del paquete'
    }
    # el lanzador del anfitrion (2-JUGAR-YO) con esos datos: 127.0.0.1 primero
    $vivo = Start-BLServidorFalso -Modo lidgren
    $d2 = Read-BLJson (Join-Path $carpeta 'servidor-actual.json')
    $d2.servidor.puerto = $vivo.Puerto
    Write-BLJson (Join-Path $carpeta 'servidor-actual.json') $d2
    $r = Invoke-Guion (Join-Path $P_Amigo 'jugar.ps1') @('-EnSeco', '-NoPreguntar', '-Local', '-CarpetaJuego', $juego, '-Jugador', 'Anfi', '-DatosServidor', (Join-Path $carpeta 'servidor-actual.json'), '-EsperaMs', '200')
    [void](Stop-BLServidorFalso $vivo)
    if ($interfaces.Count -gt 0) {
        AfirmarIgual 0 $r.Codigo ('2-JUGAR-YO en seco. Salida: ' + $r.Salida)
        Afirmar ($r.Salida -match ('ELEGIDA: local 127\.0\.0\.1:' + $vivo.Puerto)) 'el anfitrion entra por 127.0.0.1'
        Afirmar ($r.Salida -match ('-connect "SALA DEL DUENO" 127\.0\.0\.1:' + $vivo.Puerto + ' -username "Anfi" -skipintro\s*$')) 'por 127.0.0.1 no lleva -lenienthandshake'
    }
}
Prueba 'EN SECO anfitrion: con datos "los-de-mi-juego" no hay perfil propio ni savepath, y se avisa del riesgo' {
    $juego = New-JuegoFalso (Join-Path $script:P_Tmp 'h-mios\steamapps\common\Barotrauma')
    $carpeta = Join-Path $script:P_Tmp 'h-mios-aj'
    [void](New-Item -ItemType Directory -Path $carpeta -Force)
    $aj = Join-Path $carpeta 'ajustes-anfitrion.json'
    $raiz = Join-Path $script:P_Tmp 'h-mios-srv'
    Write-BLJson $aj ([ordered]@{ carpetaJuego = $juego; carpetaServidor = $raiz; puerto = (Get-BLPuertoCerrado); nombreServidor = 'Sala'; datos = 'los-de-mi-juego' })
    [void]$script:P_Uniones.Add((Join-Path $raiz 'servidor\Content'))
    $r = Invoke-Guion (Join-Path $P_Anfitrion 'servidor.ps1') @('-Accion', 'preparar', '-NoPreguntar', '-Ajustes', $aj, '-CarpetaSalida', (Join-Path $script:P_Tmp 'h-mios-salida'))
    AfirmarIgual 0 $r.Codigo ('codigo. Salida: ' + $r.Salida)
    Afirmar ($r.Salida -notmatch 'ENTORNO:') 'sin datos propios no se cambia el entorno'
    Afirmar ($r.Salida -match 'BORRA') 'debe avisar de que el juego puede borrar mods del Workshop'
    Afirmar (-not (Test-Path -LiteralPath (Join-Path $raiz 'perfil'))) 'no se crea perfil'
    Afirmar (-not (Test-Path -LiteralPath (Join-Path $raiz 'servidor\config_player.xml'))) 'no se crea config_player.xml (lo hara el servidor con sus valores)'
    Afirmar ($r.Salida -match 'ORDEN: ') 'con "preparar" se ensena la orden y no se arranca'
}
Prueba 'EN SECO cortafuegos: ensena la regla y no cambia nada' {
    $carpeta = Join-Path $script:P_Tmp 'cf-aj'
    [void](New-Item -ItemType Directory -Path $carpeta -Force)
    $aj = Join-Path $carpeta 'ajustes-anfitrion.json'
    Write-BLJson $aj ([ordered]@{ carpetaServidor = 'D:\BarotraumaLAN'; puerto = 27015 })
    $antes = @(Get-NetFirewallRule -Group $script:AL_GrupoCortafuegos -ErrorAction SilentlyContinue).Count
    $r = Invoke-Guion (Join-Path $P_Anfitrion 'cortafuegos.ps1') @('-Accion', 'abrir', '-EnSeco', '-NoPreguntar', '-Ajustes', $aj)
    AfirmarIgual 0 $r.Codigo ('codigo. Salida: ' + $r.Salida)
    Afirmar ($r.Salida -match "ORDEN: New-NetFirewallRule .*-Direction 'Inbound' -Action 'Allow' -Protocol 'UDP' -LocalPort '27015' -Program 'D:\\BarotraumaLAN\\servidor\\DedicatedServer\.exe' -RemoteAddress 'Any' -Profile 'Any'") ('regla inesperada: ' + $r.Salida)
    $r = Invoke-Guion (Join-Path $P_Anfitrion 'cortafuegos.ps1') @('-Accion', 'quitar', '-EnSeco', '-NoPreguntar', '-Ajustes', $aj)
    AfirmarIgual 0 $r.Codigo 'quitar en seco'
    $r = Invoke-Guion (Join-Path $P_Anfitrion 'cortafuegos.ps1') @('-Accion', 'ver', '-Ajustes', $aj)
    AfirmarIgual 0 $r.Codigo 'ver'
    AfirmarIgual $antes @(Get-NetFirewallRule -Group $script:AL_GrupoCortafuegos -ErrorAction SilentlyContinue).Count 'las reglas del cortafuegos siguen igual'
}

# =================================================================================================== ficheros de la entrega
Prueba 'entrega: todos los .ps1 se entienden (sin errores de sintaxis)' {
    foreach ($f in @(Get-ChildItem -LiteralPath $P_Amigo, $P_Anfitrion, $P_Aqui -Filter '*.ps1' -File)) {
        $errores = $null; $fichas = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$fichas, [ref]$errores)
        Afirmar (@($errores).Count -eq 0) ($f.Name + ': ' + (@($errores | ForEach-Object { 'linea ' + $_.Extent.StartLineNumber + ' ' + $_.Message }) -join '; '))
    }
}
Prueba 'entrega: ASCII puro y finales de linea de Windows (si falla: pruebas\normalizar-ficheros.ps1)' {
    $r = Invoke-Guion (Join-Path $P_Aqui 'normalizar-ficheros.ps1') @('-SoloMirar')
    AfirmarIgual 0 $r.Codigo $r.Salida
}
Prueba 'entrega: cada .bat llama a un guion que existe, sin perfil y por la ruta completa de PowerShell' {
    foreach ($f in @(Get-ChildItem -LiteralPath $P_Amigo, $P_Anfitrion, $P_Aqui -Filter '*.bat' -File)) {
        $t = [System.IO.File]::ReadAllText($f.FullName)
        $llamadas = [regex]::Matches($t, '-File "%~dp0([^"]+)"')
        Afirmar ($llamadas.Count -ge 1) ($f.Name + ' no llama a ningun guion')
        foreach ($m in $llamadas) {
            $destino = Join-Path $f.DirectoryName $m.Groups[1].Value
            Afirmar (Test-Path -LiteralPath $destino -PathType Leaf) ($f.Name + ' llama a un fichero que no existe: ' + $m.Groups[1].Value)
        }
        Afirmar ($t -match '%SystemRoot%\\System32\\WindowsPowerShell\\v1\.0\\powershell\.exe" -NoProfile -ExecutionPolicy Bypass -File') ($f.Name + ' no usa la llamada de siempre')
        Afirmar ($t -notmatch '(?i)runas|-Verb|-EncodedCommand|-WindowStyle\s+Hidden|Invoke-WebRequest|curl |bitsadmin') ($f.Name + ' lleva algo que no deberia')
    }
}
Prueba 'entrega: en lo que se entrega no hay borrados de carpetas, cierres a la fuerza ni salidas a internet' {
    foreach ($f in @(Get-ChildItem -LiteralPath $P_Amigo, $P_Anfitrion -Include '*.ps1', '*.bat' -File -Recurse)) {
        $n = 0
        foreach ($linea in [System.IO.File]::ReadAllLines($f.FullName)) {
            $n++
            if ($linea.TrimStart().StartsWith('#') -or $linea.TrimStart().StartsWith('echo')) { continue }
            Afirmar ($linea -notmatch '(?i)Remove-Item|rmdir|rd /s|del /|-Recurse|Directory\]::Delete\([^)]*\$true') ($f.Name + ' linea ' + $n + ': borrado que no deberia estar: ' + $linea.Trim())
            Afirmar ($linea -notmatch '(?i)Stop-Process|taskkill|\.Kill\(') ($f.Name + ' linea ' + $n + ': cierre a la fuerza: ' + $linea.Trim())
            Afirmar ($linea -notmatch '(?i)Invoke-WebRequest|Invoke-RestMethod|WebClient|HttpClient|Start-BitsTransfer|https?://') ($f.Name + ' linea ' + $n + ': salida a internet: ' + $linea.Trim())
        }
    }
    # Solo cortafuegos.ps1 puede cambiar el cortafuegos.
    foreach ($f in @(Get-ChildItem -LiteralPath $P_Amigo, $P_Anfitrion -Include '*.ps1', '*.bat' -File -Recurse | Where-Object { $_.Name -ne 'cortafuegos.ps1' })) {
        $t = [System.IO.File]::ReadAllText($f.FullName)
        Afirmar ($t -notmatch '(?i)New-NetFirewallRule @|Remove-NetFirewallRule\s*$|Set-NetFirewall|netsh\s+advfirewall') ($f.Name + ' no puede tocar el cortafuegos')
    }
}
Prueba 'entrega: la carpeta amigo\ es exactamente lo que viaja en el paquete' {
    $hay = @(Get-ChildItem -LiteralPath $P_Amigo -File | ForEach-Object { $_.Name } | Sort-Object)
    AfirmarIgual (@($script:AL_FicherosPaquete | Sort-Object) -join ',') ($hay -join ',') 'ficheros de amigo\ frente a la lista del paquete'
}

# =================================================================================================== limpieza y resumen
$limpiezaBien = $true
if (-not $Conservar) {
    try {
        # Primero las uniones, una a una y sin tocar lo que hay detras. Despues, y solo si no queda ninguna, el resto.
        foreach ($u in $script:P_Uniones) { if (Test-Path -LiteralPath $u) { [void](Remove-ALUnion $u) } }
        foreach ($u in $script:P_Uniones) { if (Test-Path -LiteralPath $u) { throw ('sigue existiendo la union ' + $u) } }
        $quedan = @(Get-ChildItem -LiteralPath $script:P_Tmp -Directory -Recurse -Force -Attributes ReparsePoint -ErrorAction SilentlyContinue)
        if ($quedan.Count -gt 0) { throw ('quedan uniones sin quitar: ' + (@($quedan | ForEach-Object { $_.FullName }) -join ', ')) }
        [System.IO.Directory]::Delete($script:P_Tmp, $true)
        $padre = Split-Path -Parent $script:P_Tmp
        if (@(Get-ChildItem -LiteralPath $padre -Force).Count -eq 0) { [System.IO.Directory]::Delete($padre, $false) }
    } catch {
        $limpiezaBien = $false
        Write-Host ('  No he podido limpiar ' + $script:P_Tmp + ': ' + $_.Exception.Message) -ForegroundColor Yellow
    }
}

$bien = @($script:P_Resultados | Where-Object { $_.Estado -eq 'OK' }).Count
$omitidas = @($script:P_Resultados | Where-Object { $_.Estado -eq 'OMITIDA' }).Count
$mal = @($script:P_Resultados | Where-Object { $_.Estado -eq 'FALLA' }).Count
Write-Host ''
$color = 'Green'
if ($mal -gt 0) { $color = 'Red' }
Write-Host ('  RESULTADO: {0} bien, {1} fallan, {2} omitidas  (de {3})' -f $bien, $mal, $omitidas, $script:P_Resultados.Count) -ForegroundColor $color
Write-Host '  Recuerda: la sonda se ha probado contra un servidor de mentira. Eso no acredita nada del juego real.' -ForegroundColor DarkGray
if ($Conservar) { Write-Host ('  Temporales conservados en ' + $script:P_Tmp) -ForegroundColor DarkGray }
if ($mal -gt 0) { exit 1 }
if (-not $limpiezaBien) { exit 2 }
exit 0
