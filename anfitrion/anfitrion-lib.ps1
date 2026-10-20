# ==============================================================================================================
# anfitrion-lib.ps1  -  Barotrauma LAN 0.1  -  funciones del ANFITRION (el que abre el servidor)
#
# Necesita que antes se haya cargado ..\amigo\barolan-comun.ps1 (lo hacen servidor.ps1 y cortafuegos.ps1).
#
# Reglas que cumple este fichero:
#   - La instalacion del juego es de SOLO LECTURA: de ahi solo se copia.
#   - Nunca borra carpetas. Solo borra ficheros sueltos que el mismo copio (los apunta en barolan-carpeta.json)
#     y la union "Content", que se quita sin tocar lo que hay detras.
#   - Nunca cierra a la fuerza ningun proceso y nunca toca el cortafuegos (eso es cortafuegos.ps1, que abre el dueno).
# Solo ASCII a proposito.
# ==============================================================================================================

$script:AL_FicherosEstado = @('config_player.xml', 'serversettings.xml', 'creature_metrics.xml', 'consoleoutput.txt', 'steam_appid.txt')
$script:AL_PatronesEstado = @('crashreport*.log', 'servercrashreport*.log')
$script:AL_DatosEstado = @('clientpermissions.xml', 'bannedplayers.xml', 'serverblacklist.xml')
$script:AL_NombreManifiesto = 'barolan-carpeta.json'
$script:AL_GrupoCortafuegos = 'Barotrauma LAN'
$script:AL_FicherosPaquete = @('JUGAR-BAROTRAUMA-LAN.bat', 'COMPROBAR-SIN-ABRIR-EL-JUEGO.bat', 'jugar.ps1', 'barolan-comun.ps1', 'LEEME.txt')

# --------------------------------------------------------------------------------------------------------------
# Ajustes del anfitrion (ajustes-anfitrion.json)
# --------------------------------------------------------------------------------------------------------------

function Get-ALAjustesPorDefecto {
    $quien = [string]$env:USERNAME
    if ([string]::IsNullOrWhiteSpace($quien)) { $quien = 'el anfitrion' }
    return [ordered]@{
        formato                        = 1
        nombreAnfitrion                = $quien          # como te conocen tus amigos (sale en sus mensajes)
        nombreServidor                 = ''              # vacio = el de tu juego si se importa, o "Barotrauma LAN"
        puerto                         = 27715           # UDP (no el 27015 de fabrica del juego, que se deja libre)
        maxJugadores                   = 8               # de 1 a 16
        contrasena                     = ''              # vacia = sin contrasena
        contrasenaEnElPaquete          = $true           # el lanzador del amigo se la ensena
        carpetaJuego                   = ''              # vacio = buscarla
        carpetaServidor                = ''              # vacio = <unidad del juego>:\BarotraumaLAN
        datos                          = 'propios'       # propios (perfil y partidas aparte) | los-de-mi-juego
        carpetaPerfil                  = ''              # vacio = carpetaServidor\perfil (solo con datos = propios)
        importarAjustesDeMiJuego       = $true           # la primera vez copia tus ajustes de partida
        anfitrionAdministraDesdeEstePC = $true           # permisos de administrador para quien entra desde 127.0.0.1
        identidad                      = 'pendiente'     # pendiente | steam-si-lo-hay | por-nombre
        recetaPorNombre                = @('steam_api64.dll')   # ficheros que NO se copian si identidad = por-nombre
        sonda                          = 'limpia'        # limpia | ping | ninguna
        saludoTolerante                = $true           # plazos largos de conexion (para VPN)
        ordenRedes                     = @('lan', 'zerotier', 'radmin', 'hamachi', 'tailscale', 'otra')
        redesExcluidas                 = @()             # IP o nombres de red que no quieres dar
        direccionInternet              = ''              # APAGADO. Tu IP publica o nombre, escrito a mano
        puertoInternet                 = 0               # 0 = el mismo puerto
        cortafuegosAlcance             = 'cualquiera'    # cualquiera | subred
    }
}

function Read-ALAjustes {
    # Lee ajustes-anfitrion.json y le pone lo que falte. Con -Crear lo escribe si no existe.
    # Devuelve @{ Ajustes; Existia; Ruta }.
    param([string]$Ruta, [switch]$Crear)
    $a = Get-ALAjustesPorDefecto
    $existia = Test-Path -LiteralPath $Ruta -PathType Leaf
    if ($existia) {
        $j = Read-BLJson $Ruta
        if ($null -eq $j) { throw ('no entiendo ' + $Ruta + ' (no es un JSON valido). Arreglalo o borralo para empezar de cero.') }
        foreach ($k in @($a.Keys)) {
            $p = $j.PSObject.Properties[$k]
            if ($null -eq $p -or $null -eq $p.Value) { continue }
            if ($a[$k] -is [array]) { $a[$k] = @($p.Value) }
            elseif ($a[$k] -is [bool]) { $a[$k] = [bool]$p.Value }
            elseif ($a[$k] -is [int]) { $a[$k] = [int]$p.Value }
            else { $a[$k] = [string]$p.Value }
        }
    } elseif ($Crear) {
        Write-BLJson $Ruta $a
    }
    return @{ Ajustes = $a; Existia = $existia; Ruta = $Ruta }
}

function Test-ALAjustes {
    # Devuelve la lista de pegas (vacia si todo vale).
    param($A)
    $pegas = New-Object System.Collections.ArrayList
    if ($A.puerto -lt 1024 -or $A.puerto -gt 65535) { [void]$pegas.Add('puerto: tiene que estar entre 1024 y 65535') }
    if ($A.maxJugadores -lt 1 -or $A.maxJugadores -gt 16) { [void]$pegas.Add('maxJugadores: de 1 a 16 (el juego no admite mas)') }
    if ($A.nombreServidor) { $e = Test-BLNombreServidor $A.nombreServidor; if ($e) { [void]$pegas.Add('nombreServidor ' + $e) } }
    if ([string]$A.contrasena -match '["\\\s]') { [void]$pegas.Add('contrasena: sin comillas, barras ni espacios') }
    if (([string]$A.contrasena).Length -gt 40) { [void]$pegas.Add('contrasena demasiado larga (maximo 40 letras)') }
    if (@('propios', 'los-de-mi-juego') -notcontains $A.datos) { [void]$pegas.Add('datos: propios o los-de-mi-juego') }
    if (@('pendiente', 'steam-si-lo-hay', 'por-nombre') -notcontains $A.identidad) { [void]$pegas.Add('identidad: pendiente, steam-si-lo-hay o por-nombre') }
    if (@('limpia', 'ping', 'ninguna') -notcontains $A.sonda) { [void]$pegas.Add('sonda: limpia, ping o ninguna') }
    if (@('cualquiera', 'subred') -notcontains $A.cortafuegosAlcance) { [void]$pegas.Add('cortafuegosAlcance: cualquiera o subred') }
    foreach ($f in @($A.recetaPorNombre)) { if ([string]$f -match '[\\/:*?"<>|]') { [void]$pegas.Add('recetaPorNombre: solo nombres de fichero, sin rutas (' + $f + ')') } }
    if ($A.puertoInternet -ne 0 -and ($A.puertoInternet -lt 1 -or $A.puertoInternet -gt 65535)) { [void]$pegas.Add('puertoInternet: de 1 a 65535, o 0') }
    if ([string]$A.direccionInternet -match '[\s"]') { [void]$pegas.Add('direccionInternet: una IP o un nombre, sin espacios') }
    return @($pegas)
}

# --------------------------------------------------------------------------------------------------------------
# Carpeta de servidor propia (copia de los ficheros sueltos del juego + union a Content)
# --------------------------------------------------------------------------------------------------------------

function ConvertTo-ALRutaLimpia {
    param([string]$Ruta)
    return ([System.IO.Path]::GetFullPath($Ruta)).TrimEnd('\')
}

function Test-ALRutaDentro {
    # Cierto si $Hija es $Madre o cuelga de ella.
    param([string]$Hija, [string]$Madre)
    $h = (ConvertTo-ALRutaLimpia $Hija).ToLowerInvariant() + '\'
    $m = (ConvertTo-ALRutaLimpia $Madre).ToLowerInvariant() + '\'
    return $h.StartsWith($m)
}

function Get-ALRaizServidor {
    # Donde vive el servidor: lo que digan los ajustes o <unidad del juego>:\BarotraumaLAN.
    param($A, [string]$CarpetaJuego)
    if (-not [string]::IsNullOrWhiteSpace([string]$A.carpetaServidor)) { return (ConvertTo-ALRutaLimpia ([string]$A.carpetaServidor)) }
    return (Join-Path ([System.IO.Path]::GetPathRoot((ConvertTo-ALRutaLimpia $CarpetaJuego))) 'BarotraumaLAN')
}

function Test-ALRaizSegura {
    # Devuelve '' si se puede usar esa carpeta para el servidor, o por que no.
    param([string]$Raiz, [string]$CarpetaJuego)
    if ([string]::IsNullOrWhiteSpace($Raiz)) { return 'esta vacia' }
    if (-not [System.IO.Path]::IsPathRooted($Raiz)) { return 'tiene que ser una ruta completa (con su unidad)' }
    $r = ConvertTo-ALRutaLimpia $Raiz
    if ($r.Length -le 3) { return 'no puede ser la raiz de una unidad' }
    if (Test-ALRutaDentro $r $CarpetaJuego) { return 'esta dentro de la instalacion del juego (ahi no se escribe)' }
    if (Test-ALRutaDentro $CarpetaJuego $r) { return 'contiene la instalacion del juego' }
    if ($r -match '(?i)\\steamapps(\\|$)') { return 'esta dentro de una biblioteca de Steam' }
    if ($env:LOCALAPPDATA -and (Test-ALRutaDentro $r (Join-Path $env:LOCALAPPDATA 'Daedalic Entertainment GmbH'))) { return 'esta dentro de los datos del juego' }
    return ''
}

function Get-ALPlanCopia {
    # Que ficheros del juego se copian a la carpeta del servidor. NO entran los de estado (config_player.xml,
    # serversettings.xml, permisos, vetos, registros) ni la carpeta Content (va por union).
    param([string]$CarpetaJuego, [string[]]$NoCopiar = @())
    $plan = New-Object System.Collections.ArrayList
    $fuera = @($script:AL_FicherosEstado) + @($NoCopiar | ForEach-Object { ([string]$_).ToLowerInvariant() })
    foreach ($f in (Get-ChildItem -LiteralPath $CarpetaJuego -File -Force)) {
        $n = $f.Name.ToLowerInvariant()
        if ($fuera -contains $n) { continue }
        $salta = $false
        foreach ($p in $script:AL_PatronesEstado) { if ($n -like $p) { $salta = $true } }
        if ($salta) { continue }
        [void]$plan.Add(@{ Rel = $f.Name; Origen = $f.FullName; Tam = [long]$f.Length; Fecha = $f.LastWriteTimeUtc; SoloSiFalta = $false })
    }
    $x64 = Join-Path $CarpetaJuego 'x64'
    if (Test-Path -LiteralPath $x64 -PathType Container) {
        foreach ($f in (Get-ChildItem -LiteralPath $x64 -File -Force)) {
            [void]$plan.Add(@{ Rel = ('x64\' + $f.Name); Origen = $f.FullName; Tam = [long]$f.Length; Fecha = $f.LastWriteTimeUtc; SoloSiFalta = $false })
        }
    }
    $data = Join-Path $CarpetaJuego 'Data'
    if (Test-Path -LiteralPath $data -PathType Container) {
        foreach ($f in (Get-ChildItem -LiteralPath $data -File -Force)) {
            if ($script:AL_DatosEstado -contains $f.Name.ToLowerInvariant()) { continue }
            # El servidor puede reescribir algunos (karma): solo se ponen si faltan, o al cambiar de version.
            [void]$plan.Add(@{ Rel = ('Data\' + $f.Name); Origen = $f.FullName; Tam = [long]$f.Length; Fecha = $f.LastWriteTimeUtc; SoloSiFalta = $true })
        }
    }
    return @($plan)
}

function Test-ALFicheroIgual {
    param([string]$Destino, [long]$Tam, [datetime]$Fecha)
    if (-not (Test-Path -LiteralPath $Destino -PathType Leaf)) { return $false }
    $d = Get-Item -LiteralPath $Destino -Force
    if ([long]$d.Length -ne $Tam) { return $false }
    return ([math]::Abs(($d.LastWriteTimeUtc - $Fecha).TotalSeconds) -le 2)
}

function Get-ALDestinoUnion {
    # A donde apunta una union o enlace de carpeta ('' si no lo es).
    param([string]$Ruta)
    try {
        $i = Get-Item -LiteralPath $Ruta -Force -ErrorAction Stop
        if (-not ($i.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { return '' }
        $t = @($i.Target)
        if ($t.Count -gt 0 -and $t[0]) { return ([string]$t[0]) -replace '^\\\?\?\\', '' }
        return '?'
    } catch { return '' }
}

function Remove-ALUnion {
    # Quita SOLO la union (el nombre). Lo que hay detras, que es el Content del juego, no se toca.
    # Si la ruta no es una union, no hace nada y devuelve $false.
    param([string]$Ruta)
    if (-not (Test-Path -LiteralPath $Ruta)) { return $false }
    $i = Get-Item -LiteralPath $Ruta -Force
    if (-not ($i.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { return $false }
    [System.IO.Directory]::Delete($Ruta, $false)
    return $true
}

function Set-ALUnionContent {
    # Deja <servidor>\Content como union a <juego>\Content. Devuelve 'estaba', 'creada' o 'rehecha'.
    param([string]$CarpetaJuego, [string]$Destino)
    $origen = ConvertTo-ALRutaLimpia (Join-Path $CarpetaJuego 'Content')
    $union = Join-Path $Destino 'Content'
    $resultado = 'creada'
    if (Test-Path -LiteralPath $union) {
        $apunta = Get-ALDestinoUnion $union
        if ($apunta -eq '') { throw ($union + ' existe y NO es una union. No la toco: mira que es y quitala a mano si sobra.') }
        if ($apunta -ne '?' -and (ConvertTo-ALRutaLimpia $apunta) -ieq $origen) { return 'estaba' }
        [void](Remove-ALUnion $union)
        $resultado = 'rehecha'
    }
    [void](New-Item -ItemType Junction -Path $union -Target $origen -ErrorAction Stop)
    if (-not (Test-Path -LiteralPath (Join-Path $union 'ContentPackages\Vanilla.xml') -PathType Leaf)) {
        throw ('la union ' + $union + ' no deja ver el contenido del juego')
    }
    return $resultado
}

function Sync-ALCarpetaServidor {
    # Crea o pone al dia <Raiz>\servidor a partir de la instalacion del juego.
    #   -SoloMirar: no escribe nada; dice que haria.
    # Devuelve @{ Destino; Nuevo; Actualizado; VersionAntes; VersionAhora; Build; Copiados; Borrados; Pendientes;
    #             Union; Respaldo; Excluidos }
    param([string]$CarpetaJuego, [string]$Raiz, [string[]]$NoCopiar = @(), [switch]$SoloMirar)
    $destino = Join-Path $Raiz 'servidor'
    $r = @{ Destino = $destino; Nuevo = $false; Actualizado = $false; VersionAntes = ''; VersionAhora = ''; Build = ''
        Copiados = 0; Borrados = 0; Pendientes = 0; Union = ''; Respaldo = ''; Excluidos = @($NoCopiar) }
    if (-not (Test-Path -LiteralPath (Join-Path $CarpetaJuego 'DedicatedServer.exe') -PathType Leaf)) {
        throw ('en ' + $CarpetaJuego + ' no esta DedicatedServer.exe (el servidor viene con el juego: verifica los archivos en Steam)')
    }
    $ver = Get-BLVersionEnsamblado (Join-Path $CarpetaJuego 'DedicatedServer.dll')
    if ($null -eq $ver) { throw 'no puedo leer la version de DedicatedServer.dll' }
    $r.VersionAhora = $ver.ToString()
    $r.Build = Get-BLBuildIdSteam $CarpetaJuego

    $rutaManifiesto = Join-Path $destino $script:AL_NombreManifiesto
    $manifiesto = Read-BLJson $rutaManifiesto
    if ($null -eq $manifiesto) {
        if ((Test-Path -LiteralPath $destino) -and @(Get-ChildItem -LiteralPath $destino -Force).Count -gt 0) {
            throw ('la carpeta ' + $destino + ' ya existe y no la he creado yo (no tiene ' + $script:AL_NombreManifiesto + '). Elige otra carpetaServidor.')
        }
        $r.Nuevo = $true
    } else {
        $r.VersionAntes = [string](Get-BLCampo $manifiesto 'versionJuego' '')
        $buildAntes = [string](Get-BLCampo $manifiesto 'build' '')
        if ($r.VersionAntes -ne $r.VersionAhora) { $r.Actualizado = $true }
        if ($buildAntes -and $r.Build -and $buildAntes -ne $r.Build) { $r.Actualizado = $true }
    }

    $plan = @(Get-ALPlanCopia -CarpetaJuego $CarpetaJuego -NoCopiar $NoCopiar)
    $enPlan = @{}
    $copiar = New-Object System.Collections.ArrayList
    foreach ($p in $plan) {
        $enPlan[$p.Rel.ToLowerInvariant()] = $true
        $dst = Join-Path $destino $p.Rel
        if ($p.SoloSiFalta -and -not $r.Actualizado) {
            if (-not (Test-Path -LiteralPath $dst -PathType Leaf)) { [void]$copiar.Add($p) }
        } elseif (-not (Test-ALFicheroIgual $dst $p.Tam $p.Fecha)) { [void]$copiar.Add($p) }
    }
    # Sobrantes: ficheros que copie yo en su dia (estan en el manifiesto) y que ya no tocan.
    $sobran = New-Object System.Collections.ArrayList
    foreach ($f in @(Get-BLCampo $manifiesto 'ficheros' @())) {
        $rel = [string]$f
        if ([string]::IsNullOrWhiteSpace($rel) -or $rel -match '\.\.' -or [System.IO.Path]::IsPathRooted($rel)) { continue }
        if ($enPlan.ContainsKey($rel.ToLowerInvariant())) { continue }
        if ($script:AL_FicherosEstado -contains $rel.ToLowerInvariant()) { continue }
        if (Test-Path -LiteralPath (Join-Path $destino $rel) -PathType Leaf) { [void]$sobran.Add($rel) }
    }
    $r.Pendientes = $copiar.Count + $sobran.Count
    $unionAhora = Get-ALDestinoUnion (Join-Path $destino 'Content')
    if ($unionAhora -eq '' -or $unionAhora -eq '?' -or (ConvertTo-ALRutaLimpia $unionAhora) -ine (ConvertTo-ALRutaLimpia (Join-Path $CarpetaJuego 'Content'))) { $r.Union = 'falta' } else { $r.Union = 'estaba' }
    if ($SoloMirar) { return $r }
    $rutaContent = Join-Path $destino 'Content'
    if ((Test-Path -LiteralPath $rutaContent) -and $unionAhora -eq '') {
        throw ($rutaContent + ' existe y NO es una union. No toco nada: mira que es y quitala a mano si sobra.')
    }

    foreach ($c in @($Raiz, $destino, (Join-Path $destino 'x64'), (Join-Path $destino 'Data'), (Join-Path $destino 'LocalMods'), (Join-Path $Raiz 'respaldos'))) {
        if (-not (Test-Path -LiteralPath $c)) { [void](New-Item -ItemType Directory -Path $c -Force) }
    }
    if ($r.Actualizado) {
        # El juego cambio de version: se guarda lo que el servidor tenia escrito antes de pisar nada.
        $r.Respaldo = Join-Path $Raiz ('respaldos\' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '-antes-de-' + $r.VersionAhora)
        [void](New-Item -ItemType Directory -Path (Join-Path $r.Respaldo 'Data') -Force)
        foreach ($n in @('serversettings.xml', 'config_player.xml')) {
            $src = Join-Path $destino $n
            if (Test-Path -LiteralPath $src -PathType Leaf) { [System.IO.File]::Copy($src, (Join-Path $r.Respaldo $n), $true) }
        }
        $dataDestino = Join-Path $destino 'Data'
        foreach ($f in (Get-ChildItem -LiteralPath $dataDestino -File -Force -ErrorAction SilentlyContinue)) {
            [System.IO.File]::Copy($f.FullName, (Join-Path $r.Respaldo ('Data\' + $f.Name)), $true)
        }
    }
    # El manifiesto se escribe ANTES de copiar: si la copia se corta a medias, la siguiente pasada la termina.
    $lista = @($plan | ForEach-Object { $_.Rel })
    $datosManifiesto = [ordered]@{
        formato = 1; herramienta = ('Barotrauma LAN ' + $script:BL_Version); versionJuego = $r.VersionAhora; build = $r.Build
        carpetaJuego = (ConvertTo-ALRutaLimpia $CarpetaJuego); actualizado = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        noCopiados = @($NoCopiar); ficheros = $lista
    }
    Write-BLJson $rutaManifiesto $datosManifiesto
    foreach ($p in $copiar) {
        $dst = Join-Path $destino $p.Rel
        if (Test-Path -LiteralPath $dst -PathType Leaf) {
            $i = Get-Item -LiteralPath $dst -Force
            if ($i.IsReadOnly) { $i.IsReadOnly = $false }
        }
        [System.IO.File]::Copy($p.Origen, $dst, $true)
        $r.Copiados++
    }
    foreach ($rel in $sobran) {
        $ruta = Join-Path $destino $rel
        if (-not (Test-ALRutaDentro $ruta $destino)) { continue }
        [System.IO.File]::Delete($ruta)
        $r.Borrados++
    }
    $r.Union = Set-ALUnionContent -CarpetaJuego $CarpetaJuego -Destino $destino
    $r.Pendientes = 0
    return $r
}

function Get-ALEntornoServidor {
    # Variables de entorno con las que se lanza el servidor cuando sus datos son "propios": su carpeta de datos
    # (partidas, temporales, mods del Workshop) cae dentro de $Perfil y NO en la tuya.
    # Es la receta que mide el laboratorio con el ejecutable real: lo que redirige es USERPROFILE (el juego pide la
    # carpeta a Windows, que la calcula a partir de el); las demas van por coherencia. $Perfil\AppData\Local tiene
    # que existir ANTES de arrancar (lo crea Initialize-ALPerfil).
    param([string]$Perfil)
    $p = ConvertTo-ALRutaLimpia $Perfil
    return [ordered]@{
        USERPROFILE  = $p
        LOCALAPPDATA = (Join-Path $p 'AppData\Local')
        APPDATA      = (Join-Path $p 'AppData\Roaming')
        TEMP         = (Join-Path $p 'Temp')
        TMP          = (Join-Path $p 'Temp')
    }
}

function Initialize-ALPerfil {
    param([string]$Perfil)
    foreach ($d in @('AppData\Local', 'AppData\Roaming', 'Temp')) {
        $ruta = Join-Path $Perfil $d
        if (-not (Test-Path -LiteralPath $ruta)) { [void](New-Item -ItemType Directory -Path $ruta -Force) }
    }
}

function Start-ALProceso {
    # Lanza un programa en SU PROPIA ventana con unas variables de entorno cambiadas SOLO para el.
    # Las variables se ponen en este proceso un instante (el hijo hereda el entorno al nacer) y se devuelven a su
    # valor enseguida. Nunca se usa setx ni se tocan las variables del sistema o del usuario.
    param([string]$Exe, [string]$Argumentos = '', [string]$Carpeta = '', [System.Collections.IDictionary]$Entorno = @{}, [switch]$Oculto)
    $antes = @{}
    foreach ($k in @($Entorno.Keys)) { $antes[[string]$k] = [System.Environment]::GetEnvironmentVariable([string]$k, 'Process') }
    try {
        foreach ($k in @($Entorno.Keys)) { [System.Environment]::SetEnvironmentVariable([string]$k, [string]$Entorno[$k], 'Process') }
        $p = @{ FilePath = $Exe; PassThru = $true }
        if ($Argumentos) { $p['ArgumentList'] = $Argumentos }
        if ($Carpeta) { $p['WorkingDirectory'] = $Carpeta }
        if ($Oculto) { $p['WindowStyle'] = 'Hidden' }
        $proceso = Start-Process @p
        $null = $proceso.Handle      # sin un asa abierta, el codigo de salida se pierde
        return $proceso
    } finally {
        foreach ($k in @($antes.Keys)) { [System.Environment]::SetEnvironmentVariable([string]$k, $antes[$k], 'Process') }
    }
}

function Get-ALServidorEnMarcha {
    # Devuelve el proceso DedicatedServer.exe que corre desde esa carpeta, o $null. No lo toca.
    param([string]$Destino)
    $exe = (Join-Path $Destino 'DedicatedServer.exe')
    foreach ($p in @(Get-Process -Name 'DedicatedServer' -ErrorAction SilentlyContinue)) {
        try { if ($p.Path -and ($p.Path -ieq $exe)) { return $p } } catch { }
    }
    return $null
}

# --------------------------------------------------------------------------------------------------------------
# Ficheros de configuracion del servidor
# --------------------------------------------------------------------------------------------------------------

function Set-ALAtributoXml {
    # Pone un atributo sin duplicarlo: el juego no distingue mayusculas en los nombres, XML si.
    param($Elemento, [string]$Nombre, [string]$Valor)
    $hecho = $false
    foreach ($a in @($Elemento.Attributes)) {
        if ($a.Name -ieq $Nombre) { $a.Value = $Valor; $hecho = $true }
    }
    if (-not $hecho) { [void]$Elemento.SetAttribute($Nombre, $Valor) }
}

function Get-ALAtributoXml {
    param($Elemento, [string]$Nombre, [string]$Defecto = '')
    foreach ($a in @($Elemento.Attributes)) { if ($a.Name -ieq $Nombre) { return [string]$a.Value } }
    return $Defecto
}

function Save-ALXml {
    param($Doc, [string]$Ruta)
    $aj = New-Object System.Xml.XmlWriterSettings
    $aj.Indent = $true
    $aj.NewLineOnAttributes = $true
    $aj.Encoding = New-Object System.Text.UTF8Encoding($false)
    $w = [System.Xml.XmlWriter]::Create($Ruta, $aj)
    try { $Doc.Save($w) } finally { $w.Close() }
}

function Get-ALNombreServidorDeSemilla {
    # ServerName del serversettings.xml del juego ('' si no hay).
    param([string]$Semilla)
    try {
        if ($Semilla -and (Test-Path -LiteralPath $Semilla -PathType Leaf)) {
            $d = New-Object System.Xml.XmlDocument
            $d.Load($Semilla)
            return (Get-ALAtributoXml $d.DocumentElement 'ServerName' '')
        }
    } catch { }
    return ''
}

function Set-ALAjustesServidorXml {
    # Escribe serversettings.xml en la carpeta del servidor (con el servidor PARADO: al arrancar lo relee y lo reescribe).
    #   -Forzados   se ponen siempre (puerto, nombre, privado, sin autenticacion...)
    #   -Iniciales  solo cuando el fichero se crea de cero
    #   -Semilla    si el fichero no existe, se parte de este (el del juego del dueno, que solo se LEE)
    # El resto de atributos se conserva tal cual. Devuelve @{ Creado; Sembrado; Cambiado; Respaldo }.
    param([string]$Ruta, [System.Collections.IDictionary]$Forzados, [System.Collections.IDictionary]$Iniciales = @{}, [string]$Semilla = '', [string]$CarpetaRespaldo = '')
    $r = @{ Creado = $false; Sembrado = $false; Cambiado = $false; Respaldo = '' }
    $doc = New-Object System.Xml.XmlDocument
    $antes = $null
    if (Test-Path -LiteralPath $Ruta -PathType Leaf) {
        $doc.Load($Ruta)
        $antes = $doc.OuterXml
    } elseif ($Semilla -and (Test-Path -LiteralPath $Semilla -PathType Leaf)) {
        $doc.Load($Semilla)
        $r.Creado = $true; $r.Sembrado = $true
    } else {
        $doc.LoadXml('<serversettings />')
        $r.Creado = $true
        foreach ($k in @($Iniciales.Keys)) { Set-ALAtributoXml $doc.DocumentElement ([string]$k) ([string]$Iniciales[$k]) }
    }
    if ($doc.DocumentElement.Name -ine 'serversettings') { throw ($Ruta + ' no es un serversettings.xml') }
    foreach ($k in @($Forzados.Keys)) { Set-ALAtributoXml $doc.DocumentElement ([string]$k) ([string]$Forzados[$k]) }
    if ($r.Creado -or $doc.OuterXml -ne $antes) {
        if ($null -ne $antes -and $CarpetaRespaldo) {
            if (-not (Test-Path -LiteralPath $CarpetaRespaldo)) { [void](New-Item -ItemType Directory -Path $CarpetaRespaldo -Force) }
            $r.Respaldo = Join-Path $CarpetaRespaldo ('serversettings-' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '.xml')
            [System.IO.File]::Copy($Ruta, $r.Respaldo, $true)
        }
        Save-ALXml $doc $Ruta
        $r.Cambiado = $true
    }
    return $r
}

function Get-ALValoresServidor {
    # Los atributos de serversettings.xml que esta herramienta fija SIEMPRE. Nombres leidos en la 1.13.4
    # (ServerSource\Networking\ServerSettings.cs:267-308 y SharedSource\Networking\ServerSettings.cs).
    param([string]$Nombre, [int]$Puerto, [int]$MaxJugadores, [string]$Contrasena)
    return [ordered]@{
        port                  = [string]$Puerto
        queryport             = [string]($Puerto + 1)     # no se usa en un servidor privado; se deja coherente
        password              = "$Contrasena"
        enableupnp            = 'false'
        ServerName            = $Nombre
        IsPublic              = 'False'                   # nunca en la lista publica
        RequireAuthentication = 'False'                   # entran los que tienen Steam conectado y los que no
        AllowModDownloads     = 'True'                    # el servidor reparte sus mods a quien no los tenga
        AllowFileTransfers    = 'True'
        MaxPlayers            = [string]$MaxJugadores
        SaveServerLogs        = 'True'
    }
}

function Set-ALConfigServidor {
    # config_player.xml de la carpeta del SERVIDOR (no el de tu juego). Solo se usa para decir donde guardar las
    # partidas (savepath). Si no existe y no hace falta, se deja que el servidor lo cree con sus valores de fabrica.
    # Devuelve 'creado', 'cambiado' o 'igual'.
    param([string]$Ruta, [string]$CarpetaPartidas = '')
    $doc = New-Object System.Xml.XmlDocument
    if (-not (Test-Path -LiteralPath $Ruta -PathType Leaf)) {
        if ([string]::IsNullOrWhiteSpace($CarpetaPartidas)) { return 'igual' }
        $doc.LoadXml('<config><contentpackages><corepackage path="Content/ContentPackages/Vanilla.xml" /><regularpackages /></contentpackages></config>')
        Set-ALAtributoXml $doc.DocumentElement 'savepath' $CarpetaPartidas
        Save-ALXml $doc $Ruta
        return 'creado'
    }
    $doc.Load($Ruta)
    $antes = Get-ALAtributoXml $doc.DocumentElement 'savepath' ''
    if ($antes -eq $CarpetaPartidas) { return 'igual' }
    Set-ALAtributoXml $doc.DocumentElement 'savepath' $CarpetaPartidas
    Save-ALXml $doc $Ruta
    return 'cambiado'
}

function Set-ALPermisosAnfitrion {
    # Data\clientpermissions.xml: permisos de administrador para quien entre desde este mismo PC (127.0.0.1).
    # Solo se crea si NO existe; si existe, es del servidor y no se toca. Devuelve $true si lo creo.
    # (Leido en ServerSource\Networking\ServerSettings.cs:479-583; PENDIENTE de medir que la regla por direccion funciona.)
    param([string]$Ruta)
    if (Test-Path -LiteralPath $Ruta -PathType Leaf) { return $false }
    $doc = New-Object System.Xml.XmlDocument
    $doc.LoadXml('<ClientPermissions><Client name="Anfitrion (este PC)" address="127.0.0.1" permissions="All" /></ClientPermissions>')
    $carpeta = Split-Path -Parent $Ruta
    if (-not (Test-Path -LiteralPath $carpeta)) { [void](New-Item -ItemType Directory -Path $carpeta -Force) }
    Save-ALXml $doc $Ruta
    return $true
}

function Get-ALArgumentosServidor {
    # Argumentos de DedicatedServer.exe (leidos en ServerSource\GameMain.cs:182-237). Los argumentos mandan sobre
    # el XML, asi que se repite lo importante: privado, puerto y nombre.
    param([string]$Nombre, [int]$Puerto, [int]$MaxJugadores, [string]$Contrasena = '', [switch]$SaludoTolerante)
    $p = @('-name', ('"' + $Nombre + '"'), '-port', [string]$Puerto, '-queryport', [string]($Puerto + 1), '-public', 'false', '-maxplayers', [string]$MaxJugadores)
    if ([string]::IsNullOrEmpty($Contrasena)) { $p += '-nopassword' } else { $p += @('-password', ('"' + $Contrasena + '"')) }
    if ($SaludoTolerante) { $p += '-lenienthandshake' }
    return ($p -join ' ')
}

# --------------------------------------------------------------------------------------------------------------
# Puerto y cortafuegos (SOLO MIRAR: aqui no se cambia nada)
# --------------------------------------------------------------------------------------------------------------

function Test-ALPuertoUdpLibre {
    # $true libre, $false ocupado, $null no se pudo mirar.
    param([int]$Puerto)
    try {
        foreach ($e in [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveUdpListeners()) {
            if ($e.Port -eq $Puerto) { return $false }
        }
        return $true
    } catch { return $null }
}

function Get-ALDuenoPuertoUdp {
    # Nombre del programa que tiene ese puerto UDP ('' si no se sabe).
    param([int]$Puerto)
    try {
        $e = @(Get-NetUDPEndpoint -LocalPort $Puerto -ErrorAction Stop)
        if ($e.Count -gt 0) {
            $p = Get-Process -Id $e[0].OwningProcess -ErrorAction Stop
            return ('{0} (proceso {1})' -f $p.ProcessName, $p.Id)
        }
    } catch { }
    return ''
}

function Get-ALParametrosRegla {
    # Los datos de LA regla de cortafuegos de esta herramienta: entrada, UDP, ese puerto y ese programa.
    param([int]$Puerto, [string]$Exe, [string]$Alcance = 'cualquiera', [object[]]$Interfaces = @())
    $remotas = @('Any')
    if ($Alcance -eq 'subred') {
        $remotas = @('LocalSubnet')
        foreach ($i in @($Interfaces)) {
            if ($null -ne $i -and (Get-BLTipoDeRed $i.Alias $i.Descripcion $i.Clase $i.Ip) -eq 'tailscale') { $remotas += ($script:BL_RangoTailscale + '/10'); break }
        }
    }
    return [ordered]@{
        DisplayName   = ('Barotrauma LAN - servidor (UDP {0})' -f $Puerto)
        Group         = $script:AL_GrupoCortafuegos
        Description   = 'Deja entrar a los amigos al servidor dedicado de Barotrauma LAN. Se quita con CORTAFUEGOS-QUITAR.'
        Direction     = 'Inbound'
        Action        = 'Allow'
        Protocol      = 'UDP'
        LocalPort     = [string]$Puerto
        Program       = $Exe
        RemoteAddress = $remotas
        Profile       = 'Any'
    }
}

function Get-ALTextoRegla {
    # La orden equivalente, para ensenarla.
    param($Parametros)
    $trozos = @('New-NetFirewallRule')
    foreach ($k in @($Parametros.Keys)) {
        $v = $Parametros[$k]
        if ($v -is [array]) { $trozos += ('-{0} {1}' -f $k, ((@($v) | ForEach-Object { "'" + $_ + "'" }) -join ',')) }
        else { $trozos += ("-{0} '{1}'" -f $k, $v) }
    }
    return ($trozos -join ' ')
}

function Get-ALEstadoCortafuegos {
    # Mira (sin cambiar nada) que reglas de ENTRADA del cortafuegos de Windows afectan a este servidor: las de esta
    # herramienta (grupo "Barotrauma LAN") y cualquier otra puesta para ese programa (por ejemplo las que crea
    # Windows cuando se pulsa "Permitir" o "Cancelar" en su aviso).
    # Devuelve @{ Comprobado; Permiten = @(nombres); Bloquean = @(nombres); Nuestra; CubrePublica; CubrePrivada; Detalle }.
    param([int]$Puerto, [string]$Exe)
    $r = @{ Comprobado = $false; Permiten = @(); Bloquean = @(); Nuestra = $false; CubrePublica = $false; CubrePrivada = $false; Detalle = '' }
    try {
        $vistas = @{}
        $reglas = New-Object System.Collections.ArrayList
        foreach ($regla in @(Get-NetFirewallRule -Group $script:AL_GrupoCortafuegos -ErrorAction SilentlyContinue)) {
            if (-not $vistas.ContainsKey([string]$regla.Name)) { $vistas[[string]$regla.Name] = $true; [void]$reglas.Add($regla) }
        }
        $filtros = @(Get-NetFirewallApplicationFilter -Program $Exe -ErrorAction SilentlyContinue)
        if ($filtros.Count -gt 0) {
            foreach ($regla in @($filtros | Get-NetFirewallRule -ErrorAction SilentlyContinue)) {
                if (-not $vistas.ContainsKey([string]$regla.Name)) { $vistas[[string]$regla.Name] = $true; [void]$reglas.Add($regla) }
            }
        }
        $r.Comprobado = $true
        $permiten = New-Object System.Collections.ArrayList
        $bloquean = New-Object System.Collections.ArrayList
        foreach ($regla in $reglas) {
            if ([string]$regla.Enabled -ne 'True' -or [string]$regla.Direction -ne 'Inbound') { continue }
            $pf = $regla | Get-NetFirewallPortFilter
            $af = $regla | Get-NetFirewallApplicationFilter
            $puertos = @($pf.LocalPort | ForEach-Object { [string]$_ })
            $okProtocolo = (@('UDP', 'Any') -contains [string]$pf.Protocol)
            $okPuerto = ($puertos -contains ([string]$Puerto)) -or ($puertos -contains 'Any')
            $okPrograma = ([string]$af.Program -eq 'Any') -or ([string]$af.Program -ieq $Exe)
            if (-not $okProtocolo) { continue }
            if (-not ($okPuerto -and $okPrograma)) {
                if ([string]$regla.Group -eq $script:AL_GrupoCortafuegos) { $r.Detalle = ('la regla de Barotrauma LAN es para UDP {0} y {1}: ya no coincide' -f ($puertos -join ','), $af.Program) }
                continue
            }
            $perfil = [string]$regla.Profile
            if ([string]$regla.Action -eq 'Block') { [void]$bloquean.Add(('{0} ({1})' -f $regla.DisplayName, $perfil)); continue }
            [void]$permiten.Add(('{0} ({1})' -f $regla.DisplayName, $perfil))
            if ([string]$regla.Group -eq $script:AL_GrupoCortafuegos) { $r.Nuestra = $true }
            if ($perfil -match 'Any|Public') { $r.CubrePublica = $true }
            if ($perfil -match 'Any|Private') { $r.CubrePrivada = $true }
        }
        $r.Permiten = @($permiten)
        $r.Bloquean = @($bloquean)
    } catch { $r.Detalle = $_.Exception.Message }
    return $r
}

function Get-ALPerfilesDeRed {
    # Tabla interfaz -> categoria del cortafuegos (Public / Private / DomainAuthenticated). Solo mira.
    $t = @{}
    try { foreach ($p in @(Get-NetConnectionProfile -ErrorAction Stop)) { $t[[string]$p.InterfaceAlias] = [string]$p.NetworkCategory } } catch { }
    return $t
}

# --------------------------------------------------------------------------------------------------------------
# Paquete para los amigos
# --------------------------------------------------------------------------------------------------------------

function ConvertTo-ALNombreFichero {
    param([string]$Texto)
    $t = $Texto
    foreach ($c in [System.IO.Path]::GetInvalidFileNameChars()) { $t = $t.Replace([string]$c, '_') }
    $t = $t.Trim().TrimEnd('.')
    if ([string]::IsNullOrWhiteSpace($t)) { $t = 'servidor' }
    return $t
}

function New-ALDatosServidor {
    # El contenido de servidor.json: lo UNICO del paquete que cambia de un anfitrion a otro.
    param([string]$Nombre, [int]$Puerto, [string]$Version, [string]$Anfitrion, [string]$Contrasena = '', [bool]$IncluirContrasena = $true,
        [string]$Sonda = 'limpia', [bool]$SaludoTolerante = $true, [object[]]$Direcciones = @())
    $s = [ordered]@{ nombre = $Nombre; puerto = $Puerto; version = $Version; anfitrion = $Anfitrion; tieneContrasena = (-not [string]::IsNullOrEmpty($Contrasena)) }
    if ($IncluirContrasena -and -not [string]::IsNullOrEmpty($Contrasena)) { $s['contrasena'] = $Contrasena }
    $tolerante = 'nunca'
    if ($SaludoTolerante) { $tolerante = 'vpn' }
    return [ordered]@{
        formato         = $script:BL_FormatoDatos
        herramienta     = ('Barotrauma LAN ' + $script:BL_Version)
        generado        = (Get-Date).ToString('yyyy-MM-dd HH:mm')
        servidor        = $s
        sonda           = $Sonda
        saludoTolerante = $tolerante
        direcciones     = @($Direcciones)
    }
}

function New-ALPaqueteAmigo {
    # Crea <Salida>\Barotrauma LAN - <nombre>\ y su .zip con los guiones del amigo y servidor.json. NADA del juego.
    # Devuelve @{ Carpeta; Zip; Ficheros }.
    param([string]$CarpetaAmigo, [string]$Salida, $Datos)
    foreach ($n in $script:AL_FicherosPaquete) {
        if (-not (Test-Path -LiteralPath (Join-Path $CarpetaAmigo $n) -PathType Leaf)) { throw ('falta ' + $n + ' en ' + $CarpetaAmigo) }
    }
    $nombre = 'Barotrauma LAN - ' + (ConvertTo-ALNombreFichero ([string]$Datos.servidor.nombre))
    $carpeta = Join-Path $Salida $nombre
    if (-not (Test-Path -LiteralPath $carpeta)) { [void](New-Item -ItemType Directory -Path $carpeta -Force) }
    foreach ($n in $script:AL_FicherosPaquete) { [System.IO.File]::Copy((Join-Path $CarpetaAmigo $n), (Join-Path $carpeta $n), $true) }
    Write-BLJson (Join-Path $carpeta 'servidor.json') $Datos
    $ficheros = @($script:AL_FicherosPaquete) + @('servidor.json')

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = Join-Path $Salida ($nombre + '.zip')
    $fs = [System.IO.File]::Open($zip, [System.IO.FileMode]::Create)
    try {
        $za = New-Object System.IO.Compression.ZipArchive -ArgumentList $fs, ([System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($n in $ficheros) {
                $entrada = $za.CreateEntry(($nombre + '/' + $n), [System.IO.Compression.CompressionLevel]::Optimal)
                $flujo = $entrada.Open()
                try {
                    $bytes = [System.IO.File]::ReadAllBytes((Join-Path $carpeta $n))
                    $flujo.Write($bytes, 0, $bytes.Length)
                } finally { $flujo.Dispose() }
            }
        } finally { $za.Dispose() }
    } finally { $fs.Dispose() }
    return @{ Carpeta = $carpeta; Zip = $zip; Ficheros = $ficheros }
}
