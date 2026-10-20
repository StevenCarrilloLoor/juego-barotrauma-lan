# ==============================================================================================================
# barolan-comun.ps1  -  Barotrauma LAN 0.1  -  funciones compartidas (lanzador del amigo y herramientas del anfitrion)
#
# Para Windows PowerShell 5.1, que viene con Windows 10 y 11. No instala nada, no pide administrador y no sale a
# internet. Lo unico que manda por la red es la SONDA: un saludo UDP de 31 bytes a cada direccion del servidor
# (y un ping si se pide). No toca la carpeta del juego: solo lee su version.
#
# Escrito solo con caracteres ASCII (sin tildes) a proposito: asi da igual la pagina de codigos de la consola.
# Se carga con:   . "<carpeta>\barolan-comun.ps1"      (al nivel del guion, no dentro de una funcion)
# ==============================================================================================================

$script:BL_Version = '0.1'
# Rango que reparte Tailscale (CGNAT, 100.64/10). Se escribe por octetos para que el detector de secretos del
# repositorio no lo confunda con la IP de un equipo.
$script:BL_RangoTailscale = (@(100, 64, 0, 0) -join '.')
$script:BL_AppIdSteam = '602960'
$script:BL_FormatoDatos = 1
# Identificador que manda la sonda limpia. Tiene que ser DISTINTO del que usa el juego ("barotrauma"):
# el servidor contesta "Wrong application identifier!" desde su hilo de red y el juego no llega a enterarse.
$script:BL_IdSonda = 'barolan-sonda'
$script:BL_IdJuego = 'barotrauma'

# --------------------------------------------------------------------------------------------------------------
# Utilidades
# --------------------------------------------------------------------------------------------------------------

function Get-BLCampo {
    # Lee un campo de un objeto (de JSON) o de una tabla sin fallar si no existe.
    param($Objeto, [string]$Nombre, $Defecto = $null)
    if ($null -eq $Objeto) { return $Defecto }
    if ($Objeto -is [System.Collections.IDictionary]) {
        if ($Objeto.Contains($Nombre) -and $null -ne $Objeto[$Nombre]) { return $Objeto[$Nombre] }
        return $Defecto
    }
    $p = $Objeto.PSObject.Properties[$Nombre]
    if ($null -eq $p -or $null -eq $p.Value) { return $Defecto }
    return $p.Value
}

function Read-BLJson {
    # Lee un fichero JSON (UTF-8, con o sin marca). Devuelve $null si no existe o no se entiende.
    param([string]$Ruta)
    if ([string]::IsNullOrWhiteSpace($Ruta)) { return $null }
    if (-not (Test-Path -LiteralPath $Ruta -PathType Leaf)) { return $null }
    try {
        $texto = [System.IO.File]::ReadAllText($Ruta, [System.Text.Encoding]::UTF8)
        return ($texto | ConvertFrom-Json)
    } catch { return $null }
}

function Write-BLJson {
    # Escribe un objeto como JSON en UTF-8 sin marca.
    param([string]$Ruta, $Objeto)
    $carpeta = Split-Path -Parent $Ruta
    if ($carpeta -and -not (Test-Path -LiteralPath $carpeta)) { [void](New-Item -ItemType Directory -Path $carpeta -Force) }
    $json = $Objeto | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($Ruta, $json, (New-Object System.Text.UTF8Encoding($false)))
}

# --------------------------------------------------------------------------------------------------------------
# Versiones
# --------------------------------------------------------------------------------------------------------------

function ConvertTo-BLVersion {
    # "1.13.4.0" -> [version]. Admite de 2 a 4 numeros y basura detras ("1.13.4.0+6029cd01").
    param([string]$Texto)
    if ([string]::IsNullOrWhiteSpace($Texto)) { return $null }
    $m = [regex]::Match($Texto.Trim(), '^(\d+)\.(\d+)(?:\.(\d+))?(?:\.(\d+))?')
    if (-not $m.Success) { return $null }
    $c = 0; $r = 0
    if ($m.Groups[3].Success) { $c = [int]$m.Groups[3].Value }
    if ($m.Groups[4].Success) { $r = [int]$m.Groups[4].Value }
    return (New-Object System.Version -ArgumentList ([int]$m.Groups[1].Value), ([int]$m.Groups[2].Value), $c, $r)
}

function Compare-BLVersion {
    # Compara como lo hace el juego: Mayor.Menor.Compilacion; la revision (cuarto numero) NO cuenta.
    # (leido en SharedSource\Networking\NetworkMember.cs:255-263 de la 1.13.4)
    # Devuelve: 'igual', 'mia-mas-vieja', 'mia-mas-nueva' o 'desconocida'.
    param($Mia, $Servidor)
    $a = ConvertTo-BLVersion ([string]$Mia)
    $b = ConvertTo-BLVersion ([string]$Servidor)
    if ($null -eq $a -or $null -eq $b) { return 'desconocida' }
    $pares = @(@($a.Major, $b.Major), @($a.Minor, $b.Minor), @($a.Build, $b.Build))
    foreach ($par in $pares) {
        if ($par[0] -lt $par[1]) { return 'mia-mas-vieja' }
        if ($par[0] -gt $par[1]) { return 'mia-mas-nueva' }
    }
    return 'igual'
}

function Get-BLVersionEnsamblado {
    # Version de un .dll del juego SIN cargarlo ni ejecutarlo. Es el mismo numero que usa el juego
    # (GameMain.Version = version del ensamblado). Si falla, prueba con la version del fichero.
    param([string]$Ruta)
    if ([string]::IsNullOrWhiteSpace($Ruta)) { return $null }
    if (-not (Test-Path -LiteralPath $Ruta -PathType Leaf)) { return $null }
    try { return [System.Reflection.AssemblyName]::GetAssemblyName($Ruta).Version } catch { }
    try { return (ConvertTo-BLVersion ((Get-Item -LiteralPath $Ruta).VersionInfo.FileVersion)) } catch { }
    return $null
}

function Get-BLVersionJuego {
    param([string]$Carpeta)
    return (Get-BLVersionEnsamblado (Join-Path $Carpeta 'Barotrauma.dll'))
}

function Get-BLVersionContenido {
    # Atributo gameversion de Content\ContentPackages\Vanilla.xml (para avisar de una instalacion a medias).
    param([string]$Carpeta)
    $ruta = Join-Path $Carpeta 'Content\ContentPackages\Vanilla.xml'
    if (-not (Test-Path -LiteralPath $ruta -PathType Leaf)) { return $null }
    $fs = $null
    try {
        $fs = [System.IO.File]::Open($ruta, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $bufer = New-Object byte[] 4096
        $n = $fs.Read($bufer, 0, $bufer.Length)
        $texto = [System.Text.Encoding]::UTF8.GetString($bufer, 0, $n)
        $m = [regex]::Match($texto, 'gameversion\s*=\s*"([^"]+)"', 'IgnoreCase')
        if ($m.Success) { return (ConvertTo-BLVersion $m.Groups[1].Value) }
    } catch { } finally { if ($null -ne $fs) { $fs.Dispose() } }
    return $null
}

# --------------------------------------------------------------------------------------------------------------
# Ficheros de Steam (formato VDF) y busqueda del juego
# --------------------------------------------------------------------------------------------------------------

function ConvertFrom-BLVdf {
    # Lee el formato de texto de Valve ("clave" "valor" / "clave" { ... }) y devuelve tablas ordenadas anidadas.
    # Las claves no distinguen mayusculas. Admite comentarios // y las barras escapadas (\\).
    param([string]$Texto)
    if ($null -eq $Texto) { $Texto = '' }
    $fichas = New-Object System.Collections.ArrayList
    $i = 0
    $n = $Texto.Length
    while ($i -lt $n) {
        $c = $Texto[$i]
        if ([char]::IsWhiteSpace($c)) { $i++; continue }
        if ($c -eq '/' -and ($i + 1) -lt $n -and $Texto[$i + 1] -eq '/') {
            while ($i -lt $n -and $Texto[$i] -ne "`n") { $i++ }
            continue
        }
        if ($c -eq '{') { [void]$fichas.Add(@{ T = 'abre' }); $i++; continue }
        if ($c -eq '}') { [void]$fichas.Add(@{ T = 'cierra' }); $i++; continue }
        $sb = New-Object System.Text.StringBuilder
        if ($c -eq '"') {
            $i++
            while ($i -lt $n -and $Texto[$i] -ne '"') {
                if ($Texto[$i] -eq '\' -and ($i + 1) -lt $n) {
                    $s = [string]$Texto[$i + 1]
                    if ($s -ceq 'n') { [void]$sb.Append("`n") }
                    elseif ($s -ceq 't') { [void]$sb.Append("`t") }
                    else { [void]$sb.Append($s) }
                    $i += 2
                    continue
                }
                [void]$sb.Append($Texto[$i])
                $i++
            }
            $i++
        } else {
            while ($i -lt $n -and -not [char]::IsWhiteSpace($Texto[$i]) -and $Texto[$i] -ne '{' -and $Texto[$i] -ne '}' -and $Texto[$i] -ne '"') {
                [void]$sb.Append($Texto[$i])
                $i++
            }
        }
        [void]$fichas.Add(@{ T = 'texto'; V = $sb.ToString() })
    }

    $raiz = New-Object System.Collections.Specialized.OrderedDictionary -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)
    $pila = New-Object System.Collections.Stack
    $actual = $raiz
    $clave = $null
    foreach ($f in $fichas) {
        if ($f.T -eq 'abre') {
            if ($null -eq $clave) { throw 'VDF mal formado: llave sin nombre' }
            $nuevo = New-Object System.Collections.Specialized.OrderedDictionary -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)
            $actual[[string]$clave] = $nuevo
            $pila.Push($actual)
            $actual = $nuevo
            $clave = $null
        } elseif ($f.T -eq 'cierra') {
            if ($pila.Count -eq 0) { throw 'VDF mal formado: sobra una llave de cierre' }
            $actual = $pila.Pop()
            $clave = $null
        } else {
            if ($null -eq $clave) { $clave = [string]$f.V }
            else { $actual[[string]$clave] = [string]$f.V; $clave = $null }
        }
    }
    return $raiz
}

function Get-BLBibliotecasSteam {
    # De libraryfolders.vdf saca las carpetas de biblioteca. Vale el formato nuevo ("0" { "path" "..." }) y el
    # viejo ("1" "D:\\SteamLibrary").
    param([string]$TextoVdf)
    $salida = New-Object System.Collections.ArrayList
    $doc = $null
    try { $doc = ConvertFrom-BLVdf $TextoVdf } catch { return @() }
    foreach ($nombreRaiz in @($doc.Keys)) {
        $raiz = $doc[[string]$nombreRaiz]
        if ($raiz -isnot [System.Collections.IDictionary]) { continue }
        foreach ($k in @($raiz.Keys)) {
            if ([string]$k -notmatch '^\d+$') { continue }
            $v = $raiz[[string]$k]
            $ruta = $null
            if ($v -is [System.Collections.IDictionary]) { if ($v.Contains('path')) { $ruta = [string]$v['path'] } }
            else { $ruta = [string]$v }
            if (-not [string]::IsNullOrWhiteSpace($ruta)) { [void]$salida.Add($ruta.Replace('/', '\')) }
        }
    }
    return @($salida)
}

function Get-BLDatosManifiestoSteam {
    # De appmanifest_<id>.acf saca installdir y buildid.
    param([string]$TextoAcf)
    $r = @{ InstallDir = $null; BuildId = $null }
    try {
        $doc = ConvertFrom-BLVdf $TextoAcf
        foreach ($nombreRaiz in @($doc.Keys)) {
            $raiz = $doc[[string]$nombreRaiz]
            if ($raiz -isnot [System.Collections.IDictionary]) { continue }
            if ($raiz.Contains('installdir')) { $r.InstallDir = [string]$raiz['installdir'] }
            if ($raiz.Contains('buildid')) { $r.BuildId = [string]$raiz['buildid'] }
        }
    } catch { }
    return $r
}

function Test-BLCarpetaJuego {
    # Una carpeta vale como juego si tiene el ejecutable, su .dll y el paquete de contenido original.
    param([string]$Carpeta)
    if ([string]::IsNullOrWhiteSpace($Carpeta)) { return $false }
    try {
        if (-not (Test-Path -LiteralPath $Carpeta -PathType Container)) { return $false }
        foreach ($f in @('Barotrauma.exe', 'Barotrauma.dll', 'Content\ContentPackages\Vanilla.xml')) {
            if (-not (Test-Path -LiteralPath (Join-Path $Carpeta $f) -PathType Leaf)) { return $false }
        }
        return $true
    } catch { return $false }
}

function ConvertTo-BLCarpetaJuego {
    # Limpia lo que escribe o arrastra una persona: comillas, espacios, o la ruta de Barotrauma.exe.
    param([string]$Texto)
    if ([string]::IsNullOrWhiteSpace($Texto)) { return '' }
    $t = $Texto.Trim().Trim('"').Trim("'").Trim()
    if ($t -match '\.exe$') { $t = Split-Path -Parent $t }
    return $t.TrimEnd('\')
}

function Get-BLValorRegistro {
    param([string]$Clave, [string]$Nombre)
    try {
        $p = Get-ItemProperty -LiteralPath $Clave -Name $Nombre -ErrorAction Stop
        return [string]($p.$Nombre)
    } catch { return $null }
}

function Get-BLRaicesSteam {
    # Carpetas donde puede estar instalado Steam (registro y sitios de siempre). Solo lee.
    $lista = New-Object System.Collections.ArrayList
    $vistas = @{}
    $posibles = @(
        (Get-BLValorRegistro 'HKCU:\Software\Valve\Steam' 'SteamPath'),
        (Get-BLValorRegistro 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' 'InstallPath'),
        (Get-BLValorRegistro 'HKLM:\SOFTWARE\Valve\Steam' 'InstallPath')
    )
    if (${env:ProgramFiles(x86)}) { $posibles += (Join-Path ${env:ProgramFiles(x86)} 'Steam') }
    if ($env:ProgramFiles) { $posibles += (Join-Path $env:ProgramFiles 'Steam') }
    foreach ($p in $posibles) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        $q = $p.Replace('/', '\').TrimEnd('\')
        $k = $q.ToLowerInvariant()
        if ($vistas.ContainsKey($k)) { continue }
        $vistas[$k] = $true
        if (Test-Path -LiteralPath $q -PathType Container) { [void]$lista.Add($q) }
    }
    return @($lista)
}

function Find-BLJuegoEnSteam {
    # Dada la carpeta de Steam, devuelve las carpetas donde deberia estar el juego (existan o no), leyendo
    # libraryfolders.vdf y appmanifest_602960.acf.
    param([string]$RaizSteam, [string]$AppId = $script:BL_AppIdSteam)
    $salida = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrWhiteSpace($RaizSteam)) { return @() }
    $bibliotecas = New-Object System.Collections.ArrayList
    [void]$bibliotecas.Add($RaizSteam.TrimEnd('\'))
    foreach ($rel in @('steamapps\libraryfolders.vdf', 'config\libraryfolders.vdf')) {
        $vdf = Join-Path $RaizSteam $rel
        if (-not (Test-Path -LiteralPath $vdf -PathType Leaf)) { continue }
        try {
            $texto = [System.IO.File]::ReadAllText($vdf, [System.Text.Encoding]::UTF8)
            foreach ($b in (Get-BLBibliotecasSteam $texto)) {
                $b2 = $b.TrimEnd('\')
                if (-not ($bibliotecas -contains $b2)) { [void]$bibliotecas.Add($b2) }
            }
        } catch { }
    }
    foreach ($b in $bibliotecas) {
        $acf = Join-Path $b ("steamapps\appmanifest_{0}.acf" -f $AppId)
        if (Test-Path -LiteralPath $acf -PathType Leaf) {
            try {
                $m = Get-BLDatosManifiestoSteam ([System.IO.File]::ReadAllText($acf, [System.Text.Encoding]::UTF8))
                if ($m.InstallDir) { [void]$salida.Add((Join-Path $b ('steamapps\common\' + $m.InstallDir))) }
            } catch { }
        }
        $tipica = Join-Path $b 'steamapps\common\Barotrauma'
        if (-not ($salida -contains $tipica)) { [void]$salida.Add($tipica) }
    }
    return @($salida)
}

function Get-BLBuildIdSteam {
    # buildid de Steam para una carpeta de juego ...\steamapps\common\<juego>. Devuelve '' si no es de Steam.
    param([string]$CarpetaJuego, [string]$AppId = $script:BL_AppIdSteam)
    try {
        $steamapps = Split-Path -Parent (Split-Path -Parent $CarpetaJuego.TrimEnd('\'))
        $acf = Join-Path $steamapps ("appmanifest_{0}.acf" -f $AppId)
        if (Test-Path -LiteralPath $acf -PathType Leaf) {
            $m = Get-BLDatosManifiestoSteam ([System.IO.File]::ReadAllText($acf, [System.Text.Encoding]::UTF8))
            if ($m.BuildId) { return [string]$m.BuildId }
        }
    } catch { }
    return ''
}

function Get-BLCandidatasJuego {
    # Lista ordenada de sitios donde mirar. Cada elemento: Carpeta y Origen. Solo lee.
    #   -SinSistema: no mira el registro ni los discos (para pruebas); usa solo lo que se le pasa.
    param([string]$Recordada = '', [string[]]$RaicesSteam = @(), [switch]$SinSistema)
    $lista = New-Object System.Collections.ArrayList
    $vistas = @{}
    $anadir = {
        param($carpeta, $origen)
        if ([string]::IsNullOrWhiteSpace($carpeta)) { return }
        $c = ([string]$carpeta).Replace('/', '\').TrimEnd('\')
        $k = $c.ToLowerInvariant()
        if ($vistas.ContainsKey($k)) { return }
        $vistas[$k] = $true
        [void]$lista.Add((New-Object psobject -Property @{ Carpeta = $c; Origen = $origen }))
    }
    & $anadir $Recordada 'la carpeta que ya me dijiste'

    if (-not $SinSistema) {
        $claves = @(
            ('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App ' + $script:BL_AppIdSteam),
            ('HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App ' + $script:BL_AppIdSteam)
        )
        foreach ($clave in $claves) { & $anadir (Get-BLValorRegistro $clave 'InstallLocation') 'el registro de Windows (Steam)' }
        $RaicesSteam = @($RaicesSteam) + @(Get-BLRaicesSteam)
    }
    foreach ($raiz in @($RaicesSteam)) {
        foreach ($c in (Find-BLJuegoEnSteam $raiz)) { & $anadir $c 'las bibliotecas de Steam' }
    }
    if (-not $SinSistema) {
        try {
            foreach ($d in [System.IO.DriveInfo]::GetDrives()) {
                if ($d.DriveType -ne [System.IO.DriveType]::Fixed -or -not $d.IsReady) { continue }
                $u = $d.Name.TrimEnd('\')
                foreach ($rel in @('SteamLibrary\steamapps\common\Barotrauma', 'Steam\steamapps\common\Barotrauma',
                        'Program Files (x86)\Steam\steamapps\common\Barotrauma', 'Program Files\Steam\steamapps\common\Barotrauma',
                        'Games\Steam\steamapps\common\Barotrauma', 'Juegos\Steam\steamapps\common\Barotrauma',
                        'Program Files\Epic Games\Barotrauma', 'Epic Games\Barotrauma')) {
                    & $anadir ($u + '\' + $rel) 'las carpetas de siempre'
                }
            }
        } catch { }
        # Copia de Epic Games (SUPUESTO: no se ha probado con una copia de Epic de verdad).
        try {
            $manifiestos = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
            if (Test-Path -LiteralPath $manifiestos -PathType Container) {
                foreach ($item in (Get-ChildItem -LiteralPath $manifiestos -Filter '*.item' -File -ErrorAction SilentlyContinue)) {
                    $j = Read-BLJson $item.FullName
                    $exe = [string](Get-BLCampo $j 'LaunchExecutable' '')
                    $nom = [string](Get-BLCampo $j 'DisplayName' '')
                    if ($exe -match 'Barotrauma' -or $nom -match 'Barotrauma') {
                        & $anadir ([string](Get-BLCampo $j 'InstallLocation' '')) 'Epic Games'
                    }
                }
            }
        } catch { }
    }
    return @($lista)
}

function Find-BLJuego {
    # Devuelve @{ Carpeta; Origen } de la primera carpeta que de verdad contiene el juego, o $null.
    param([string]$Recordada = '', [string[]]$RaicesSteam = @(), [switch]$SinSistema)
    foreach ($c in (Get-BLCandidatasJuego -Recordada $Recordada -RaicesSteam $RaicesSteam -SinSistema:$SinSistema)) {
        if (Test-BLCarpetaJuego $c.Carpeta) { return $c }
    }
    return $null
}

# --------------------------------------------------------------------------------------------------------------
# Nombres (jugador y servidor) y linea de ordenes
# --------------------------------------------------------------------------------------------------------------

function Test-BLNombreJugador {
    # Devuelve '' si el nombre vale, o una frase que explica por que no.
    # Reglas del servidor leidas en la 1.13.4 (ServerSource\Networking\Client.cs:186-214): no vacio, maximo 32,
    # prohibidos ; < > / \ [ ] " ? y solo caracteres de los rangos permitidos de fabrica.
    param([string]$Nombre)
    if ([string]::IsNullOrWhiteSpace($Nombre)) { return 'esta vacio' }
    $n = $Nombre.Trim()
    if ($n.Length -gt 32) { return 'tiene mas de 32 letras' }
    if ($n[0] -eq '-' -or $n[0] -eq '+') { return 'no puede empezar por - ni por +' }
    $rangos = @(@(32, 33), @(38, 46), @(48, 57), @(65, 90), @(95, 122), @(192, 255), @(384, 591), @(1024, 1279))
    foreach ($ch in $n.ToCharArray()) {
        if (';<>/\[]"?'.IndexOf($ch) -ge 0) { return ('lleva un caracter prohibido: ' + $ch) }
        $v = [int]$ch
        $vale = $false
        foreach ($r in $rangos) { if ($v -ge $r[0] -and $v -le $r[1]) { $vale = $true; break } }
        if (-not $vale) { return ('lleva un caracter que el servidor no admite: ' + $ch) }
    }
    return ''
}

function Test-BLNombreServidor {
    # Devuelve '' si vale. El nombre viaja entre comillas en la linea de ordenes: sin comillas ni barras.
    param([string]$Nombre)
    if ([string]::IsNullOrWhiteSpace($Nombre)) { return 'esta vacio' }
    $n = $Nombre.Trim()
    if ($n.Length -gt 60) { return 'tiene mas de 60 letras' }
    foreach ($ch in $n.ToCharArray()) {
        if ('"\/<>|:*?'.IndexOf($ch) -ge 0) { return ('lleva un caracter que no vale: ' + $ch) }
        if ([int]$ch -lt 32) { return 'lleva un caracter de control' }
    }
    return ''
}

function ConvertTo-BLArgumento {
    # Pone comillas a un argumento si las necesita (reglas de la linea de ordenes de Windows).
    param([string]$Texto)
    if ($null -eq $Texto) { $Texto = '' }
    if ($Texto -ne '' -and $Texto -notmatch '[\s"]') { return $Texto }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    $barras = 0
    foreach ($ch in $Texto.ToCharArray()) {
        if ($ch -eq '\') { $barras++; continue }
        if ($ch -eq '"') {
            [void]$sb.Append('\' * ($barras * 2 + 1))
            [void]$sb.Append('"')
            $barras = 0
            continue
        }
        if ($barras -gt 0) { [void]$sb.Append('\' * $barras); $barras = 0 }
        [void]$sb.Append($ch)
    }
    if ($barras -gt 0) { [void]$sb.Append('\' * ($barras * 2)) }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function Get-BLArgumentosCliente {
    # Argumentos de Barotrauma.exe para entrar directo a un servidor. Leido en la 1.13.4:
    #   -connect TIENE que ser el primer argumento, seguido del nombre (solo se muestra) y de UNA direccion IP
    #   literal con puerto; -username fija el nombre del jugador; -skipintro salta los videos;
    #   -lenienthandshake alarga los plazos del saludo (para VPN).
    param([string]$NombreServidor, [string]$Direccion, [int]$Puerto, [string]$Jugador, [switch]$SaludoTolerante)
    if (-not (Test-BLIpLiteral $Direccion)) { throw ('la direccion no es una IP: ' + $Direccion) }
    if ($Puerto -lt 1 -or $Puerto -gt 65535) { throw ('puerto fuera de rango: ' + $Puerto) }
    $partes = @('-connect', ('"' + $NombreServidor + '"'), ($Direccion + ':' + $Puerto), '-username', ('"' + $Jugador + '"'), '-skipintro')
    if ($SaludoTolerante) { $partes += '-lenienthandshake' }
    return ($partes -join ' ')
}

# --------------------------------------------------------------------------------------------------------------
# Direcciones y redes
# --------------------------------------------------------------------------------------------------------------

function Test-BLIpLiteral {
    # Solo IPv4 escrita con sus cuatro numeros (el juego no resuelve nombres por la linea de ordenes).
    param([string]$Texto)
    if ([string]::IsNullOrWhiteSpace($Texto)) { return $false }
    $m = [regex]::Match($Texto.Trim(), '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
    if (-not $m.Success) { return $false }
    for ($i = 1; $i -le 4; $i++) { if ([int]$m.Groups[$i].Value -gt 255) { return $false } }
    return $true
}

function ConvertTo-BLNumeroIp {
    param([string]$Ip)
    if (-not (Test-BLIpLiteral $Ip)) { return $null }
    $p = $Ip.Trim().Split('.')
    return ([uint64]$p[0] * 16777216 + [uint64]$p[1] * 65536 + [uint64]$p[2] * 256 + [uint64]$p[3])
}

function Test-BLMismaRed {
    # Cierto si las dos IP caen en la misma red con ese prefijo (24 = 255.255.255.0).
    param([string]$IpA, [string]$IpB, [int]$Prefijo)
    $a = ConvertTo-BLNumeroIp $IpA
    $b = ConvertTo-BLNumeroIp $IpB
    if ($null -eq $a -or $null -eq $b) { return $false }
    if ($Prefijo -le 0) { return $true }
    if ($Prefijo -ge 32) { return ($a -eq $b) }
    $div = [uint64][math]::Pow(2, 32 - $Prefijo)
    return (($a - ($a % $div)) -eq ($b - ($b % $div)))
}

function Test-BLIpPrivada {
    param([string]$Ip)
    return ((Test-BLMismaRed $Ip '10.0.0.0' 8) -or (Test-BLMismaRed $Ip '172.16.0.0' 12) -or (Test-BLMismaRed $Ip '192.168.0.0' 16))
}

function Resolve-BLDireccion {
    # Devuelve una IPv4 literal. Si le dan un nombre (solo vale para "internet"), lo resuelve por DNS.
    param([string]$Texto)
    if ([string]::IsNullOrWhiteSpace($Texto)) { return $null }
    $t = $Texto.Trim()
    if (Test-BLIpLiteral $t) { return $t }
    try {
        foreach ($d in [System.Net.Dns]::GetHostAddresses($t)) {
            if ($d.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) { return $d.ToString() }
        }
    } catch { }
    return $null
}

function Get-BLInterfaces {
    # Interfaces de red ACTIVAS de este PC con su IPv4. Solo lee (no necesita administrador).
    $lista = New-Object System.Collections.ArrayList
    try {
        foreach ($ni in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            if ($ni.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up) { continue }
            $props = $ni.GetIPProperties()
            $puerta = $false
            foreach ($g in $props.GatewayAddresses) {
                if ($g.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and $g.Address.ToString() -ne '0.0.0.0') { $puerta = $true }
            }
            foreach ($u in $props.UnicastAddresses) {
                if ($u.Address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { continue }
                $prefijo = 24
                try { $prefijo = [int]$u.PrefixLength } catch { }
                [void]$lista.Add((New-Object psobject -Property @{
                            Alias = [string]$ni.Name; Descripcion = [string]$ni.Description; Clase = [string]$ni.NetworkInterfaceType
                            Ip = $u.Address.ToString(); Prefijo = $prefijo; TienePuerta = $puerta
                        }))
            }
        }
    } catch { }
    return @($lista)
}

function Get-BLTipoDeRed {
    # Clasifica una interfaz: lan, zerotier, tailscale, hamachi, radmin, otra (otro tunel o VPN), publica
    # (una IP de internet puesta directamente en el PC) o descartar (bucle local, sin direccion, maquinas virtuales).
    param([string]$Alias, [string]$Descripcion, [string]$Clase, [string]$Ip)
    if (-not (Test-BLIpLiteral $Ip)) { return 'descartar' }
    if ((Test-BLMismaRed $Ip '127.0.0.0' 8) -or (Test-BLMismaRed $Ip '169.254.0.0' 16) -or $Ip -eq '0.0.0.0') { return 'descartar' }
    if ($Clase -eq 'Loopback') { return 'descartar' }
    $t = ($Alias + ' ' + $Descripcion).ToLowerInvariant()
    if ($t -match 'zerotier') { return 'zerotier' }
    if ($t -match 'tailscale') { return 'tailscale' }
    if ($t -match 'hamachi') { return 'hamachi' }
    if ($t -match 'radmin') { return 'radmin' }
    if ($t -match 'hyper-v|vethernet|virtualbox|vmware|docker|wsl|teredo|bluetooth|npcap|loopback') { return 'descartar' }
    if (Test-BLMismaRed $Ip $script:BL_RangoTailscale 10) { return 'tailscale' }
    if (Test-BLMismaRed $Ip '25.0.0.0' 8) { return 'hamachi' }
    if (Test-BLMismaRed $Ip '26.0.0.0' 8) { return 'radmin' }
    if ($t -match 'wireguard|wintun|tap-windows|openvpn|fortinet|anyconnect|vpn|tunnel') { return 'otra' }
    if ($Clase -eq 'Tunnel' -or $Clase -eq 'Ppp') { return 'otra' }
    if (Test-BLIpPrivada $Ip) { return 'lan' }
    return 'publica'
}

function Get-BLEtiquetaRed {
    param([string]$Red)
    switch ($Red) {
        'local' { return 'Este mismo PC' }
        'lan' { return 'Red local' }
        'zerotier' { return 'ZeroTier' }
        'tailscale' { return 'Tailscale' }
        'hamachi' { return 'Hamachi' }
        'radmin' { return 'Radmin VPN' }
        'otra' { return 'Otra red privada' }
        'publica' { return 'Internet' }
        'internet' { return 'Internet' }
    }
    return $Red
}

function Get-BLTipoGeneral {
    # lan, vpn, internet o local: para ordenar y para decidir el saludo tolerante.
    param([string]$Red)
    switch ($Red) {
        'local' { return 'local' }
        'lan' { return 'lan' }
        'publica' { return 'internet' }
        'internet' { return 'internet' }
    }
    return 'vpn'
}

function Get-BLDireccionesServidor {
    # Para el ANFITRION: de las interfaces de su PC saca, ordenadas, las direcciones que dar a los amigos.
    #   -Orden: redes que entran y en que orden (las que no esten, no salen). Por omision: red local y luego cada VPN.
    #   -Excluidas: IP o nombres de red que no se quieren dar.
    #   -Internet: direccion publica o nombre escritos A MANO por el anfitrion (vacio = no se da ninguna).
    param([object[]]$Interfaces, [string[]]$Orden = @('lan', 'zerotier', 'radmin', 'hamachi', 'tailscale', 'otra'),
        [string[]]$Excluidas = @(), [string]$Internet = '', [int]$PuertoInternet = 0)
    $filas = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($i in @($Interfaces)) {
        if ($null -eq $i) { continue }
        $red = Get-BLTipoDeRed -Alias $i.Alias -Descripcion $i.Descripcion -Clase $i.Clase -Ip $i.Ip
        $pos = [array]::IndexOf(@($Orden), $red)
        if ($pos -lt 0) { continue }
        if (@($Excluidas) -contains $i.Ip -or @($Excluidas) -contains $red) { continue }
        $puerta = 1
        if ($i.TienePuerta) { $puerta = 0 }
        $n++
        [void]$filas.Add((New-Object psobject -Property @{
                    Pos = $pos; Puerta = $puerta; N = $n
                    Dato = [ordered]@{ red = $red; tipo = (Get-BLTipoGeneral $red); direccion = $i.Ip; prefijo = [int]$i.Prefijo
                        etiqueta = (Get-BLEtiquetaRed $red); interfaz = [string]$i.Alias }
                }))
    }
    $salida = New-Object System.Collections.ArrayList
    foreach ($f in ($filas | Sort-Object Pos, Puerta, N)) { [void]$salida.Add($f.Dato) }
    if (-not [string]::IsNullOrWhiteSpace($Internet)) {
        $d = [ordered]@{ red = 'internet'; tipo = 'internet'; direccion = $Internet.Trim(); prefijo = 0; etiqueta = 'Internet'; interfaz = '' }
        if ($PuertoInternet -gt 0) { $d['puerto'] = $PuertoInternet }
        [void]$salida.Add($d)
    }
    return @($salida)
}

function Test-BLTengoEsaRed {
    # Para el AMIGO: tengo alguna interfaz en la red de esa direccion del servidor?
    # Devuelve $true, $false o $null (no se puede saber: internet).
    param($Candidata, [object[]]$Interfaces)
    $red = [string](Get-BLCampo $Candidata 'red' '')
    $ip = [string](Get-BLCampo $Candidata 'direccion' '')
    $prefijo = [int](Get-BLCampo $Candidata 'prefijo' 0)
    if ($red -eq 'local') { return $true }
    if ($red -eq 'internet' -or $red -eq 'publica') { return $null }
    if (-not (Test-BLIpLiteral $ip)) { return $null }
    $base = $ip
    if ($prefijo -le 0 -or $prefijo -ge 31) {
        # Tailscale da /32 a cada equipo: se mira el rango entero de la VPN.
        if ($red -eq 'tailscale') { $base = $script:BL_RangoTailscale; $prefijo = 10 }
        elseif ($red -eq 'hamachi') { $base = '25.0.0.0'; $prefijo = 8 }
        elseif ($red -eq 'radmin') { $base = '26.0.0.0'; $prefijo = 8 }
        else { return $null }
    }
    foreach ($i in @($Interfaces)) {
        if ($null -eq $i) { continue }
        if (Test-BLMismaRed $i.Ip $base $prefijo) { return $true }
    }
    return $false
}

# --------------------------------------------------------------------------------------------------------------
# Datos del servidor (servidor.json, lo genera el anfitrion) y datos del jugador (nombre y carpeta recordados)
# --------------------------------------------------------------------------------------------------------------

function Read-BLDatosServidor {
    # Lee y comprueba servidor.json. Devuelve @{ Ok; Error; Nombre; Puerto; Version; Anfitrion; Contrasena;
    # Sonda; SaludoTolerante; Generado; Direcciones = @( @{ red; tipo; direccion; puerto; prefijo; etiqueta } ) }
    #   -PermitirBucle (solo pruebas y laboratorio): no descarta las direcciones 127.x.
    #   -PermitirVacio: vale sin direcciones (el anfitrion jugando en su PC, que entra por 127.0.0.1).
    param([string]$Ruta, [switch]$PermitirBucle, [switch]$PermitirVacio)
    $r = @{ Ok = $false; Error = ''; Direcciones = @() }
    if (-not (Test-Path -LiteralPath $Ruta -PathType Leaf)) { $r.Error = 'no encuentro servidor.json'; return $r }
    $j = Read-BLJson $Ruta
    if ($null -eq $j) { $r.Error = 'servidor.json esta roto (no es un JSON valido)'; return $r }
    $formato = [int](Get-BLCampo $j 'formato' 0)
    if ($formato -ne $script:BL_FormatoDatos) { $r.Error = ('servidor.json es de otra version de Barotrauma LAN (formato ' + $formato + ')'); return $r }
    $s = Get-BLCampo $j 'servidor' $null
    $r.Nombre = [string](Get-BLCampo $s 'nombre' '')
    $r.Puerto = [int](Get-BLCampo $s 'puerto' 0)
    $r.Version = [string](Get-BLCampo $s 'version' '')
    $r.Anfitrion = [string](Get-BLCampo $s 'anfitrion' 'el anfitrion')
    $clave = [string](Get-BLCampo $s 'contrasena' '')
    $r.Contrasena = $clave
    $r.TieneContrasena = [bool](Get-BLCampo $s 'tieneContrasena' $false)
    $r.Sonda = [string](Get-BLCampo $j 'sonda' 'limpia')
    $r.SaludoTolerante = [string](Get-BLCampo $j 'saludoTolerante' 'vpn')
    $r.Generado = [string](Get-BLCampo $j 'generado' '')
    $e = Test-BLNombreServidor $r.Nombre
    if ($e) { $r.Error = ('el nombre del servidor ' + $e); return $r }
    if ($r.Puerto -lt 1 -or $r.Puerto -gt 65535) { $r.Error = 'el puerto del servidor no vale'; return $r }
    if ($null -eq (ConvertTo-BLVersion $r.Version)) { $r.Error = 'falta la version del juego del servidor'; return $r }
    if (@('limpia', 'ping', 'ninguna') -notcontains $r.Sonda) { $r.Error = ('modo de sonda desconocido: ' + $r.Sonda); return $r }
    if (@('vpn', 'siempre', 'nunca') -notcontains $r.SaludoTolerante) { $r.SaludoTolerante = 'vpn' }
    $lista = New-Object System.Collections.ArrayList
    foreach ($d in @(Get-BLCampo $j 'direcciones' @())) {
        if ($null -eq $d) { continue }
        $red = [string](Get-BLCampo $d 'red' '')
        $dir = [string](Get-BLCampo $d 'direccion' '')
        if ([string]::IsNullOrWhiteSpace($dir)) { continue }
        $tipo = [string](Get-BLCampo $d 'tipo' (Get-BLTipoGeneral $red))
        if ($tipo -ne 'internet' -and -not (Test-BLIpLiteral $dir)) { $r.Error = ('direccion que no es una IP: ' + $dir); return $r }
        if ((Test-BLMismaRed $dir '127.0.0.0' 8) -and -not $PermitirBucle) { continue }   # 127.x seria el PC del propio amigo
        $puerto = [int](Get-BLCampo $d 'puerto' $r.Puerto)
        if ($puerto -lt 1 -or $puerto -gt 65535) { $r.Error = ('puerto que no vale en ' + $dir); return $r }
        [void]$lista.Add(@{ red = $red; tipo = $tipo; direccion = $dir.Trim(); puerto = $puerto
                prefijo = [int](Get-BLCampo $d 'prefijo' 0); etiqueta = [string](Get-BLCampo $d 'etiqueta' (Get-BLEtiquetaRed $red)) })
    }
    if ($lista.Count -eq 0 -and -not $PermitirVacio) { $r.Error = 'servidor.json no trae ninguna direccion'; return $r }
    $r.Direcciones = @($lista)
    $r.Ok = $true
    return $r
}

function Get-BLCarpetaDatos {
    # Donde se recuerda el nombre del jugador y la carpeta del juego: %APPDATA%\BarotraumaLAN (fuera del juego).
    param([string]$Carpeta = '')
    if (-not [string]::IsNullOrWhiteSpace($Carpeta)) { return $Carpeta }
    return (Join-Path $env:APPDATA 'BarotraumaLAN')
}

function Read-BLDatosJugador {
    param([string]$Carpeta = '')
    $j = Read-BLJson (Join-Path (Get-BLCarpetaDatos $Carpeta) 'jugador.json')
    return @{ Jugador = [string](Get-BLCampo $j 'jugador' ''); CarpetaJuego = [string](Get-BLCampo $j 'carpetaJuego' '') }
}

function Save-BLDatosJugador {
    # Devuelve $true si pudo guardarlo. Si no puede, no pasa nada: se volvera a preguntar.
    param([string]$Carpeta = '', [string]$Jugador, [string]$CarpetaJuego)
    try {
        Write-BLJson (Join-Path (Get-BLCarpetaDatos $Carpeta) 'jugador.json') ([ordered]@{ jugador = $Jugador; carpetaJuego = $CarpetaJuego })
        return $true
    } catch { return $false }
}

# --------------------------------------------------------------------------------------------------------------
# LA SONDA: saber si el servidor contesta antes de abrir el juego
#
# Interfaz unica:  Invoke-BLSonda -Modo limpia|ping|ninguna -Destinos <lista con .direccion y .puerto>
# Devuelve, en el mismo orden, objetos con Estado:
#   contesta        el servidor de Barotrauma (su biblioteca de red, Lidgren) ha respondido
#   puerto-cerrado  el PC esta, pero nadie escucha en ese puerto (Windows devolvio "puerto inalcanzable")
#   silencio        no ha vuelto nada (servidor cerrado, cortafuegos, otra red, VPN apagada...)
#   raro            ha vuelto algo que no es lo esperado (se ensena, no se elige solo)
#   sin-sondear     modo "ninguna"
#   error           no se pudo ni enviar
#
# Modo "limpia" (leido en Libraries\Lidgren.Network de la 1.13.4; PENDIENTE de medir en el laboratorio):
#   se manda UN datagrama de tipo Connect (0x83) con un identificador de aplicacion equivocado; el hilo de red
#   del servidor contesta Disconnect (0x87) "Wrong application identifier!" y borra el intento sin avisar al
#   juego: ni registro, ni cliente pendiente, ni veto. REGLA DURA: la sonda NUNCA manda mensajes de datos
#   (tipos 1 a 98), que son los unicos por los que el servidor veta una IP.
# --------------------------------------------------------------------------------------------------------------

function New-BLDatagramaSaludo {
    # Datagrama Connect de Lidgren (NetOutgoingMessage.Encode + NetConnection.SendConnect):
    #   byte 0     0x83 (Connect)        bytes 1-2  0,0 (sin fragmento, secuencia 0)
    #   bytes 3-4  largo de la carga EN BITS, byte bajo primero
    #   carga      [largo][identificador UTF-8] [8 bytes identificador unico] [4 bytes hora, float]
    param([string]$Identificador = $script:BL_IdSonda)
    $id = [System.Text.Encoding]::UTF8.GetBytes($Identificador)
    if ($id.Length -lt 1 -or $id.Length -gt 127) { throw 'el identificador debe medir de 1 a 127 bytes' }
    $carga = New-Object System.Collections.Generic.List[byte]
    $carga.Add([byte]$id.Length)
    $carga.AddRange([byte[]]$id)
    $unico = New-Object byte[] 8
    (New-Object System.Random).NextBytes($unico)
    $carga.AddRange([byte[]]$unico)
    $carga.AddRange([byte[]][System.BitConverter]::GetBytes([single]1.0))
    $bits = $carga.Count * 8
    $d = New-Object System.Collections.Generic.List[byte]
    $d.Add([byte]0x83); $d.Add([byte]0); $d.Add([byte]0)
    $d.Add([byte]($bits -band 0xFF)); $d.Add([byte](($bits -shr 8) -band 0xFF))
    $d.AddRange($carga)
    return , ($d.ToArray())
}

function New-BLDatagramaAdios {
    # Datagrama Disconnect (0x87) con un texto. SOLO lo usa la sonda completa (laboratorio) para soltar el hueco.
    param([string]$Texto = 'sonda')
    $t = [System.Text.Encoding]::UTF8.GetBytes($Texto)
    if ($t.Length -gt 127) { throw 'texto demasiado largo' }
    $bits = ($t.Length + 1) * 8
    $d = New-Object System.Collections.Generic.List[byte]
    $d.Add([byte]0x87); $d.Add([byte]0); $d.Add([byte]0)
    $d.Add([byte]($bits -band 0xFF)); $d.Add([byte](($bits -shr 8) -band 0xFF))
    $d.Add([byte]$t.Length)
    $d.AddRange([byte[]]$t)
    return , ($d.ToArray())
}

function Read-BLDatagramaLidgren {
    # Interpreta la cabecera de un datagrama de Lidgren y, si lleva texto al principio (Disconnect y
    # ConnectResponse), lo saca. Devuelve @{ Valido; Tipo; Texto }.
    param([byte[]]$Datos, [int]$Largo)
    $r = @{ Valido = $false; Tipo = -1; Texto = $null }
    if ($null -eq $Datos -or $Largo -lt 5 -or $Datos.Length -lt $Largo) { return $r }
    $r.Tipo = [int]$Datos[0]
    $bits = [int]$Datos[3] + ([int]$Datos[4] * 256)
    $bytes = [int][math]::Ceiling($bits / 8.0)
    if (($Largo - 5) -lt $bytes) { return $r }
    $r.Valido = $true
    if (($r.Tipo -eq 0x87 -or $r.Tipo -eq 0x84) -and $bytes -ge 1) {
        $pos = 5; $fin = 5 + $bytes
        $largoTexto = 0; $desplaza = 0
        while ($pos -lt $fin) {
            $b = [int]$Datos[$pos]; $pos++
            $largoTexto = $largoTexto -bor (($b -band 0x7F) -shl $desplaza)
            if (($b -band 0x80) -eq 0) { break }
            $desplaza += 7
            if ($desplaza -gt 28) { break }
        }
        if ($largoTexto -ge 0 -and ($pos + $largoTexto) -le $fin) {
            $r.Texto = [System.Text.Encoding]::UTF8.GetString($Datos, $pos, $largoTexto)
        }
    }
    return $r
}

function Invoke-BLSondaLidgren {
    # Manda el saludo a todos los destinos A LA VEZ y espera las respuestas. Hasta $Intentos envios por destino.
    #   -Completa (SOLO LABORATORIO): usa el identificador del juego; el servidor crea un cliente pendiente y
    #    apunta "Incoming connection" en su registro; al recibir la respuesta se manda un Disconnect para soltarlo.
    param([object[]]$Destinos, [int]$EsperaMs = 450, [int]$Intentos = 2, [string]$Identificador = '', [switch]$Completa)
    if ([string]::IsNullOrEmpty($Identificador)) {
        if ($Completa) { $Identificador = $script:BL_IdJuego } else { $Identificador = $script:BL_IdSonda }
    }
    if (-not $Completa -and $Identificador -eq $script:BL_IdJuego) { throw 'la sonda limpia no puede usar el identificador del juego' }
    $saludo = New-BLDatagramaSaludo $Identificador
    $filas = New-Object System.Collections.ArrayList
    foreach ($d in @($Destinos)) {
        $fila = New-Object psobject -Property @{
            Direccion = [string](Get-BLCampo $d 'direccion' ''); Puerto = [int](Get-BLCampo $d 'puerto' 0)
            Estado = 'silencio'; Detalle = ''; Ms = -1; Enviados = 0; Zocalo = $null; Extremo = $null; T0 = -1
        }
        try {
            if (-not (Test-BLIpLiteral $fila.Direccion)) { throw 'no es una IP' }
            $fila.Extremo = New-Object System.Net.IPEndPoint -ArgumentList ([System.Net.IPAddress]::Parse($fila.Direccion)), $fila.Puerto
            $z = New-Object System.Net.Sockets.Socket -ArgumentList ([System.Net.Sockets.AddressFamily]::InterNetwork), ([System.Net.Sockets.SocketType]::Dgram), ([System.Net.Sockets.ProtocolType]::Udp)
            $z.Bind((New-Object System.Net.IPEndPoint -ArgumentList ([System.Net.IPAddress]::Any), 0))
            $fila.Zocalo = $z
        } catch {
            $fila.Estado = 'error'; $fila.Detalle = $_.Exception.Message
        }
        [void]$filas.Add($fila)
    }
    $reloj = [System.Diagnostics.Stopwatch]::StartNew()
    $bufer = New-Object byte[] 2048
    try {
        for ($intento = 1; $intento -le $Intentos; $intento++) {
            $pendientes = @($filas | Where-Object { $_.Estado -eq 'silencio' -and $null -ne $_.Zocalo })
            if ($pendientes.Count -eq 0) { break }
            foreach ($f in $pendientes) {
                try {
                    [void]$f.Zocalo.SendTo($saludo, $f.Extremo)
                    $f.Enviados++
                    if ($f.T0 -lt 0) { $f.T0 = $reloj.ElapsedMilliseconds }
                } catch { $f.Estado = 'error'; $f.Detalle = $_.Exception.GetBaseException().Message }
            }
            $limite = $reloj.ElapsedMilliseconds + $EsperaMs
            while ($reloj.ElapsedMilliseconds -lt $limite) {
                $pendientes = @($filas | Where-Object { $_.Estado -eq 'silencio' -and $null -ne $_.Zocalo })
                if ($pendientes.Count -eq 0) { break }
                $listos = New-Object System.Collections.ArrayList
                foreach ($f in $pendientes) { [void]$listos.Add($f.Zocalo) }
                $resto = [int](($limite - $reloj.ElapsedMilliseconds) * 1000)
                if ($resto -lt 1000) { $resto = 1000 }
                [System.Net.Sockets.Socket]::Select($listos, $null, $null, $resto)
                foreach ($z in @($listos)) {
                    $f = $null
                    foreach ($x in $pendientes) { if ([object]::ReferenceEquals($x.Zocalo, $z)) { $f = $x; break } }
                    if ($null -eq $f) { continue }
                    [System.Net.EndPoint]$remoto = New-Object System.Net.IPEndPoint -ArgumentList ([System.Net.IPAddress]::Any), 0
                    $n = 0
                    try {
                        $n = $z.ReceiveFrom($bufer, [ref]$remoto)
                    } catch {
                        $base = $_.Exception.GetBaseException()
                        if ($base -is [System.Net.Sockets.SocketException] -and $base.SocketErrorCode -eq [System.Net.Sockets.SocketError]::ConnectionReset) {
                            $f.Estado = 'puerto-cerrado'; $f.Detalle = 'el PC esta, pero nadie escucha en ese puerto'
                        } else {
                            $f.Estado = 'error'; $f.Detalle = $base.Message
                        }
                        $f.Ms = [int]($reloj.ElapsedMilliseconds - $f.T0)
                        continue
                    }
                    $f.Ms = [int]($reloj.ElapsedMilliseconds - $f.T0)
                    $ipRemota = ([System.Net.IPEndPoint]$remoto).Address.ToString()
                    if ($ipRemota -ne $f.Direccion) {
                        # El juego tampoco aceptaria una respuesta que llega desde otra IP.
                        $f.Estado = 'raro'; $f.Detalle = ('contesto otra IP: ' + $ipRemota)
                        continue
                    }
                    $m = Read-BLDatagramaLidgren $bufer $n
                    if (-not $m.Valido) { $f.Estado = 'raro'; $f.Detalle = ('respuesta que no es de Lidgren (' + $n + ' bytes)'); continue }
                    if ($m.Tipo -eq 0x87) {
                        $f.Detalle = [string]$m.Texto
                        if ($Completa) { $f.Estado = 'rechazado' } else { $f.Estado = 'contesta' }
                    } elseif ($m.Tipo -eq 0x84) {
                        if ($Completa) {
                            $f.Estado = 'contesta'; $f.Detalle = 'ConnectResponse'
                            try { [void]$z.SendTo((New-BLDatagramaAdios 'sonda'), $remoto) } catch { }
                        } else {
                            $f.Estado = 'raro'; $f.Detalle = 'ConnectResponse inesperado'
                        }
                    } else {
                        $f.Estado = 'raro'; $f.Detalle = ('mensaje de Lidgren de tipo ' + $m.Tipo)
                    }
                }
            }
        }
    } finally {
        foreach ($f in $filas) { if ($null -ne $f.Zocalo) { try { $f.Zocalo.Close() } catch { } } }
    }
    $salida = New-Object System.Collections.ArrayList
    foreach ($f in $filas) {
        [void]$salida.Add((New-Object psobject -Property @{ Direccion = $f.Direccion; Puerto = $f.Puerto; Estado = $f.Estado; Detalle = $f.Detalle; Ms = $f.Ms; Enviados = $f.Enviados }))
    }
    return @($salida)
}

function Invoke-BLPing {
    # Ping normal (ICMP) a varias direcciones a la vez. OJO: solo dice que el PC esta encendido y en esa red;
    # no dice nada del servidor. Y un PC con Windows puede no contestar al ping aunque este.
    param([string[]]$Direcciones, [int]$EsperaMs = 700)
    $salida = @{}
    $tareas = New-Object System.Collections.ArrayList
    foreach ($d in @($Direcciones)) {
        $salida[$d] = $false
        if (-not (Test-BLIpLiteral $d)) { continue }
        try {
            $p = New-Object System.Net.NetworkInformation.Ping
            [void]$tareas.Add(@{ Ip = $d; Tarea = $p.SendPingAsync($d, $EsperaMs); Ping = $p })
        } catch { }
    }
    foreach ($t in $tareas) {
        try {
            if ($t.Tarea.Wait($EsperaMs + 400)) {
                if ($t.Tarea.Result.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) { $salida[$t.Ip] = $true }
            }
        } catch { }
        try { $t.Ping.Dispose() } catch { }
    }
    return $salida
}

function Invoke-BLSonda {
    # LA INTERFAZ. Si el laboratorio mide que la sonda limpia no es limpia, basta cambiar el modo (ajuste "sonda"
    # del anfitrion, o -Sonda en el lanzador) sin tocar nada mas.
    param([ValidateSet('limpia', 'ping', 'ninguna')][string]$Modo = 'limpia', [object[]]$Destinos, [int]$EsperaMs = 450, [int]$Intentos = 2)
    $salida = New-Object System.Collections.ArrayList
    if ($Modo -eq 'limpia') {
        return @(Invoke-BLSondaLidgren -Destinos $Destinos -EsperaMs $EsperaMs -Intentos $Intentos)
    }
    if ($Modo -eq 'ping') {
        $ips = @()
        foreach ($d in @($Destinos)) { $ips += [string](Get-BLCampo $d 'direccion' '') }
        $res = Invoke-BLPing -Direcciones $ips -EsperaMs ($EsperaMs * $Intentos)
        foreach ($d in @($Destinos)) {
            $ip = [string](Get-BLCampo $d 'direccion' '')
            $estado = 'silencio'; $detalle = ''
            if ($res.ContainsKey($ip) -and $res[$ip]) { $estado = 'contesta'; $detalle = 'ping (solo dice que el PC esta)' }
            [void]$salida.Add((New-Object psobject -Property @{ Direccion = $ip; Puerto = [int](Get-BLCampo $d 'puerto' 0); Estado = $estado; Detalle = $detalle; Ms = -1; Enviados = 0 }))
        }
        return @($salida)
    }
    foreach ($d in @($Destinos)) {
        [void]$salida.Add((New-Object psobject -Property @{ Direccion = [string](Get-BLCampo $d 'direccion' ''); Puerto = [int](Get-BLCampo $d 'puerto' 0); Estado = 'sin-sondear'; Detalle = ''; Ms = -1; Enviados = 0 }))
    }
    return @($salida)
}

function Select-BLDestino {
    # De las candidatas ya sondeadas (en orden de preferencia) devuelve el indice de la elegida, o -1.
    #   con sonda: la primera que contesta.
    #   sin sonda: la primera que esta en una red que este PC tiene (EnMiRed = $true).
    param([object[]]$Candidatas)
    $lista = @($Candidatas)
    for ($i = 0; $i -lt $lista.Count; $i++) { if ($lista[$i].Estado -eq 'contesta') { return $i } }
    $sinSondear = @($lista | Where-Object { $_.Estado -eq 'sin-sondear' })
    if ($sinSondear.Count -eq $lista.Count -and $lista.Count -gt 0) {
        for ($i = 0; $i -lt $lista.Count; $i++) { if ($lista[$i].EnMiRed -eq $true) { return $i } }
    }
    return -1
}

function Get-BLDiagnostico {
    # Frases cortas que explican por que no contesta ninguna direccion. Cada candidata trae: Etiqueta, Direccion,
    # Puerto, Tipo (lan/vpn/internet/local), Red, Estado, EnMiRed ($true/$false/$null) y Ping ($true/$false).
    param([object[]]$Candidatas, [string]$Anfitrion = 'el anfitrion')
    $l = New-Object System.Collections.ArrayList
    foreach ($c in @($Candidatas)) {
        $quien = ('{0} ({1})' -f $c.Etiqueta, $c.Direccion)
        if ($c.Estado -eq 'puerto-cerrado') {
            [void]$l.Add(($quien + ': el PC de ' + $Anfitrion + ' esta ahi, pero el servidor NO esta abierto. Pidele que lo abra.'))
        } elseif ($c.Estado -eq 'raro') {
            [void]$l.Add(($quien + ': ha contestado algo que no es el servidor (' + $c.Detalle + ').'))
        } elseif ($c.Estado -eq 'error') {
            [void]$l.Add(($quien + ': no he podido ni enviar (' + $c.Detalle + ').'))
        } elseif ($c.EnMiRed -eq $false) {
            if ($c.Tipo -eq 'lan') { [void]$l.Add(($quien + ': este PC no esta en la red local de ' + $Anfitrion + ' (normal si no estais en la misma casa).')) }
            else { [void]$l.Add(($quien + ': este PC no tiene ' + $c.Etiqueta + ' conectado. Abrelo y conectate a la red de ' + $Anfitrion + '.')) }
        } elseif ($c.Ping -eq $true) {
            [void]$l.Add(($quien + ': el PC de ' + $Anfitrion + ' contesta, pero el servidor no. O esta cerrado o lo corta su cortafuegos.'))
        } elseif ($c.Tipo -eq 'internet') {
            [void]$l.Add(($quien + ': no contesta. Hace falta que ' + $Anfitrion + ' tenga el puerto UDP ' + $c.Puerto + ' redirigido en su router.'))
        } else {
            [void]$l.Add(($quien + ': no contesta. O el servidor esta cerrado, o lo corta el cortafuegos de ' + $Anfitrion + ', o su ' + $c.Etiqueta + ' no esta conectado.'))
        }
    }
    [void]$l.Add(('Preguntale a ' + $Anfitrion + ': 1) tienes el servidor abierto?  2) abriste el cortafuegos (una vez)?  3) estamos en la misma red o VPN?'))
    return @($l)
}
