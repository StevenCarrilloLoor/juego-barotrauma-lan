# ==============================================================================================================
# servidor.ps1  -  Barotrauma LAN 0.1  -  el ANFITRION abre su servidor dedicado
#
# Que hace (-Accion abrir, que es lo que lanza 1-ABRIR-SERVIDOR.bat):
#   1. Lee ajustes-anfitrion.json (si no existe, lo crea con valores de fabrica).
#   2. Encuentra tu Barotrauma y lee su version. Tu instalacion NO se toca: de ahi solo se copia.
#   3. Crea o pone al dia una carpeta de servidor PROPIA (copia de los ficheros sueltos + union a Content).
#      Si el juego se actualizo, la rehace sola y guarda antes lo que el servidor tenia escrito.
#   4. Escribe su serversettings.xml: privado, sin autenticacion (entran los que tienen Steam conectado y los que
#      no), descarga de mods desde el servidor activada, tu puerto, tu nombre y tu contrasena.
#   5. Te ensena las direcciones que dar a tus amigos (red local y cada VPN) y la version exacta del juego.
#   6. Genera el paquete de tus amigos con esas direcciones dentro.
#   7. Mira (sin cambiar nada) si el puerto esta libre y si esta la regla del cortafuegos.
#   8. Arranca DedicatedServer.exe en su propia ventana de consola. Se cierra escribiendo  quit  en ESA ventana.
#
# Otras acciones:   -Accion preparar   todo menos arrancar          -Accion estado   solo mira, no escribe nada
# Para probar:      -EnSeco            con "abrir": lo prepara todo y ENSENA la orden, pero no arranca el servidor
#                   -NoPreguntar       nunca pregunta        -Ajustes <ruta>    otro fichero de ajustes
#                   -CarpetaSalida     donde dejar el paquete (por omision ..\PARA COMPARTIR)
#
# No toca el cortafuegos, ni puertos, ni servicios; no cierra a la fuerza ningun proceso; no pide administrador.
# Codigos de salida: 0 bien | 2 no encuentro el juego | 3 ajustes mal | 4 carpeta de servidor no valida
#                    5 puerto ocupado | 9 error
# ==============================================================================================================
param(
    [ValidateSet('abrir', 'preparar', 'estado')][string]$Accion = 'abrir',
    [switch]$EnSeco,
    [switch]$NoPreguntar,
    [string]$Ajustes = '',
    [string]$CarpetaSalida = '',
    [int]$EsperaArranqueS = 120
)

$ErrorActionPreference = 'Stop'
$AL_Aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$AL_Proyecto = Split-Path -Parent $AL_Aqui
$AL_Amigo = Join-Path $AL_Proyecto 'amigo'
. (Join-Path $AL_Amigo 'barolan-comun.ps1')
. (Join-Path $AL_Aqui 'anfitrion-lib.ps1')

function Decir { param([string]$Texto = '', [string]$Color = '') if ($Color) { Write-Host $Texto -ForegroundColor $Color } else { Write-Host $Texto } }

try {
    $soloMirar = ($Accion -eq 'estado')
    Decir ''
    Decir ('  BAROTRAUMA LAN {0}  -  servidor dedicado' -f $script:BL_Version) 'Cyan'
    if ($soloMirar) { Decir '  ESTADO: solo miro. No escribo ni arranco nada.' 'Yellow' }
    elseif ($EnSeco) { Decir '  MODO EN SECO: lo preparo todo, pero NO arranco el servidor.' 'Yellow' }
    Decir ''

    # ---------------------------------------------------------------------------------- 1. ajustes
    if ([string]::IsNullOrWhiteSpace($Ajustes)) { $Ajustes = Join-Path $AL_Aqui 'ajustes-anfitrion.json' }
    $Ajustes = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Ajustes)
    $leido = Read-ALAjustes -Ruta $Ajustes -Crear:(-not $soloMirar)
    $a = $leido.Ajustes
    if (-not $leido.Existia) {
        if ($soloMirar) { Decir '  [1] Ajustes: todavia no hay ajustes-anfitrion.json; uso los de fabrica.' }
        else {
            Decir ('  [1] Ajustes: he creado ' + $Ajustes) 'Yellow'
            Decir '      con los valores de fabrica. Puedes cambiarlos con el Bloc de notas (nombre, puerto, contrasena...).'
        }
    } else { Decir ('  [1] Ajustes: ' + $Ajustes) }
    $pegas = @(Test-ALAjustes $a)
    if ($pegas.Count -gt 0) {
        Decir '      Hay ajustes que no valen:' 'Red'
        foreach ($p in $pegas) { Decir ('        - ' + $p) 'Red' }
        exit 3
    }

    # ---------------------------------------------------------------------------------- 2. el juego
    $juego = $null
    if (-not [string]::IsNullOrWhiteSpace([string]$a.carpetaJuego)) {
        $c = ConvertTo-BLCarpetaJuego ([string]$a.carpetaJuego)
        if (Test-BLCarpetaJuego $c) { $juego = New-Object psobject -Property @{ Carpeta = $c; Origen = 'ajustes-anfitrion.json' } }
        else { Decir ('  [2] En carpetaJuego (' + $c + ') no esta Barotrauma.') 'Red'; exit 2 }
    } else {
        $juego = Find-BLJuego
    }
    if ($null -eq $juego) {
        Decir '  [2] No encuentro Barotrauma en este PC.' 'Red'
        Decir ('      Escribe su carpeta en "carpetaJuego" dentro de ' + $Ajustes)
        exit 2
    }
    $verCliente = Get-BLVersionJuego $juego.Carpeta
    $verServidor = Get-BLVersionEnsamblado (Join-Path $juego.Carpeta 'DedicatedServer.dll')
    if ($null -eq $verServidor) {
        Decir ('  [2] En ' + $juego.Carpeta + ' no esta el servidor dedicado (DedicatedServer.exe/.dll).') 'Red'
        Decir '      Viene con el juego: en Steam, Propiedades - Archivos instalados - Verificar integridad.'
        exit 2
    }
    Decir ('  [2] Tu juego: ' + $juego.Carpeta + '   (solo lo leo)')
    Decir ('      version ' + $verServidor + '   build de Steam ' + (Get-BLBuildIdSteam $juego.Carpeta))
    if ($null -ne $verCliente -and (Compare-BLVersion $verCliente $verServidor) -ne 'igual') {
        Decir ('      AVISO: el juego dice ' + $verCliente + ' y su servidor ' + $verServidor + '. Instalacion a medias: verifica los archivos en Steam.') 'Yellow'
    }

    # ---------------------------------------------------------------------------------- 3. carpeta del servidor
    $raiz = Get-ALRaizServidor $a $juego.Carpeta
    $pega = Test-ALRaizSegura $raiz $juego.Carpeta
    if ($pega) { Decir ('  [3] La carpeta del servidor (' + $raiz + ') no vale: ' + $pega + '.') 'Red'; exit 4 }
    $destino = Join-Path $raiz 'servidor'
    $exeServidor = Join-Path $destino 'DedicatedServer.exe'
    $enMarcha = Get-ALServidorEnMarcha $destino

    $noCopiar = @()
    if ($a.identidad -eq 'por-nombre') { $noCopiar = @($a.recetaPorNombre) }

    if ($null -ne $enMarcha) {
        Decir ('  [3] El servidor YA ESTA ABIERTO (proceso ' + $enMarcha.Id + '). No toco su carpeta.') 'Yellow'
        $sync = Sync-ALCarpetaServidor -CarpetaJuego $juego.Carpeta -Raiz $raiz -NoCopiar $noCopiar -SoloMirar
    } else {
        $sync = Sync-ALCarpetaServidor -CarpetaJuego $juego.Carpeta -Raiz $raiz -NoCopiar $noCopiar -SoloMirar:$soloMirar
        if ($soloMirar) {
            if ($sync.Nuevo) { Decir ('  [3] Carpeta del servidor: ' + $destino + '  (todavia no existe; se creara al abrir)') }
            elseif ($sync.Actualizado) { Decir ('  [3] Carpeta del servidor: ' + $destino + '  DESFASADA: es de la ' + $sync.VersionAntes + ' y el juego va por la ' + $sync.VersionAhora) 'Yellow' }
            elseif ($sync.Pendientes -gt 0 -or $sync.Union -ne 'estaba') { Decir ('  [3] Carpeta del servidor: ' + $destino + '  (le faltan ' + $sync.Pendientes + ' ficheros por poner al dia)') 'Yellow' }
            else { Decir ('  [3] Carpeta del servidor: ' + $destino + '  al dia (' + $sync.VersionAhora + ')') }
        } else {
            if ($sync.Nuevo) { Decir ('  [3] Carpeta del servidor CREADA: ' + $destino + '  (' + $sync.Copiados + ' ficheros copiados + union a Content)') 'Green' }
            elseif ($sync.Actualizado) {
                Decir ('  [3] EL JUEGO SE ACTUALIZO (' + $sync.VersionAntes + ' -> ' + $sync.VersionAhora + '). Carpeta del servidor REHECHA: ' + $sync.Copiados + ' copiados, ' + $sync.Borrados + ' quitados.') 'Yellow'
                Decir ('      Lo que el servidor tenia escrito esta guardado en ' + $sync.Respaldo)
                Decir '      OJO: tus amigos tienen que actualizar tambien su juego, y hay que mandarles el paquete nuevo.' 'Yellow'
            }
            elseif ($sync.Copiados -gt 0 -or $sync.Borrados -gt 0) { Decir ('  [3] Carpeta del servidor puesta al dia: ' + $destino + '  (' + $sync.Copiados + ' copiados, ' + $sync.Borrados + ' quitados)') }
            else { Decir ('  [3] Carpeta del servidor: ' + $destino + '  al dia (' + $sync.VersionAhora + ')') }
        }
    }

    # ---------------------------------------------------------------------------------- 4. configuracion
    $semilla = ''
    if ($a.importarAjustesDeMiJuego) { $semilla = Join-Path $juego.Carpeta 'serversettings.xml' }
    $nombre = [string]$a.nombreServidor
    $rutaXml = Join-Path $destino 'serversettings.xml'
    if ([string]::IsNullOrWhiteSpace($nombre)) {
        if (Test-Path -LiteralPath $rutaXml -PathType Leaf) { $nombre = Get-ALNombreServidorDeSemilla $rutaXml }
        if ([string]::IsNullOrWhiteSpace($nombre) -and $semilla) { $nombre = Get-ALNombreServidorDeSemilla $semilla }
        if ([string]::IsNullOrWhiteSpace($nombre) -or (Test-BLNombreServidor $nombre)) { $nombre = 'Barotrauma LAN' }
    }
    # Datos del servidor: por omision, PROPIOS (perfil y partidas dentro de su carpeta; lo tuyo no se toca).
    $carpetaPartidas = ''
    $perfil = ''
    $entorno = [ordered]@{}
    if ($a.datos -eq 'propios') {
        $carpetaPartidas = Join-Path $raiz 'partidas'
        if ([string]::IsNullOrWhiteSpace([string]$a.carpetaPerfil)) { $perfil = Join-Path $raiz 'perfil' } else { $perfil = ConvertTo-ALRutaLimpia ([string]$a.carpetaPerfil) }
        $pegaPerfil = Test-ALRaizSegura $perfil $juego.Carpeta
        if ($pegaPerfil) { Decir ('  [4] La carpeta del perfil del servidor (' + $perfil + ') no vale: ' + $pegaPerfil + '.') 'Red'; exit 4 }
        $entorno = Get-ALEntornoServidor $perfil
    }

    if ($soloMirar -or $null -ne $enMarcha) {
        Decir ('  [4] Servidor "' + $nombre + '", puerto UDP ' + $a.puerto + ', hasta ' + $a.maxJugadores + ' jugadores.')
    } else {
        $valores = Get-ALValoresServidor -Nombre $nombre -Puerto $a.puerto -MaxJugadores $a.maxJugadores -Contrasena ([string]$a.contrasena)
        $xml = Set-ALAjustesServidorXml -Ruta $rutaXml -Forzados $valores -Iniciales @{ BanAfterWrongPassword = 'False' } -Semilla $semilla -CarpetaRespaldo (Join-Path $raiz 'respaldos')
        Decir ('  [4] Servidor "' + $nombre + '", puerto UDP ' + $a.puerto + ', hasta ' + $a.maxJugadores + ' jugadores. Privado, sin autenticacion, mods desde el servidor.')
        if ($xml.Sembrado) { Decir '      Primera vez: he copiado tus ajustes de partida de tu juego (submarino, modo, reaparicion...).' }
        elseif ($xml.Cambiado -and $xml.Respaldo) { Decir ('      serversettings.xml cambiado; el anterior esta en ' + $xml.Respaldo) }
        if ($carpetaPartidas -and -not (Test-Path -LiteralPath $carpetaPartidas)) { [void](New-Item -ItemType Directory -Path $carpetaPartidas -Force) }
        if ($perfil) { Initialize-ALPerfil $perfil }
        [void](Set-ALConfigServidor -Ruta (Join-Path $destino 'config_player.xml') -CarpetaPartidas $carpetaPartidas)
        if ($a.anfitrionAdministraDesdeEstePC) {
            if (Set-ALPermisosAnfitrion (Join-Path $destino 'Data\clientpermissions.xml')) { Decir '      Permisos: quien entre desde este mismo PC (127.0.0.1) administra el servidor.' }
        }
    }
    if ($perfil) {
        Decir ('      Datos del servidor PROPIOS: partidas en ' + $carpetaPartidas)
        Decir ('      y su carpeta de datos en ' + $perfil + '. Tus partidas y tus mods de Steam no se tocan.')
    } else {
        Decir '      Datos del servidor: LOS DE TU JUEGO (tu carpeta de datos de Barotrauma, la que sincroniza Steam).' 'Yellow'
        Decir '      OJO (leido en el codigo): el juego BORRA de ahi los mods del Workshop que le fallen al cargar.' 'Yellow'
    }
    if ($a.contrasena) { Decir '      Con contrasena: el juego se la pide a cada amigo al entrar (no se puede pasar sola).' }

    # Identidad: como reconoce el servidor a cada jugador.
    if ($a.identidad -eq 'por-nombre') {
        Decir ('      IDENTIDAD por nombre para todos. RECETA SIN MEDIR: la carpeta del servidor va sin ' + (@($a.recetaPorNombre) -join ', ') + '.') 'Yellow'
    } elseif ($a.identidad -eq 'pendiente') {
        Decir '      IDENTIDAD: pendiente de decidir (se comporta como "steam-si-lo-hay"). Quien entre un dia con Steam' 'DarkGray'
        Decir '      conectado y otro sin el sera DOS jugadores distintos para la campana. Ver LEEME.txt.' 'DarkGray'
    }

    # ---------------------------------------------------------------------------------- 5. direcciones
    $interfaces = @(Get-BLInterfaces)
    $direcciones = @(Get-BLDireccionesServidor -Interfaces $interfaces -Orden @($a.ordenRedes) -Excluidas @($a.redesExcluidas) -Internet ([string]$a.direccionInternet) -PuertoInternet $a.puertoInternet)
    $perfiles = Get-ALPerfilesDeRed
    Decir ''
    Decir ('  [5] DIRECCIONES PARA TUS AMIGOS   (servidor "' + $nombre + '", juego ' + $sync.VersionAhora + ', puerto UDP ' + $a.puerto + ')') 'Cyan'
    if ($direcciones.Count -eq 0) {
        Decir '        NINGUNA: este PC no tiene red local ni VPN conectada. Conecta la red o la VPN y vuelve a abrir esto.' 'Red'
    }
    foreach ($d in $direcciones) {
        $nota = ''
        if ($d.interfaz -and $perfiles.ContainsKey($d.interfaz)) {
            if ($perfiles[$d.interfaz] -eq 'Public') { $nota = '(' + $d.interfaz + ', red marcada como Publica en Windows)' } else { $nota = '(' + $d.interfaz + ')' }
        } elseif ($d.interfaz) { $nota = '(' + $d.interfaz + ')' }
        if ($d.tipo -eq 'internet') { $nota = '(puesta a mano; necesita el puerto UDP redirigido en tu router)' }
        Decir ('        {0,-17} {1,-18} {2}' -f $d.etiqueta, $d.direccion, $nota)
    }
    Decir ('      A mano, dentro del juego: Unirse a un servidor y escribir la direccion con el puerto, por ejemplo  ' + $(if ($direcciones.Count -gt 0) { $direcciones[0].direccion } else { '10.0.0.5' }) + ':' + $a.puerto) 'DarkGray'

    # ---------------------------------------------------------------------------------- 6. paquete del amigo
    $datos = New-ALDatosServidor -Nombre $nombre -Puerto $a.puerto -Version $sync.VersionAhora -Anfitrion ([string]$a.nombreAnfitrion) -Contrasena ([string]$a.contrasena) `
        -IncluirContrasena ([bool]$a.contrasenaEnElPaquete) -Sonda ([string]$a.sonda) -SaludoTolerante ([bool]$a.saludoTolerante) -Direcciones $direcciones
    if ([string]::IsNullOrWhiteSpace($CarpetaSalida)) { $CarpetaSalida = Join-Path $AL_Proyecto 'PARA COMPARTIR' }
    Decir ''
    if ($soloMirar) {
        Decir ('  [6] Paquete para tus amigos: se generara en ' + $CarpetaSalida)
    } else {
        # Copia de los datos para 2-JUGAR-YO.bat: junto al fichero de ajustes (por omision, esta misma carpeta).
        Write-BLJson (Join-Path (Split-Path -Parent $Ajustes) 'servidor-actual.json') $datos
    }
    if ($soloMirar) {
        # nada mas que hacer aqui
    } elseif ($direcciones.Count -eq 0) {
        Decir '  [6] No genero el paquete de tus amigos: no hay ninguna direccion que darles.' 'Yellow'
    } else {
        if (-not (Test-Path -LiteralPath $CarpetaSalida)) { [void](New-Item -ItemType Directory -Path $CarpetaSalida -Force) }
        $paquete = New-ALPaqueteAmigo -CarpetaAmigo $AL_Amigo -Salida $CarpetaSalida -Datos $datos
        Decir '  [6] PAQUETE PARA TUS AMIGOS (mandales este .zip por Discord o en un USB):' 'Cyan'
        Decir ('        ' + $paquete.Zip) 'Green'
        Decir '      Lleva solo los guiones y las direcciones de arriba; nada del juego. Si cambian tus direcciones o la'
        Decir '      version del juego, mandales el nuevo. Ellos: extraer la carpeta y doble clic en JUGAR-BAROTRAUMA-LAN.bat'
        Decir ('PAQUETE: ' + $paquete.Zip) 'DarkGray'
    }

    # ---------------------------------------------------------------------------------- 7. puerto y cortafuegos
    Decir ''
    $libre = Test-ALPuertoUdpLibre $a.puerto
    if ($null -ne $enMarcha) { Decir ('  [7] Puerto UDP ' + $a.puerto + ': lo tiene tu servidor, que ya esta abierto.') }
    elseif ($libre -eq $false) {
        $quien = Get-ALDuenoPuertoUdp $a.puerto
        Decir ('  [7] EL PUERTO UDP ' + $a.puerto + ' ESTA OCUPADO' + $(if ($quien) { ' por ' + $quien } else { '' }) + '.') 'Red'
        Decir ('      Cierra ese programa o cambia "puerto" en ' + $Ajustes + ' (y vuelve a mandar el paquete a tus amigos).')
        if (-not $soloMirar -and -not $EnSeco -and $Accion -eq 'abrir') { exit 5 }
    } elseif ($null -eq $libre) { Decir ('  [7] Puerto UDP ' + $a.puerto + ': no he podido mirar si esta libre.') 'Yellow' }
    else { Decir ('  [7] Puerto UDP ' + $a.puerto + ': libre.') }

    $cf = Get-ALEstadoCortafuegos -Puerto $a.puerto -Exe $exeServidor
    $hayPublicas = $false
    foreach ($d in $direcciones) { if ($d.interfaz -and $perfiles.ContainsKey($d.interfaz) -and $perfiles[$d.interfaz] -eq 'Public') { $hayPublicas = $true } }
    if (-not $cf.Comprobado) {
        Decir '      Cortafuegos: no he podido mirarlo. Si tus amigos no entran, abre CORTAFUEGOS-ABRIR-como-administrador.bat' 'Yellow'
    } elseif (@($cf.Permiten).Count -gt 0 -and ($cf.CubrePublica -or -not $hayPublicas)) {
        Decir ('      Cortafuegos: hay regla que deja entrar a este servidor: ' + (@($cf.Permiten) -join '; ')) 'Green'
    } elseif (@($cf.Permiten).Count -gt 0) {
        Decir ('      CORTAFUEGOS: la regla que hay (' + (@($cf.Permiten) -join '; ') + ') NO vale para redes marcadas como Publicas,') 'Yellow'
        Decir '      y alguna de tus redes de arriba lo esta. Por ahi tus amigos NO entran y no sale ningun aviso.' 'Yellow'
        Decir '      Clic derecho en  CORTAFUEGOS-ABRIR-como-administrador.bat  - Ejecutar como administrador.' 'Yellow'
    } else {
        Decir '      CORTAFUEGOS: FALTA la regla de entrada. Sin ella tus amigos NO entran y no sale ningun aviso.' 'Yellow'
        if ($cf.Detalle) { Decir ('      (' + $cf.Detalle + ')') 'Yellow' }
        Decir '      Una sola vez: clic derecho en  CORTAFUEGOS-ABRIR-como-administrador.bat  - Ejecutar como administrador.' 'Yellow'
        Decir '      (Para jugar tu solo desde este PC no hace falta.)'
    }
    foreach ($b in @($cf.Bloquean)) {
        Decir ('      OJO: Windows tiene una regla que BLOQUEA este servidor: ' + $b + '. Gana a la que permite.') 'Red'
        Decir '      Suele crearse al pulsar Cancelar en el aviso del cortafuegos. Quitala en "Firewall de Windows con seguridad avanzada".' 'Red'
    }

    # ---------------------------------------------------------------------------------- 8. arrancar
    $argumentos = Get-ALArgumentosServidor -Nombre $nombre -Puerto $a.puerto -MaxJugadores $a.maxJugadores -Contrasena ([string]$a.contrasena) -SaludoTolerante:([bool]$a.saludoTolerante)
    $lineasEntorno = @($entorno.Keys | ForEach-Object { 'ENTORNO: ' + $_ + '=' + $entorno[$_] })
    Decir ''
    if ($Accion -ne 'abrir') {
        Decir ('  [8] No arranco el servidor (accion "' + $Accion + '"). La orden seria:')
        foreach ($l in $lineasEntorno) { Decir $l }
        Decir ('ORDEN: "' + $exeServidor + '" ' + $argumentos)
        exit 0
    }
    if ($null -ne $enMarcha) {
        Decir '  [8] El servidor ya estaba abierto: no arranco otro. Para cerrarlo, escribe  quit  en SU ventana.' 'Yellow'
        exit 0
    }
    if ($EnSeco) {
        Decir '  [8] EN SECO. Esta es la orden que lanzaria, con estas variables solo para ese proceso (no la lanzo):' 'Yellow'
        foreach ($l in $lineasEntorno) { Decir $l }
        Decir ('ORDEN: "' + $exeServidor + '" ' + $argumentos)
        exit 0
    }
    Decir '  [8] Arrancando el servidor en SU PROPIA VENTANA...' 'Green'
    Decir '      - Para CERRARLO: escribe  quit  y pulsa Intro en la ventana del servidor (no la cierres con la X).'
    Decir '      - Si Windows pregunta por el cortafuegos: pulsa PERMITIR (marcando redes privadas Y publicas).'
    Decir '        NO pulses Cancelar: Windows crearia una regla que BLOQUEA el servidor.'
    $proceso = Start-ALProceso -Exe $exeServidor -Argumentos $argumentos -Carpeta $destino -Entorno $entorno
    Decir ('      Proceso ' + $proceso.Id + '. Esperando a que escuche en UDP ' + $a.puerto + ' (carga todo el contenido: puede tardar)...')
    $reloj = [System.Diagnostics.Stopwatch]::StartNew()
    $escucha = $false
    while ($reloj.Elapsed.TotalSeconds -lt $EsperaArranqueS) {
        if ($proceso.HasExited) { break }
        if ((Test-ALPuertoUdpLibre $a.puerto) -eq $false) { $escucha = $true; break }
        Start-Sleep -Milliseconds 500
    }
    if ($proceso.HasExited) {
        Decir ('      EL SERVIDOR SE HA CERRADO SOLO (codigo ' + $proceso.ExitCode + '). Mira ' + $destino + '\servercrashreport.log si existe.') 'Red'
        exit 9
    }
    if (-not $escucha) {
        Decir ('      A los ' + $EsperaArranqueS + ' s todavia no escucha. Mira su ventana: puede seguir cargando.') 'Yellow'
        exit 0
    }
    Decir ('      El servidor ESCUCHA en UDP ' + $a.puerto + ' (' + [int]$reloj.Elapsed.TotalSeconds + ' s).') 'Green'
    if ($a.sonda -eq 'limpia') {
        # A 127.0.0.1 no hay riesgo: el servidor no puede vetar la direccion de bucle local.
        $s = @(Invoke-BLSonda -Modo limpia -Destinos @(@{ direccion = '127.0.0.1'; puerto = $a.puerto }) -EsperaMs 600 -Intentos 3)
        if ($s[0].Estado -eq 'contesta') { Decir ('      Y CONTESTA a la sonda (' + $s[0].Ms + ' ms): tus amigos lo veran igual si les llega la red.') 'Green' }
        else { Decir ('      Pero NO contesta a la sonda (' + $s[0].Estado + '). Los lanzadores de tus amigos diran "no contesta" aunque puedan entrar: avisa.') 'Yellow' }
    }
    Decir ''
    Decir '  LISTO. Ahora: manda el .zip a tus amigos y, para jugar tu, abre  2-JUGAR-YO.bat' 'Cyan'
    exit 0
} catch {
    Decir ''
    Decir ('  Ha fallado algo: ' + $_.Exception.Message) 'Red'
    Decir ('  (' + $_.InvocationInfo.ScriptName + ', linea ' + $_.InvocationInfo.ScriptLineNumber + ')') 'DarkGray'
    exit 9
}
