# ==============================================================================================================
# jugar.ps1  -  Barotrauma LAN 0.1  -  lanzador del amigo (y del anfitrion cuando juega en su propio PC)
#
# Que hace, en orden:
#   1. Encuentra tu Barotrauma (registro de Steam y bibliotecas; si no, te lo pregunta UNA vez y lo recuerda).
#   2. Compara la version de tu juego con la del servidor. Si no coinciden NO abre el juego (no entrarias).
#   3. Te pide tu nombre de jugador UNA vez y lo recuerda (usa siempre el mismo: tu personaje va con el nombre).
#   4. Prueba las direcciones del servidor por orden (red local, luego cada VPN) y se queda con la primera que contesta.
#   5. Abre el juego ya conectando.
#
# No instala nada, no pide administrador, no sale a internet y no escribe en la carpeta del juego.
# Lo unico que guarda es  %APPDATA%\BarotraumaLAN\jugador.json  (tu nombre y donde esta tu juego).
#
# Parametros para probar (los usan las pruebas y el laboratorio):
#   -EnSeco          ensena la orden que lanzaria y NO abre el juego
#   -NoPreguntar     nunca pregunta nada: si le falta un dato, termina con un codigo de salida
#   -Local           el anfitrion en su PC: prueba primero 127.0.0.1
#   -DatosServidor   ruta de servidor.json (por omision, el que esta junto a este fichero)
#   -CarpetaDatos    donde recordar nombre y carpeta (por omision %APPDATA%\BarotraumaLAN)
#   -CarpetaJuego    carpeta del juego (no la busca)        -Jugador   nombre (no lo pregunta ni lo guarda)
#   -Sonda           limpia | ping | ninguna (por omision, la que diga servidor.json)
#   -Forzar <ip>     entra por esa direccion sin sondear    -EsperaMs  espera de cada intento de la sonda
#   -IgnorarVersion  SOLO LABORATORIO. Un cliente de otra version puede acabar con su IP vetada en el servidor.
#   -PermitirBucle   SOLO PRUEBAS Y LABORATORIO. No descarta las direcciones 127.x de servidor.json.
#
# Codigos de salida: 0 bien | 2 no encuentro el juego | 3 version distinta | 4 no contesta ninguna direccion
#                    5 servidor.json falta o esta mal | 6 falta el nombre | 7 el juego ya esta abierto | 9 error
# ==============================================================================================================
param(
    [switch]$EnSeco,
    [switch]$NoPreguntar,
    [switch]$Local,
    [string]$DatosServidor = '',
    [string]$CarpetaDatos = '',
    [string]$CarpetaJuego = '',
    [string]$Jugador = '',
    [ValidateSet('', 'limpia', 'ping', 'ninguna')][string]$Sonda = '',
    [string]$Forzar = '',
    [int]$EsperaMs = 450,
    [switch]$IgnorarVersion,
    [switch]$PermitirBucle
)

$ErrorActionPreference = 'Stop'
$BL_Aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $BL_Aqui 'barolan-comun.ps1')

function Decir { param([string]$Texto = '', [string]$Color = '') if ($Color) { Write-Host $Texto -ForegroundColor $Color } else { Write-Host $Texto } }

function Buscar-Servidor {
    # Sondea las candidatas y les pone Estado, Detalle, Ms y Ping. Devuelve el indice de la elegida o -1.
    param([object[]]$Candidatas, [string]$Modo, [int]$Espera)
    $resultados = @(Invoke-BLSonda -Modo $Modo -Destinos $Candidatas -EsperaMs $Espera -Intentos 2)
    for ($i = 0; $i -lt $Candidatas.Count; $i++) {
        $Candidatas[$i].Estado = $resultados[$i].Estado
        $Candidatas[$i].Detalle = $resultados[$i].Detalle
        $Candidatas[$i].Ms = $resultados[$i].Ms
    }
    return (Select-BLDestino $Candidatas)
}

function Ensenar-Candidatas {
    param([object[]]$Candidatas)
    foreach ($c in $Candidatas) {
        $donde = ('{0}:{1}' -f $c.Direccion, $c.Puerto)
        $texto = 'no contesta'
        $color = 'DarkGray'
        if ($c.Estado -eq 'contesta') {
            $texto = 'CONTESTA'; $color = 'Green'
            if ($c.Ms -ge 0) { $texto = ('CONTESTA ({0} ms)' -f $c.Ms) }
        }
        elseif ($c.Estado -eq 'puerto-cerrado') { $texto = 'el PC esta, el servidor no'; $color = 'Yellow' }
        elseif ($c.Estado -eq 'sin-sondear') { $texto = 'sin probar'; if ($c.EnMiRed -eq $true) { $texto = 'sin probar (tienes esa red)' } }
        elseif ($c.Estado -eq 'raro') { $texto = ('respuesta rara: ' + $c.Detalle); $color = 'Yellow' }
        elseif ($c.Estado -eq 'error') { $texto = ('error: ' + $c.Detalle); $color = 'Yellow' }
        elseif ($c.EnMiRed -eq $false) { $texto = 'no tienes esa red' }
        Decir ('        {0,-17} {1,-22} {2}' -f $c.Etiqueta, $donde, $texto) $color
    }
}

try {
    Decir ''
    # ---------------------------------------------------------------------------------- datos del servidor
    if ([string]::IsNullOrWhiteSpace($DatosServidor)) { $DatosServidor = Join-Path $BL_Aqui 'servidor.json' }
    $srv = Read-BLDatosServidor -Ruta $DatosServidor -PermitirBucle:$PermitirBucle -PermitirVacio:$Local
    if (-not $srv.Ok) {
        Decir ('  No puedo empezar: ' + $srv.Error + '.') 'Red'
        Decir '  Pidele al anfitrion que te mande otra vez la carpeta entera (trae un fichero servidor.json).'
        exit 5
    }
    $verServidor = ConvertTo-BLVersion $srv.Version
    Decir ('  BAROTRAUMA LAN {0}  -  servidor "{1}" de {2}  (juego {3})' -f $script:BL_Version, $srv.Nombre, $srv.Anfitrion, $srv.Version) 'Cyan'
    if ($EnSeco) { Decir '  MODO EN SECO: lo compruebo todo, pero NO abro el juego.' 'Yellow' }
    Decir ''

    $recordado = Read-BLDatosJugador $CarpetaDatos

    # ---------------------------------------------------------------------------------- 1. el juego
    $carpeta = ''
    $origen = ''
    if (-not [string]::IsNullOrWhiteSpace($CarpetaJuego)) {
        $carpeta = ConvertTo-BLCarpetaJuego $CarpetaJuego
        $origen = 'la que me has pasado'
        if (-not (Test-BLCarpetaJuego $carpeta)) {
            Decir ('  [1/4] En ' + $carpeta + ' no esta Barotrauma (falta Barotrauma.exe o su carpeta Content).') 'Red'
            exit 2
        }
    } else {
        $encontrado = Find-BLJuego -Recordada $recordado.CarpetaJuego
        if ($null -ne $encontrado) { $carpeta = $encontrado.Carpeta; $origen = $encontrado.Origen }
        while ([string]::IsNullOrEmpty($carpeta)) {
            if ($NoPreguntar) { Decir '  [1/4] No encuentro Barotrauma en este PC.' 'Red'; exit 2 }
            Decir '  [1/4] No encuentro Barotrauma en este PC.' 'Yellow'
            Decir '        Abre la carpeta donde lo tienes instalado, ARRASTRA aqui el fichero Barotrauma.exe y pulsa Intro.'
            Decir '        (En Steam: clic derecho en Barotrauma - Administrar - Ver archivos locales.)  Intro sin nada = salir.'
            $respuesta = Read-Host '        Carpeta'
            if ([string]::IsNullOrWhiteSpace($respuesta)) { exit 2 }
            $posible = ConvertTo-BLCarpetaJuego $respuesta
            if (Test-BLCarpetaJuego $posible) { $carpeta = $posible; $origen = 'la que me acabas de decir' }
            else { Decir ('        Ahi no esta el juego: ' + $posible) 'Yellow' }
        }
    }
    $verMia = Get-BLVersionJuego $carpeta
    $verTexto = 'desconocida'
    if ($null -ne $verMia) { $verTexto = $verMia.ToString() }
    Decir ('  [1/4] Tu juego: ' + $carpeta)
    Decir ('        version ' + $verTexto + '   (encontrado por ' + $origen + ')')

    # ---------------------------------------------------------------------------------- 2. la version
    $comparacion = Compare-BLVersion $verMia $verServidor
    if ($comparacion -ne 'igual') {
        if ($IgnorarVersion) {
            Decir ('        AVISO: version distinta de la del servidor (' + $srv.Version + '). Sigo porque lo has pedido (-IgnorarVersion).') 'Yellow'
        } else {
            Decir ''
            Decir '  NO SE PUEDE ENTRAR: tu juego y el servidor no tienen la misma version.' 'Red'
            Decir ('        Tu juego:  ' + $verTexto)
            Decir ('        Servidor:  ' + $srv.Version)
            if ($comparacion -eq 'mia-mas-vieja') {
                Decir '        Tu juego es mas VIEJO: actualizalo en Steam (necesitas internet) y vuelve a abrir esto.'
                Decir ('        Si no puedes actualizar, dile a ' + $srv.Anfitrion + ' que su servidor va por delante del tuyo.')
            } elseif ($comparacion -eq 'mia-mas-nueva') {
                Decir ('        Tu juego es mas NUEVO: es ' + $srv.Anfitrion + ' quien tiene que actualizar el suyo y volver a abrir el servidor.')
            } else {
                Decir '        No he podido leer la version de tu juego. En Steam: Propiedades - Archivos instalados - Verificar integridad.'
            }
            Decir '        No abro el juego: con versiones distintas el servidor te rechaza.'
            exit 3
        }
    }
    $verContenido = Get-BLVersionContenido $carpeta
    if ($null -ne $verContenido -and $null -ne $verMia -and (Compare-BLVersion $verContenido $verMia) -ne 'igual') {
        Decir ('        AVISO: el contenido de tu juego dice ' + $verContenido + ' y el programa ' + $verTexto + '. Parece una actualizacion a medias:') 'Yellow'
        Decir '        si no te deja entrar, en Steam: Propiedades - Archivos instalados - Verificar integridad.' 'Yellow'
    }

    # ---------------------------------------------------------------------------------- 3. el nombre
    $nombre = ''
    $guardarNombre = $false
    if (-not [string]::IsNullOrWhiteSpace($Jugador)) {
        $nombre = $Jugador.Trim()
        $pega = Test-BLNombreJugador $nombre
        if ($pega) { Decir ('  [2/4] El nombre "' + $nombre + '" no vale: ' + $pega + '.') 'Red'; exit 6 }
    } else {
        $nombre = $recordado.Jugador
        if ((Test-BLNombreJugador $nombre) -ne '') { $nombre = '' }
        while ([string]::IsNullOrEmpty($nombre)) {
            if ($NoPreguntar) { Decir '  [2/4] Falta tu nombre de jugador.' 'Red'; exit 6 }
            Decir '  [2/4] Como te vas a llamar en la partida? (letras, numeros y espacios; maximo 32)'
            Decir '        Usa SIEMPRE el mismo: tu personaje y tus permisos van con el nombre, tal cual lo escribas.'
            $respuesta = Read-Host '        Nombre'
            if ([string]::IsNullOrWhiteSpace($respuesta)) { exit 6 }
            $pega = Test-BLNombreJugador $respuesta
            if ($pega) { Decir ('        Ese nombre no vale: ' + $pega + '.') 'Yellow' }
            else { $nombre = $respuesta.Trim(); $guardarNombre = $true }
        }
    }
    Decir ('  [2/4] Tu nombre en la partida: ' + $nombre)

    if ([string]::IsNullOrWhiteSpace($CarpetaJuego) -and [string]::IsNullOrWhiteSpace($Jugador)) {
        if ($guardarNombre -or $recordado.CarpetaJuego -ne $carpeta) {
            if (-not (Save-BLDatosJugador -Carpeta $CarpetaDatos -Jugador $nombre -CarpetaJuego $carpeta)) {
                Decir '        (No he podido guardar tus datos; la proxima vez te lo volvere a preguntar.)' 'DarkGray'
            }
        }
    }

    # ---------------------------------------------------------------------------------- 4. el servidor
    $modo = $srv.Sonda
    if ($Sonda) { $modo = $Sonda }
    $misRedes = @(Get-BLInterfaces)
    $candidatas = New-Object System.Collections.ArrayList
    if ($Local) {
        [void]$candidatas.Add((New-Object psobject -Property @{ Red = 'local'; Tipo = 'local'; Direccion = '127.0.0.1'; Puerto = $srv.Puerto; Etiqueta = 'Este mismo PC'
                    Prefijo = 8; EnMiRed = $true; Estado = ''; Detalle = ''; Ms = -1; Ping = $false }))
    }
    foreach ($d in $srv.Direcciones) {
        $ip = $d.direccion
        if ($d.tipo -eq 'internet' -and -not (Test-BLIpLiteral $ip)) {
            # El juego no resuelve nombres por la linea de ordenes: lo hago yo.
            $resuelta = Resolve-BLDireccion $ip
            if ($null -eq $resuelta) { Decir ('        No puedo resolver el nombre ' + $ip + ' (sin internet?). Lo salto.') 'DarkGray'; continue }
            $ip = $resuelta
        }
        $c = New-Object psobject -Property @{ Red = $d.red; Tipo = $d.tipo; Direccion = $ip; Puerto = $d.puerto; Etiqueta = $d.etiqueta
            Prefijo = $d.prefijo; EnMiRed = $null; Estado = ''; Detalle = ''; Ms = -1; Ping = $false }
        $c.EnMiRed = Test-BLTengoEsaRed @{ red = $d.red; direccion = $ip; prefijo = $d.prefijo } $misRedes
        [void]$candidatas.Add($c)
    }
    $candidatas = @($candidatas)

    $elegida = $null
    if (-not [string]::IsNullOrWhiteSpace($Forzar)) {
        if (-not (Test-BLIpLiteral $Forzar)) { Decir ('  -Forzar necesita una IP, no "' + $Forzar + '".') 'Red'; exit 9 }
        $elegida = New-Object psobject -Property @{ Red = 'forzada'; Tipo = 'vpn'; Direccion = $Forzar.Trim(); Puerto = $srv.Puerto; Etiqueta = 'Forzada' }
        foreach ($c in $candidatas) { if ($c.Direccion -eq $elegida.Direccion) { $elegida = $c } }
        Decir ('  [3/4] Direccion forzada, sin probar: ' + $elegida.Direccion + ':' + $elegida.Puerto)
    } else {
        while ($null -eq $elegida) {
            if ($modo -eq 'ninguna') { Decir '  [3/4] Direcciones del servidor (sonda apagada: no se prueba ninguna):' }
            else { Decir '  [3/4] Buscando el servidor...' }
            $indice = Buscar-Servidor -Candidatas $candidatas -Modo $modo -Espera $EsperaMs
            Ensenar-Candidatas $candidatas
            if ($indice -ge 0) { $elegida = $candidatas[$indice]; break }

            # Ninguna contesta: diagnostico y, si hay alguien delante, elegir a mano.
            Decir ''
            if ($modo -eq 'ninguna') { Decir '  No se cual usar: este PC no esta en ninguna de esas redes.' 'Yellow' }
            else { Decir '  NO CONTESTA NINGUNA DIRECCION.' 'Yellow' }
            if ($modo -eq 'limpia') {
                $pings = Invoke-BLPing -Direcciones @($candidatas | ForEach-Object { $_.Direccion }) -EsperaMs 600
                foreach ($c in $candidatas) { if ($pings.ContainsKey($c.Direccion)) { $c.Ping = [bool]$pings[$c.Direccion] } }
            }
            foreach ($linea in (Get-BLDiagnostico -Candidatas $candidatas -Anfitrion $srv.Anfitrion)) { Decir ('   - ' + $linea) }
            if ($NoPreguntar) { exit 4 }
            Decir ''
            Decir '  Que hago?   R = volver a probar   |   un numero = abrir el juego por esa direccion aunque no conteste   |   Intro = salir'
            for ($i = 0; $i -lt $candidatas.Count; $i++) { Decir ('        {0} = {1} {2}:{3}' -f ($i + 1), $candidatas[$i].Etiqueta, $candidatas[$i].Direccion, $candidatas[$i].Puerto) }
            $respuesta = (Read-Host '        Respuesta').Trim()
            if ($respuesta -eq '') { exit 4 }
            $numero = 0
            if ([int]::TryParse($respuesta, [ref]$numero) -and $numero -ge 1 -and $numero -le $candidatas.Count) {
                $elegida = $candidatas[$numero - 1]
                Decir ('        Vale: abro el juego por ' + $elegida.Direccion + ' sin haber visto que conteste.') 'Yellow'
            }
            Decir ''
        }
    }
    Decir ('        Elegida: {0}  {1}:{2}' -f $elegida.Etiqueta, $elegida.Direccion, $elegida.Puerto) 'Green'
    Decir ('ELEGIDA: {0} {1}:{2}' -f $elegida.Red, $elegida.Direccion, $elegida.Puerto) 'DarkGray'

    # ---------------------------------------------------------------------------------- 5. abrir el juego
    $tolerante = $false
    if ($srv.SaludoTolerante -eq 'siempre') { $tolerante = $true }
    elseif ($srv.SaludoTolerante -eq 'vpn' -and $elegida.Tipo -ne 'lan' -and $elegida.Tipo -ne 'local') { $tolerante = $true }
    $argumentos = Get-BLArgumentosCliente -NombreServidor $srv.Nombre -Direccion $elegida.Direccion -Puerto $elegida.Puerto -Jugador $nombre -SaludoTolerante:$tolerante
    $exe = Join-Path $carpeta 'Barotrauma.exe'

    # Solo cuenta TU juego abierto (el de esta carpeta); otra copia en otra carpeta no estorba.
    $abiertos = @(Get-Process -Name 'Barotrauma' -ErrorAction SilentlyContinue | Where-Object { $ruta = ''; try { $ruta = [string]$_.Path } catch { }; ($ruta -eq '') -or ($ruta -ieq $exe) })
    if ($EnSeco) {
        if ($abiertos.Count -gt 0) { Decir '        AVISO: Barotrauma ya esta abierto. De verdad te pediria que lo cerraras antes.' 'Yellow' }
        Decir ''
        Decir '  [4/4] EN SECO. Esta es la orden que lanzaria (no la lanzo):' 'Yellow'
        Decir ('ORDEN: "' + $exe + '" ' + $argumentos)
        exit 0
    }
    if ($abiertos.Count -gt 0) {
        Decir ''
        Decir '  Barotrauma YA ESTA ABIERTO. Cierralo (Salir, en su menu) y vuelve a abrir esto:' 'Yellow'
        Decir '  solo puede entrar directo al servidor al arrancar.'
        exit 7
    }
    Decir ''
    Decir '  [4/4] Abriendo Barotrauma...' 'Green'
    Start-Process -FilePath $exe -ArgumentList $argumentos -WorkingDirectory $carpeta
    Decir '        - Cuando termine de cargar, PULSA UNA TECLA o haz clic dentro del juego: entonces entra al servidor.'
    if (@(Get-Process -Name 'steam' -ErrorAction SilentlyContinue).Count -eq 0) {
        Decir '        - Steam no esta abierto: puede que el juego avise de que no encuentra Steam. Acepta el aviso y sigue.'
    }
    if ($srv.TieneContrasena) {
        if ($srv.Contrasena) {
            Decir ('        - El servidor tiene contrasena. El juego te la va a pedir:  ' + $srv.Contrasena) 'Yellow'
        } else {
            Decir ('        - El servidor tiene contrasena. El juego te la va a pedir: preguntasela a ' + $srv.Anfitrion + '.') 'Yellow'
        }
    }
    Decir '        - Si el juego dice que no puede conectar, cierralo y vuelve a abrir este fichero.'
    exit 0
} catch {
    Decir ''
    Decir ('  Ha fallado algo que no esperaba: ' + $_.Exception.Message) 'Red'
    Decir ('  (' + $_.InvocationInfo.ScriptName + ', linea ' + $_.InvocationInfo.ScriptLineNumber + ')') 'DarkGray'
    Decir '  Hazle una captura de esta ventana al anfitrion.'
    exit 9
}
