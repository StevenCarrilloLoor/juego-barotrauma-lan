# ==============================================================================================================
# normalizar-ficheros.ps1  -  deja los ficheros de texto de la entrega como los espera Windows
#
#   - Finales de linea CRLF en .bat, .ps1 y .txt (un .bat con finales de linea de Unix falla de formas raras).
#   - Comprueba que lo que se entrega (amigo\, anfitrion\ y los LEEME) es ASCII puro, sin tildes: asi da igual la
#     pagina de codigos de la consola del amigo. Si encuentra algo que no lo es, lo dice y sale con codigo 1.
#
# Uso (tras editar cualquier fichero):   powershell -NoProfile -ExecutionPolicy Bypass -File pruebas\normalizar-ficheros.ps1
# ==============================================================================================================
param([switch]$SoloMirar)
$ErrorActionPreference = 'Stop'
$proyecto = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$mal = 0
$cambiados = 0
foreach ($sub in @('amigo', 'anfitrion', 'pruebas', '.')) {
    $carpeta = Join-Path $proyecto $sub
    foreach ($f in (Get-ChildItem -LiteralPath $carpeta -File | Where-Object { @('.bat', '.ps1', '.txt') -contains $_.Extension.ToLowerInvariant() })) {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        $noAscii = @($bytes | Where-Object { $_ -gt 126 -or ($_ -lt 32 -and $_ -ne 9 -and $_ -ne 10 -and $_ -ne 13) })
        if ($noAscii.Count -gt 0) {
            $texto = [System.Text.Encoding]::UTF8.GetString($bytes)
            $n = 0
            foreach ($linea in $texto.Split("`n")) {
                $n++
                if ($linea -match '[^\x09\x0A\x0D\x20-\x7E]') { Write-Host ('  NO ASCII  {0}\{1} linea {2}: {3}' -f $sub, $f.Name, $n, $linea.Trim()) -ForegroundColor Red }
            }
            $mal++
            continue
        }
        $texto = [System.Text.Encoding]::ASCII.GetString($bytes)
        $crlf = ($texto -replace "`r`n", "`n") -replace "`r", "`n"
        $crlf = $crlf -replace "`n", "`r`n"
        if ($crlf -ne $texto) {
            if ($SoloMirar) { Write-Host ('  sin CRLF   {0}\{1}' -f $sub, $f.Name) -ForegroundColor Yellow; $mal++ }
            else { [System.IO.File]::WriteAllBytes($f.FullName, [System.Text.Encoding]::ASCII.GetBytes($crlf)); $cambiados++ }
        }
    }
}
Write-Host ('  normalizar: {0} fichero(s) pasados a CRLF, {1} con pegas' -f $cambiados, $mal)
if ($mal -gt 0) { exit 1 }
exit 0
