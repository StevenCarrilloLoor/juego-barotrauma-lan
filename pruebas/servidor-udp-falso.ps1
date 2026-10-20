# ==============================================================================================================
# servidor-udp-falso.ps1  -  servidor UDP DE MENTIRA para probar la sonda sin el juego
#
# OJO: esto NO es Barotrauma ni su biblioteca de red. Imita, a mano, lo que se LEYO en el codigo de Lidgren de la
# 1.13.4 (NetPeer.Internal.cs y NetConnection.Handshake.cs). Sirve para comprobar que la sonda manda lo que debe y
# entiende lo que vuelve. NO acredita nada del juego real: eso lo mide el laboratorio.
#
# Escucha SOLO en 127.0.0.1, en un puerto libre que elige Windows (no usa ningun puerto fijo).
#
#   $s = Start-BLServidorFalso -Modo lidgren      # devuelve un objeto con .Puerto
#   ...
#   $recibidos = Stop-BLServidorFalso $s          # lista de datagramas recibidos (byte[])
#
# Modos:
#   lidgren  Connect con otro identificador -> Disconnect "Wrong application identifier!"
#            Connect con el identificador del juego -> ConnectResponse (0x84)
#            Connect truncado -> Disconnect "Handshake data validation failed"
#   lleno    a cualquier Connect -> Disconnect "Server full"
#   mudo     recibe y no contesta nunca
#   basura   contesta 3 bytes sin sentido
#   texto    contesta el texto HOLA (algo que no es Lidgren)
# ==============================================================================================================

function Start-BLServidorFalso {
    param([ValidateSet('lidgren', 'lleno', 'mudo', 'basura', 'texto')][string]$Modo = 'lidgren', [string]$IdJuego = 'barotrauma')
    $sync = [hashtable]::Synchronized(@{ Parar = $false; Listo = $false; Puerto = 0; Error = $null; Recibidos = (New-Object System.Collections.ArrayList) })
    $ps = [powershell]::Create()
    [void]$ps.AddScript({
            param($sync, $Modo, $IdJuego)
            function Mensaje([byte]$tipo, [string]$texto, [byte[]]$cola) {
                $t = [System.Text.Encoding]::UTF8.GetBytes($texto)
                $carga = New-Object System.Collections.Generic.List[byte]
                $carga.Add([byte]$t.Length)
                $carga.AddRange([byte[]]$t)
                if ($null -ne $cola) { $carga.AddRange([byte[]]$cola) }
                $bits = $carga.Count * 8
                $d = New-Object System.Collections.Generic.List[byte]
                $d.Add($tipo); $d.Add([byte]0); $d.Add([byte]0)
                $d.Add([byte]($bits -band 0xFF)); $d.Add([byte](($bits -shr 8) -band 0xFF))
                $d.AddRange($carga)
                return , ($d.ToArray())
            }
            $z = $null
            try {
                $z = New-Object System.Net.Sockets.Socket -ArgumentList ([System.Net.Sockets.AddressFamily]::InterNetwork), ([System.Net.Sockets.SocketType]::Dgram), ([System.Net.Sockets.ProtocolType]::Udp)
                $z.Bind((New-Object System.Net.IPEndPoint -ArgumentList ([System.Net.IPAddress]::Loopback), 0))
                $sync.Puerto = ([System.Net.IPEndPoint]$z.LocalEndPoint).Port
                $sync.Listo = $true
                $bufer = New-Object byte[] 4096
                while (-not $sync.Parar) {
                    if (-not $z.Poll(20000, [System.Net.Sockets.SelectMode]::SelectRead)) { continue }
                    [System.Net.EndPoint]$remoto = New-Object System.Net.IPEndPoint -ArgumentList ([System.Net.IPAddress]::Any), 0
                    $n = 0
                    try { $n = $z.ReceiveFrom($bufer, [ref]$remoto) } catch { continue }
                    $copia = New-Object byte[] $n
                    [System.Array]::Copy($bufer, $copia, $n)
                    [void]$sync.Recibidos.Add($copia)
                    if ($Modo -eq 'mudo') { continue }
                    if ($Modo -eq 'basura') { [void]$z.SendTo([byte[]](1, 2, 3), $remoto); continue }
                    if ($Modo -eq 'texto') { [void]$z.SendTo([System.Text.Encoding]::ASCII.GetBytes('HOLA'), $remoto); continue }
                    if ($n -lt 5) { continue }
                    $tipo = [int]$bufer[0]
                    $bits = [int]$bufer[3] + ([int]$bufer[4] * 256)
                    $bytes = [int][math]::Ceiling($bits / 8.0)
                    if (($n - 5) -lt $bytes) { continue }      # Lidgren: "Malformed packet", sin respuesta
                    if ($tipo -ne 0x83) { continue }           # solo se contesta al saludo Connect
                    if ($Modo -eq 'lleno') { [void]$z.SendTo((Mensaje 0x87 'Server full' $null), $remoto); continue }
                    $id = $null
                    if ($bytes -ge 1) {
                        $largo = [int]$bufer[5]
                        # identificador + 8 bytes de identificador unico + 4 de hora
                        if ($largo -lt 128 -and (1 + $largo + 12) -le $bytes) { $id = [System.Text.Encoding]::UTF8.GetString($bufer, 6, $largo) }
                    }
                    if ($null -eq $id) { [void]$z.SendTo((Mensaje 0x87 'Handshake data validation failed' $null), $remoto); continue }
                    if ($id -cne $IdJuego) { [void]$z.SendTo((Mensaje 0x87 'Wrong application identifier!' $null), $remoto); continue }
                    [void]$z.SendTo((Mensaje 0x84 $IdJuego (New-Object byte[] 12)), $remoto)
                }
            } catch { $sync.Error = $_.ToString() } finally { if ($null -ne $z) { $z.Close() } }
        }).AddArgument($sync).AddArgument($Modo).AddArgument($IdJuego)
    $asa = $ps.BeginInvoke()
    $reloj = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $sync.Listo -and $null -eq $sync.Error -and $reloj.ElapsedMilliseconds -lt 5000) { Start-Sleep -Milliseconds 20 }
    if (-not $sync.Listo) { throw ('el servidor falso no arranco: ' + $sync.Error) }
    return (New-Object psobject -Property @{ Puerto = [int]$sync.Puerto; Sync = $sync; PS = $ps; Asa = $asa; Modo = $Modo })
}

function Stop-BLServidorFalso {
    # Para el servidor falso y devuelve lo que recibio (lista de byte[]).
    param($Servidor)
    Start-Sleep -Milliseconds 120      # deja llegar lo ultimo que se le haya mandado
    $Servidor.Sync.Parar = $true
    try { [void]$Servidor.PS.EndInvoke($Servidor.Asa) } catch { }
    $Servidor.PS.Dispose()
    return , @($Servidor.Sync.Recibidos.ToArray())
}

function Get-BLPuertoCerrado {
    # Un puerto UDP de 127.0.0.1 en el que ahora mismo no escucha nadie (se abre, se apunta y se cierra).
    $z = New-Object System.Net.Sockets.Socket -ArgumentList ([System.Net.Sockets.AddressFamily]::InterNetwork), ([System.Net.Sockets.SocketType]::Dgram), ([System.Net.Sockets.ProtocolType]::Udp)
    $z.Bind((New-Object System.Net.IPEndPoint -ArgumentList ([System.Net.IPAddress]::Loopback), 0))
    $p = ([System.Net.IPEndPoint]$z.LocalEndPoint).Port
    $z.Close()
    return $p
}
