# ==============================================================================================================
# cortafuegos.ps1  -  Barotrauma LAN 0.1  -  LA regla del cortafuegos de Windows para el servidor
#
# Lo abre EL DUENO DEL PC, como administrador (los .bat CORTAFUEGOS-...). Ninguna otra pieza de Barotrauma LAN
# toca el cortafuegos.
#
#   -Accion abrir    anade UNA regla: deja ENTRAR trafico UDP al puerto del servidor y solo para el programa
#                    DedicatedServer.exe de la carpeta del servidor. Antes quita la regla vieja de esta herramienta
#                    (por si cambiaste de puerto o de carpeta). No toca ninguna otra regla.
#   -Accion quitar   quita las reglas del grupo "Barotrauma LAN" y nada mas.
#   -Accion ver      ensena las reglas de ese grupo. No cambia nada y no necesita administrador.
#   -EnSeco          con abrir o quitar: ensena lo que haria y no lo hace (no necesita administrador).
#   -NoPreguntar     no pide confirmacion.          -Ajustes <ruta>   otro fichero de ajustes.
#
# Codigos de salida: 0 bien | 1 hace falta administrador | 2 cancelado | 9 error
# ==============================================================================================================
param(
    [ValidateSet('abrir', 'quitar', 'ver')][string]$Accion = 'ver',
    [switch]$EnSeco,
    [switch]$NoPreguntar,
    [string]$Ajustes = ''
)

$ErrorActionPreference = 'Stop'
$AL_Aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$AL_Proyecto = Split-Path -Parent $AL_Aqui
. (Join-Path (Join-Path $AL_Proyecto 'amigo') 'barolan-comun.ps1')
. (Join-Path $AL_Aqui 'anfitrion-lib.ps1')

function Decir { param([string]$Texto = '', [string]$Color = '') if ($Color) { Write-Host $Texto -ForegroundColor $Color } else { Write-Host $Texto } }

function Test-SoyAdministrador {
    $yo = New-Object System.Security.Principal.WindowsPrincipal -ArgumentList ([System.Security.Principal.WindowsIdentity]::GetCurrent())
    return $yo.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensenar-Reglas {
    $reglas = @(Get-NetFirewallRule -Group $script:AL_GrupoCortafuegos -ErrorAction SilentlyContinue)
    if ($reglas.Count -eq 0) { Decir '      (ahora mismo no hay ninguna regla de Barotrauma LAN)'; return 0 }
    foreach ($r in $reglas) {
        $pf = $r | Get-NetFirewallPortFilter
        $af = $r | Get-NetFirewallApplicationFilter
        Decir ('      "{0}"  {1} {2} {3} puerto {4}  activa={5}' -f $r.DisplayName, $r.Direction, $r.Action, $pf.Protocol, (@($pf.LocalPort) -join ','), $r.Enabled)
        Decir ('         programa: ' + $af.Program)
    }
    return $reglas.Count
}

try {
    Decir ''
    Decir ('  BAROTRAUMA LAN {0}  -  cortafuegos de Windows  ({1})' -f $script:BL_Version, $Accion) 'Cyan'
    if ($EnSeco) { Decir '  MODO EN SECO: enseno lo que haria y no cambio nada.' 'Yellow' }
    Decir ''

    if ([string]::IsNullOrWhiteSpace($Ajustes)) { $Ajustes = Join-Path $AL_Aqui 'ajustes-anfitrion.json' }
    $Ajustes = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Ajustes)
    $a = (Read-ALAjustes -Ruta $Ajustes).Ajustes
    $pegas = @(Test-ALAjustes $a)
    if ($pegas.Count -gt 0) { Decir ('  Los ajustes no valen: ' + ($pegas -join '; ')) 'Red'; exit 9 }

    if ($Accion -eq 'ver') {
        Decir '  Reglas del grupo "Barotrauma LAN":'
        [void](Ensenar-Reglas)
        # Tambien las que haya para el programa del servidor (por ejemplo las que crea Windows con su aviso).
        $carpetaJuegoVer = ''
        if (-not [string]::IsNullOrWhiteSpace([string]$a.carpetaJuego)) { $carpetaJuegoVer = ConvertTo-BLCarpetaJuego ([string]$a.carpetaJuego) }
        else { $jv = Find-BLJuego; if ($null -ne $jv) { $carpetaJuegoVer = $jv.Carpeta } }
        if ($carpetaJuegoVer -or -not [string]::IsNullOrWhiteSpace([string]$a.carpetaServidor)) {
            $exeVer = Join-Path (Join-Path (Get-ALRaizServidor $a $carpetaJuegoVer) 'servidor') 'DedicatedServer.exe'
            $e = Get-ALEstadoCortafuegos -Puerto $a.puerto -Exe $exeVer
            Decir ''
            Decir ('  Para ' + $exeVer + ' (UDP ' + $a.puerto + '):')
            if (-not $e.Comprobado) { Decir ('      no he podido mirarlo: ' + $e.Detalle) }
            else {
                if (@($e.Permiten).Count -eq 0) { Decir '      ninguna regla lo deja entrar' } else { Decir ('      lo dejan entrar: ' + (@($e.Permiten) -join '; ')) }
                foreach ($b in @($e.Bloquean)) { Decir ('      LO BLOQUEA: ' + $b) 'Red' }
            }
        }
        exit 0
    }

    if ($Accion -eq 'quitar') {
        Decir '  Voy a QUITAR las reglas del grupo "Barotrauma LAN" del cortafuegos de Windows. Ninguna otra.'
        Decir '  Despues, tus amigos dejan de poder entrar a tu servidor desde otro PC.'
        Decir ''
        $n = Ensenar-Reglas
        if ($EnSeco) { Decir ''; Decir ("ORDEN: Get-NetFirewallRule -Group '" + $script:AL_GrupoCortafuegos + "' | Remove-NetFirewallRule"); exit 0 }
        if ($n -eq 0) { exit 0 }
        if (-not (Test-SoyAdministrador)) {
            Decir ''
            Decir '  Hace falta abrir este fichero COMO ADMINISTRADOR: clic derecho - Ejecutar como administrador.' 'Yellow'
            exit 1
        }
        if (-not $NoPreguntar) {
            $r = Read-Host '  Escribe SI para quitarlas'
            if ($r.Trim().ToUpperInvariant() -ne 'SI') { Decir '  No he tocado nada.'; exit 2 }
        }
        Get-NetFirewallRule -Group $script:AL_GrupoCortafuegos | Remove-NetFirewallRule
        Decir '  Quitadas.' 'Green'
        exit 0
    }

    # ----- abrir
    $carpetaJuego = ''
    if (-not [string]::IsNullOrWhiteSpace([string]$a.carpetaJuego)) { $carpetaJuego = ConvertTo-BLCarpetaJuego ([string]$a.carpetaJuego) }
    else { $j = Find-BLJuego; if ($null -ne $j) { $carpetaJuego = $j.Carpeta } }
    if (-not $carpetaJuego -and [string]::IsNullOrWhiteSpace([string]$a.carpetaServidor)) {
        Decir '  No encuentro el juego y no hay "carpetaServidor" en los ajustes: no se para que programa es la regla.' 'Red'
        Decir '  Abre antes 1-ABRIR-SERVIDOR.bat una vez.'
        exit 9
    }
    $exe = Join-Path (Join-Path (Get-ALRaizServidor $a $carpetaJuego) 'servidor') 'DedicatedServer.exe'
    $p = Get-ALParametrosRegla -Puerto $a.puerto -Exe $exe -Alcance ([string]$a.cortafuegosAlcance) -Interfaces @(Get-BLInterfaces)

    Decir '  Voy a anadir UNA regla al cortafuegos de Windows:'
    Decir ('    deja ENTRAR trafico UDP al puerto ' + $a.puerto + ', solo para el programa')
    Decir ('    ' + $exe)
    if ($a.cortafuegosAlcance -eq 'subred') { Decir ('    y solo desde tus redes directas (' + (@($p.RemoteAddress) -join ', ') + ').') }
    Decir '  No abre nada mas y no toca ninguna otra regla. Se quita con CORTAFUEGOS-QUITAR-como-administrador.bat'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        Decir '  (La carpeta del servidor todavia no existe: la regla valdra en cuanto abras 1-ABRIR-SERVIDOR.bat.)' 'DarkGray'
    }
    Decir ''
    if ($EnSeco) {
        Decir ("ORDEN: Get-NetFirewallRule -Group '" + $script:AL_GrupoCortafuegos + "' | Remove-NetFirewallRule   (solo si ya habia una de esta herramienta)")
        Decir ('ORDEN: ' + (Get-ALTextoRegla $p))
        exit 0
    }
    if (-not (Test-SoyAdministrador)) {
        Decir '  Hace falta abrir este fichero COMO ADMINISTRADOR: clic derecho - Ejecutar como administrador.' 'Yellow'
        exit 1
    }
    if (-not $NoPreguntar) {
        $r = Read-Host '  Escribe SI para anadirla'
        if ($r.Trim().ToUpperInvariant() -ne 'SI') { Decir '  No he tocado nada.'; exit 2 }
    }
    $viejas = @(Get-NetFirewallRule -Group $script:AL_GrupoCortafuegos -ErrorAction SilentlyContinue)
    if ($viejas.Count -gt 0) { $viejas | Remove-NetFirewallRule }
    $parametros = @{}
    foreach ($k in @($p.Keys)) { $parametros[$k] = $p[$k] }
    [void](New-NetFirewallRule @parametros)
    Decir '  Regla anadida:' 'Green'
    [void](Ensenar-Reglas)
    exit 0
} catch {
    Decir ''
    Decir ('  Ha fallado algo: ' + $_.Exception.Message) 'Red'
    exit 9
}
