# AGENTS.md — Barotrauma LAN

Guía operativa escrita PARA una IA. Aquí vive lo que se ENTREGA al dueño (Steven) y a sus amigos para jugar a Barotrauma
por IP: red local o red privada (ZeroTier, Radmin, Hamachi, Tailscale), con y sin Steam conectado. Todo lo que toque al
juego real se mide en el proyecto hermano `..\Barotrauma Laboratorio` (leer su `AGENTS.md` primero). Este fichero se
actualiza en el mismo turno en que cambie algo.

> **Repositorio PUBLICO** (2026-10-20): https://github.com/StevenCarrilloLoor/juego-barotrauma-lan. Antes de cada
> `git push`: `revisar_secretos.py <esta carpeta> --todo` (en `_archivo\orden-20261020` del espacio de trabajo) con
> ALTO 0 y MEDIO 0: nada de IP reales de VPN, id de redes ZeroTier, SteamID ni rutas de usuario de Windows. Las IP
> de las pruebas son inventadas y las de Tailscale se escriben por octetos (`IpTs`, `$script:BL_RangoTailscale`).
> `.gitattributes` guarda `.bat`, `.ps1` y `.txt` tal cual (CRLF): no quitarlo, cmd.exe lo necesita tambien en la
> descarga ZIP de GitHub.
>
> **PAUSA 2026-10-08, 13:52 local — la versión 0.2 NO está empezada en los ficheros.** Lo que hay en disco es la 0.1
> íntegra (63 pruebas en verde; el laboratorio la ensayó con el juego real sin encontrar defectos y sin tocarla). De la
> 0.2 solo se hizo la lectura de `..\Barotrauma Laboratorio\investigacion\MEDIDAS-PARA-LA-ENTREGA.md` y
> `docs\MATRIZ-CONEXION.md` y el diseño de abajo. **Ningún punto HECHO, ninguno a medias, los diez SIN EMPEZAR:**
> 1. *Identidad por nombre por defecto* — SIN EMPEZAR. Plan: `identidad` = `por-nombre` (defecto) | `steam-si-lo-hay`,
>    quitar `pendiente` (leerlo como `por-nombre`); `recetaPorNombre` = `steam_api64.dll` + `EOSSDK-Win64-Shipping.dll`
>    (MEDIDO: cero autenticadores, cero conexiones salientes); subir `formato` de los ajustes a 2 y migrar la receta de
>    una sola DLL. OJO al redactar: «estable tenga o no Steam» está MEDIDO solo con clientes SIN Steam; con cliente que
>    trae boleto es LEÍDO (H6 aplazado).
> 2. *La tecla* — SIN EMPEZAR. Plan: recuadro en `jugar.ps1` justo antes de abrir (y en seco): carga 15-18 s, se queda
>    en «PRESS ANY KEY TO CONTINUE», pulsar con la ventana delante, 0,7 s después está en la sala; con Steam cerrado,
>    además cuadro de error de Steam [OK] que no desconecta. Y en los dos LEEME.
> 3. *Nombres* — SIN EMPEZAR. Hoy ya se recorta en `jugar.ps1` y `:` ya se rechaza (no está en los rangos); falta
>    recortar también en `Get-BLArgumentosCliente` y al leer `jugador.json`, mensaje propio para `:` y explicar
>    `NameTaken` («That name is taken.»: mismo nombre, también con otras mayúsculas, con el otro dentro).
> 4. *Permisos del anfitrión* — SIN EMPEZAR. Plan: al arrancar (servidor parado) quitar de `Data\clientpermissions.xml`
>    las entradas `accountid="UNAUTHENTICATED_…"` con `permissions="All"` (las añade el juego al entrar por 127.0.0.1;
>    LEÍDO en `SaveClientPermissions`: escribe `permissions=` o `preset=`), con copia en `respaldos\`; conservar las
>    parciales (`giveperm`); aviso si `contrasena` está vacía; una línea en el LEEME del dueño. Límite que hay que
>    decir: dentro de una misma sesión, cuando el anfitrión sale, su nombre sigue valiendo hasta el siguiente arranque.
> 5. *Submarino* — SIN EMPEZAR. Plan: al sembrar, si `SelectedSubmarine`/`SelectedShuttle` no existen en
>    `<juego>\Content\Submarines\<nombre>.sub`, poner uno de fábrica (hay `Dugong.sub`, `Azimuth.sub`, `Selkie.sub`,
>    `Hemulen.sub`…; el `R-28` y el `FDF-Chopper A1` del dueño no están) y no arrastrar `HiddenSubs`,
>    `DisabledMonsters`, `SelectedCoalitionPerks`, `SelectedSeparatistsPerks`.
> 6. *MTU* — SIN EMPEZAR. Plan: `Mtu` en `Get-BLInterfaces` y `mtu` por dirección en `servidor.json`; aviso al elegir
>    una vía con MTU < 1434 (datagrama mayor medido 1406 + 28) y en la lista del anfitrión; recomendación ZeroTier o
>    Radmin en el LEEME del dueño, marcada «troceo medido en local; túnel real sin medir».
> 7. *Mods* — SIN EMPEZAR (una línea en `amigo\LEEME.txt`: «MODS REQUIRED… download?» [YES][NO], se bajan en cada entrada).
> 8. *Cortafuegos* — SIN EMPEZAR. Hay que CAMBIAR el texto actual de `servidor.ps1` (paso 8), que dice «pulsa PERMITIR»:
>    lo medido es que aceptar crea reglas Allow TCP+UDP a cualquier puerto. Nuevo consejo: antes, el fichero propio
>    (una regla UDP, un puerto); si sale el aviso, cancelarlo (qué pasa al cancelar NO está medido: decirlo).
> 9. *`QUITAR-SERVIDOR.bat`* — SIN EMPEZAR. Plan: `quitar-servidor.ps1`: negarse si el servidor está abierto o si falta
>    `barolan-carpeta.json`; comprobar que `servidor\Content` ES una unión y enseñar adónde apunta; quitarla con
>    `cmd /c rmdir` (sin `/s`); comprobar que no queda ningún punto de reanálisis; borrar a mano fichero a fichero sin
>    entrar en uniones; `partidas\` solo con `-TambienPartidas`; prueba con unión de mentira. Ajustar la prueba
>    estática que hoy prohíbe `rmdir`. **Mientras no exista: NO borrar `D:\BarotraumaLAN\servidor` en recursivo.**
> 10. *Documentación* — SIN EMPEZAR: la sección 7 de abajo y los dos LEEME siguen diciendo LEÍDO/SUPUESTO donde el
>     laboratorio ya tiene MEDIDO (sonda limpia, la carpeta arranca en 6,9 s, permisos por 127.0.0.1, contraseña,
>     receta por nombre, `-lenienthandshake`). Sigue sin medir: entrar desde OTRO equipo por la VPN y el arranque real
>     de `jugar.ps1` en un PC con su perfil.
>
> **ESTADO 2026-10-08 — versión 0.1 ESCRITA y probada SIN el juego; NADA de esta carpeta se ha ejecutado contra
> Barotrauma.** Hay: `anfitrion\` (servidor dedicado en carpeta propia + paquete + cortafuegos aparte), `amigo\`
> (lanzador de doble clic con sonda), `pruebas\` (63 pruebas, 63 bien, ~35 s, sin el juego). Nada dentro del juego.
> Falta: (1) que el laboratorio mida lo de la sección 7 con el ejecutable real (sobre todo la SONDA y la carpeta de
> servidor que monta `servidor.ps1`), (2) la prueba con una segunda máquina (sección 9), (3) que el dueño decida la
> identidad y los datos del servidor (sección 6). Hasta entonces el paquete no se reparte como definitivo.
> Lo único del juego real en que se apoya ya esto: evidencia en bruto del laboratorio de hoy
> (`..\Barotrauma Laboratorio\investigacion\evidencia-20261008\H4\`): con `RequireAuthentication="False"` un cliente
> sin Steam entra por `-connect "<nombre>" 127.0.0.1:29015` y queda como `UNAUTHENTICATED_<nombre>`. Su resumen
> oficial irá en `..\Barotrauma Laboratorio\investigacion\MEDIDAS-PARA-LA-ENTREGA.md` (al escribir esto no existía).

Índice: 1 qué pidió el dueño · 2 reglas · 3 ficheros · 4 cómo se usa · 5 formatos y códigos · 6 decisiones y por qué ·
7 medido / leído / supuesto y qué falta medir · 8 cómo lo ensaya el laboratorio · 9 prueba con la segunda máquina ·
10 pruebas sin el juego · 11 trampas ya pisadas · 12 preguntas al laboratorio · 13 siguiente.

## 1. Qué pidió el dueño (2026-10-08)

Jugar por red local o por VPN (tiene ZeroTier, Tailscale, Hamachi y Radmin); que entren a la misma partida los que
tienen Steam conectado y los que no; que la conexión pruebe las vías y se quede con la que funcione; rápido para los
amigos (un doble clic). Dijo que el servidor dedicado «sería lo más fácil». Precisión del mismo día: «mientras se pueda
establecer una conexión LAN mediante IP o por la red privada sirve» → **lo que tiene que ir bien es LAN por IP y red
privada**; internet sin VPN queda como opción APAGADA por defecto, que el anfitrión añade a mano, y ningún guion
consulta servicios externos para averiguar la IP pública. Orden de sondeo por defecto: red local y luego cada VPN.

## 2. Reglas de lo que se entrega

1. Cada jugador usa SU copia instalada; aquí no se reparte el juego ni se quita ninguna protección. El paquete del amigo
   lleva solo guiones y `servidor.json` (hay una prueba que lo comprueba).
2. La instalación del dueño (`D:\SteamLibrary\steamapps\common\Barotrauma`) es de SOLO LECTURA: de ahí solo se copia.
   Su carpeta de datos (`%LOCALAPPDATA%\Daedalic Entertainment GmbH\Barotrauma`, con nube de Steam y 2,3 GB de mods)
   no se toca: el servidor se lanza con su propio perfil (sección 6.4).
3. Los guiones NO tocan el cortafuegos, ni puertos, ni servicios, ni instalan nada, ni cierran procesos a la fuerza, ni
   salen a internet. La única pieza que cambia el cortafuegos es `anfitrion\cortafuegos.ps1`, y la abre el dueño como
   administrador. Hay una prueba estática que vigila todo esto.
4. En esta carpeta ningún agente lanza `Barotrauma.exe` ni `DedicatedServer.exe`: la integración con el juego real la
   hace el laboratorio (sección 8). Aquí todo se prueba en seco.
5. Honestidad: en los textos no se dice «funciona» sin medirlo. Etiquetas MEDIDO (por el laboratorio, con el juego
   real), LEÍDO (código de la 1.13.4), SUPUESTO.
6. Textos para personas: español, cortos y **solo ASCII (sin tildes)** en `.bat`, `.ps1` y `.txt`. Tras editar cualquiera:
   `pruebas\normalizar-ficheros.ps1` (los deja en CRLF y avisa de lo que no sea ASCII).

## 3. Ficheros

| Ruta | Qué es |
|---|---|
| `LEEME.txt` | Para el dueño: estado, cómo se usa, ajustes, lo que tiene que saber, lo que está sin medir. |
| `amigo\JUGAR-BAROTRAUMA-LAN.bat` | Doble clic del amigo → `jugar.ps1`. Si el guion sale con error, pausa; si no, se cierra sola a los 15 s. |
| `amigo\COMPROBAR-SIN-ABRIR-EL-JUEGO.bat` | `jugar.ps1 -EnSeco`: diagnóstico para mandar una captura al anfitrión. |
| `amigo\jugar.ps1` | El lanzador: juego → versión → nombre → sonda → `Barotrauma.exe -connect …`. |
| `amigo\barolan-comun.ps1` | Biblioteca compartida (prefijo `BL`): VDF de Steam, búsqueda del juego, versiones, nombres, redes, `servidor.json`, **la sonda** (`Invoke-BLSonda`), diagnóstico. La cargan también los guiones del anfitrión. |
| `amigo\LEEME.txt` | Para los amigos. `amigo\` es EXACTAMENTE lo que viaja en el paquete (+ `servidor.json`, que se genera). |
| `anfitrion\1-ABRIR-SERVIDOR.bat` | `servidor.ps1 -Accion abrir`. |
| `anfitrion\2-JUGAR-YO.bat` | `..\amigo\jugar.ps1 -Local -DatosServidor servidor-actual.json` (prueba primero 127.0.0.1). |
| `anfitrion\VER-ESTADO-sin-tocar-nada.bat` | `servidor.ps1 -Accion estado`: solo mira (ni crea `ajustes-anfitrion.json`). |
| `anfitrion\CORTAFUEGOS-ABRIR-como-administrador.bat` / `…-QUITAR-…` | `cortafuegos.ps1 -Accion abrir|quitar`. No se autoelevan: si no hay administrador, lo dicen y salen. |
| `anfitrion\servidor.ps1` | Orquesta: ajustes → juego → carpeta de servidor → XML → direcciones → paquete → puerto/cortafuegos (leer) → arrancar. |
| `anfitrion\anfitrion-lib.ps1` | Biblioteca del anfitrión (prefijo `AL`): ajustes, copia + unión, XML, perfil propio, paquete, lectura del cortafuegos. |
| `anfitrion\cortafuegos.ps1` | LA regla: entrada, UDP, puerto del servidor, programa `…\servidor\DedicatedServer.exe`, grupo «Barotrauma LAN». `abrir`, `quitar`, `ver`, `-EnSeco`. |
| `anfitrion\ajustes-anfitrion.json` | Se crea en el primer `abrir`/`preparar`. `anfitrion\servidor-actual.json`: copia de los datos del paquete para `2-JUGAR-YO.bat`. |
| `PARA COMPARTIR\Barotrauma LAN - <servidor>\` y `.zip` | Paquete generado para los amigos. |
| `pruebas\pruebas.ps1`, `EJECUTAR-PRUEBAS.bat` | Pruebas sin el juego (sección 10). `servidor-udp-falso.ps1`: servidor UDP de mentira. |
| `pruebas\sondear.ps1` | La sonda suelta para que el laboratorio la mida contra el servidor real (limpia, completa, ping). |
| `pruebas\normalizar-ficheros.ps1` | CRLF + comprobación de ASCII. |

Fuera de esta carpeta, cuando el DUEÑO lo usa de verdad (no en las pruebas): `D:\BarotraumaLAN\` = `servidor\` (248
ficheros copiados: raíz sin el estado, `x64\`, `Data\`; más `LocalMods\` vacía, unión `Content` → instalación y `barolan-carpeta.json`),
`partidas\`, `perfil\` (`AppData\Local`, `AppData\Roaming`, `Temp`), `respaldos\`. En el PC del amigo:
`%APPDATA%\BarotraumaLAN\jugador.json`.

## 4. Cómo se usa (resumen; el detalle para personas está en los dos LEEME)

- **Anfitrión**: `1-ABRIR-SERVIDOR.bat` (la primera vez copia ~148 MB) → manda el `.zip` de `PARA COMPARTIR` →
  `2-JUGAR-YO.bat`. Cerrar: `quit` en la ventana del servidor. Cortafuegos: una vez, como administrador (o «Permitir»
  en el aviso de Windows marcando redes privadas Y públicas).
- **Amigo**: extraer el `.zip`, doble clic en `JUGAR-BAROTRAUMA-LAN.bat`; la primera vez pide el nombre.

## 5. Formatos, parámetros y códigos

### `amigo\jugar.ps1`
Parámetros: `-EnSeco` (no lanza; imprime la orden) · `-NoPreguntar` · `-Local` (añade 127.0.0.1 delante y admite lista
vacía) · `-DatosServidor <servidor.json>` · `-CarpetaDatos <dir>` (en vez de `%APPDATA%\BarotraumaLAN`) ·
`-CarpetaJuego <dir>` · `-Jugador <nombre>` (con cualquiera de estos dos no guarda nada) · `-Sonda limpia|ping|ninguna` ·
`-Forzar <ip>` (sin sondear) · `-EsperaMs` (450) · `-IgnorarVersion` y `-PermitirBucle` (solo pruebas/laboratorio).
Líneas para máquinas en la salida: `ELEGIDA: <red> <ip>:<puerto>` y, en seco, `ORDEN: "<exe>" <argumentos>` (última línea).
Salida: 0 bien · 2 no hay juego · 3 versión distinta · 4 no contesta ninguna · 5 `servidor.json` mal · 6 nombre ·
7 el juego ya está abierto (el de ESA carpeta) · 9 error.
Orden que lanza: `Barotrauma.exe -connect "<servidor>" <ip>:<puerto> -username "<jugador>" -skipintro [-lenienthandshake]`
(`-lenienthandshake` solo si la vía elegida no es `lan` ni `local` y `saludoTolerante` = `vpn`), con
`Start-Process` y carpeta de trabajo = la del juego.

### `anfitrion\servidor.ps1`
`-Accion abrir|preparar|estado` · `-EnSeco` (con `abrir`: lo prepara todo y no arranca) · `-NoPreguntar` ·
`-Ajustes <json>` · `-CarpetaSalida <dir>` (paquete; por omisión `..\PARA COMPARTIR`) · `-EsperaArranqueS` (120).
Líneas para máquinas: `PAQUETE: <zip>`, `ENTORNO: VAR=valor` (una por variable, antes de la orden) y `ORDEN: "<exe>" <args>`.
Salida: 0 · 2 no hay juego · 3 ajustes · 4 carpeta no válida · 5 puerto ocupado · 9 error.
Orden: `DedicatedServer.exe -name "<n>" -port <p> -queryport <p+1> -public false -maxplayers <m> -nopassword|-password "<c>" [-lenienthandshake]`.

### `anfitrion\ajustes-anfitrion.json` (valores de fábrica)
`nombreAnfitrion` (usuario de Windows) · `nombreServidor` `""` (= el `ServerName` del juego si se importa; si no,
«Barotrauma LAN») · `puerto` **27715** · `maxJugadores` 8 · `contrasena` `""` · `contrasenaEnElPaquete` true ·
`carpetaJuego` `""` (buscar) · `carpetaServidor` `""` (= `<unidad del juego>:\BarotraumaLAN`) · `datos` `propios` |
`los-de-mi-juego` · `carpetaPerfil` `""` (= `carpetaServidor\perfil`) · `importarAjustesDeMiJuego` true ·
`anfitrionAdministraDesdeEstePC` true · `identidad` `pendiente` | `steam-si-lo-hay` | `por-nombre` ·
`recetaPorNombre` `["steam_api64.dll"]` · `sonda` `limpia` | `ping` | `ninguna` · `saludoTolerante` true ·
`ordenRedes` `["lan","zerotier","radmin","hamachi","tailscale","otra"]` · `redesExcluidas` `[]` (IP o nombre de red) ·
`direccionInternet` `""` · `puertoInternet` 0 · `cortafuegosAlcance` `cualquiera` | `subred`.

### `servidor.json` (formato 1; lo único del paquete que cambia)
```json
{ "formato": 1, "herramienta": "Barotrauma LAN 0.1", "generado": "2026-10-08 13:01",
  "servidor": { "nombre": "…", "puerto": 27715, "version": "1.13.4.0", "anfitrion": "…", "tieneContrasena": false },
  "sonda": "limpia", "saludoTolerante": "vpn",
  "direcciones": [ { "red": "lan", "tipo": "lan", "direccion": "192.168.1.103", "prefijo": 24, "etiqueta": "Red local", "interfaz": "Wi-Fi" } ] }
```
`red`: lan · zerotier · radmin · hamachi · tailscale · otra · internet. `tipo`: lan · vpn · internet. `puerto` opcional
por dirección. `prefijo` sirve para que el amigo sepa si tiene esa red (Tailscale da /32: se mira su rango entero, 100.64/10).
Solo `tipo` internet admite nombre DNS (lo resuelve el lanzador: el juego no resuelve nombres por `-connect`). Las 127.x
se descartan al leer (serían el PC del amigo) salvo `-PermitirBucle`.

### Otros
`<servidor>\barolan-carpeta.json`: manifiesto de lo copiado (versión, build, lista). Es lo que autoriza a borrar un
fichero sobrante. `%APPDATA%\BarotraumaLAN\jugador.json`: `{ "jugador": "…", "carpetaJuego": "…" }`.

## 6. Decisiones y por qué

1. **Nada dentro del juego.** Arquitectura del estudio (`02-vias-de-mod-y-arquitectura.md` §10.1): dedicado + lanzador.
2. **Tecnología: `.bat` + Windows PowerShell 5.1.** Viene con Windows 10/11, no instala nada, no pide administrador, el
   amigo puede leerlo, y es lo que el dueño ya repartió (`Project Zomboid\…\Para tu amigo`). Frente a un `.exe`
   compilado: un `.exe` sin firmar bajado de Discord sufre más SmartScreen y antivirus, no se puede leer y obliga a
   compilar por versión. Coste asumido: `powershell -ExecutionPolicy Bypass` desde un `.bat` puede asustar a algún
   antivirus (no se ofusca nada, no hay ventanas ocultas, ni descargas, ni órdenes codificadas); en un equipo con
   directiva que fuerce la ejecución de guiones o con lenguaje restringido no arrancaría (SUPUESTO que los amigos
   no lo tienen). Solo ASCII y CRLF: PowerShell 5.1 lee los `.ps1` sin marca como ANSI y `cmd` los `.bat` en la página
   850; con ASCII da igual.
3. **Puerto 27715**, no el 27015 de fábrica: el dueño dejó el 27015/27016 sin usar y el laboratorio tiene 29015-29026.
   El amigo nunca lo teclea (va en `servidor.json`).
4. **Carpeta de servidor propia + perfil propio.** `Sync-ALCarpetaServidor` copia los ficheros sueltos de la raíz
   (menos el estado del dueño: `config_player.xml`, `serversettings.xml`, `creature_metrics.xml`,
   `crashreport*.log`…), `x64\`, los `Data\` que no son estado (sin `clientpermissions.xml`, `bannedplayers.xml`,
   `serverblacklist.xml`) y una UNIÓN `Content` → instalación. Sobre la instalación real de hoy el plan (solo
   listado, sin copiar) da **248 ficheros, 147,8 MB**: 241 de la raíz + `x64\SDL2.dll` + 6 de `Data\`, el mismo
   conjunto que monta el laboratorio en sus instancias. Motivo LEÍDO: el servidor reescribe
   `serversettings.xml` en cada arranque junto a su exe, y el del dueño está con `IsPublic="True"` y
   `RequireAuthentication="True"`. **Datos `propios` (por defecto)**: el servidor se lanza con `USERPROFILE`,
   `LOCALAPPDATA`, `APPDATA`, `TEMP`, `TMP` apuntando a `<raíz>\perfil` (solo para ese proceso) y `savepath` =
   `<raíz>\partidas`. Es la receta del laboratorio (MEDIDO por él en H1 con el exe real: la carpeta de datos sigue a
   `USERPROFILE`; `AppData\Local` debe existir antes). Motivo LEÍDO
   (`ContentPackageManager.cs`, origen `WorkshopPackages`): el juego BORRA de `WorkshopMods\Installed` los mods que
   le fallen al cargar, y el servidor también carga ese origen. Contrapartida: el servidor no ve las campañas ni los
   mods de Steam del dueño. `datos = los-de-mi-juego` lo deja como el juego de fábrica (y avisa del riesgo).
5. **Detección de actualización.** Cada arranque compara versión (`DedicatedServer.dll`) y build de Steam
   (`appmanifest_602960.acf`) con el manifiesto, y tamaño+fecha fichero a fichero. Si cambió la versión: guarda
   `serversettings.xml`, `config_player.xml` y `Data\*` en `respaldos\<fecha>-antes-de-<versión>\`, recopia, quita los
   sobrantes que él mismo copió y avisa de que los amigos deben actualizar y recibir el paquete nuevo.
6. **`serversettings.xml`.** La primera vez parte del del juego del dueño (solo lectura: conserva submarino, modo,
   campaña…) y SIEMPRE fuerza: `port`, `queryport`, `password`, `enableupnp=false`, `ServerName`, `IsPublic=False`,
   `RequireAuthentication=False`, `AllowModDownloads=True`, `AllowFileTransfers=True`, `MaxPlayers`,
   `SaveServerLogs=True`. Los atributos se buscan sin distinguir mayúsculas para no duplicarlos. Además se repite en
   la línea de órdenes lo importante (los argumentos mandan sobre el XML): `-public false`, puerto, nombre.
7. **Identidad** (decisión del DUEÑO, pendiente). `pendiente` = servidor tal cual (con Steam validado, SteamID; sin él,
   `UNAUTHENTICATED_<nombre>`: la misma persona puede ser dos cuentas). `por-nombre` aplica una receta
   (`recetaPorNombre`: ficheros que NO se copian a la carpeta del servidor; por defecto `steam_api64.dll`, hipótesis
   H19 del estudio) que está **SIN MEDIR**; si el laboratorio encuentra otra, se cambia la lista en los ajustes sin
   tocar código (o `Get-ALPlanCopia` si hiciera falta algo más que omitir ficheros).
8. **La sonda, detrás de una interfaz** (`Invoke-BLSonda -Modo`). `limpia` (por defecto): UN datagrama `Connect` (0x83)
   de Lidgren con identificador `barolan-sonda` → el servidor debería contestar `Disconnect` (0x87) «Wrong
   application identifier!» desde su hilo de red, sin registro, cliente pendiente ni veto (LEÍDO en
   `Libraries\Lidgren.Network\NetPeer.Internal.cs` y `NetConnection.Handshake.cs`; el servidor desactiva
   `WarningMessage`). Hasta 2 envíos por dirección, todas a la vez (~0,9 s si alguna calla). Nunca manda tipos 1-98
   (lo comprueba una prueba) y se niega a usar el identificador `barotrauma`. Estados: `contesta`, `puerto-cerrado`
   (ICMP: el PC está y nadie escucha), `silencio`, `raro`, `error`. **Si ninguna contesta no se queda parado**:
   diagnóstico (con ping de apoyo y «¿tienes esa red?» calculado en local) y menú para reintentar o abrir el juego
   por la dirección que el amigo elija. Si el laboratorio midiera que NO es limpia: `"sonda": "ninguna"` (o `ping`)
   en los ajustes del anfitrión y paquete nuevo; con `ninguna` se elige la primera red que el amigo tiene.
   `completa` (identificador del juego + `Disconnect` de cierre) existe SOLO en `pruebas\sondear.ps1`.
9. **Versión**: iguales Mayor.Menor.Compilación (LEÍDO `NetworkMember.cs:255-263`), leída de `Barotrauma.dll` con
   `AssemblyName.GetAssemblyName` (sin cargarla). Si no coincide NO se abre el juego y no hay forma de saltárselo en
   el paquete (`-IgnorarVersion` es de laboratorio): un cliente de otra versión podría mandar cabeceras ilegibles y
   el servidor veta esa IP para siempre (riesgo 4 del informe 01, SUPUESTO).
10. **Nombre del jugador**: siempre `-username` (sin él y sin Steam el juego manda «Unknown»). Se valida con las reglas
    LEÍDAS del servidor (`Client.cs:186-214`) y se recuerda en `%APPDATA%\BarotraumaLAN`, no junto al lanzador: el
    paquete se reemplaza cada vez que cambian las direcciones y el nombre ES la identidad sin Steam.
11. **Permisos del anfitrión**: si no existe, se crea `Data\clientpermissions.xml` con
    `<Client name="Anfitrion (este PC)" address="127.0.0.1" permissions="All" />` (LEÍDO `ServerSettings.cs:479-583` y
    `GameServer.cs:352-372`; sin órdenes de consola: para eso está la ventana del servidor). Por eso `2-JUGAR-YO.bat`
    entra por 127.0.0.1.
12. **Cortafuegos**: regla por programa + puerto + UDP, todos los perfiles (Wi-Fi, ZeroTier y Radmin del dueño están
    en perfil Público, MEDIDO leyendo `Get-NetConnectionProfile`). `cortafuegosAlcance = subred` la limita a
    `LocalSubnet` (+ el rango de Tailscale, 100.64/10, si hay Tailscale): SIN MEDIR, por eso no es el valor por defecto. `servidor.ps1`
    solo LEE: reconoce también las reglas que crea Windows al pulsar «Permitir» (el laboratorio tiene dos así para su
    `s1`) y avisa si alguna BLOQUEA el exe.
13. **`-lenienthandshake`**: servidor siempre (ajuste `saludoTolerante`) y cliente solo por VPN. Recomendación del
    estudio (LEÍDO: solo alarga plazos de Lidgren); efecto real SIN MEDIR.
14. **Orden de VPN**: ZeroTier (MTU 2800), Radmin (1500), Hamachi (1404), Tailscale (1280): los datagramas de Lidgren
    llegan a 1436 bytes IP, así que las dos últimas trocean (LEÍDO + MTU leídas en este PC; efecto SUPUESTO).

## 7. Qué está medido, qué solo leído y qué falta medir

| # | Asunto | Estado | Quién lo mide / cómo |
|---|---|---|---|
| 1 | Cliente sin Steam entra al dedicado con `RequireAuthentication="False"` por `-connect`, como `UNAUTHENTICATED_<nombre>` | MEDIDO por el laboratorio (H4, 127.0.0.1, su instancia `s1` y su cliente `c1`) | — |
| 2 | La carpeta de datos del exe real sigue a `USERPROFILE` | MEDIDO por el laboratorio (H1) | — |
| 3 | **Sonda limpia**: el dedicado real contesta «Wrong application identifier!», sin línea en consola ni `ServerLogs`, sin cliente pendiente, sin veto | LEÍDO | Laboratorio, §8.B. Decide el valor por defecto de `sonda` |
| 4 | La carpeta que monta `servidor.ps1` (copia sin estado + unión + `LocalMods` vacía) arranca como la del laboratorio | SUPUESTO (la suya es «copia completa», 248 ficheros) | Laboratorio, §8.C |
| 5 | `serversettings.xml` sembrado del del dueño + atributos forzados: el servidor lo acepta y lo conserva al reescribirlo | LEÍDO | §8.C: comparar el XML tras el primer arranque |
| 6 | Permisos por `address="127.0.0.1"` | LEÍDO | §8.C: `servidor.clientes` → `permisos` ≠ `None` |
| 7 | `-connect` entra solo, sin tecla, y qué avisos salen con Steam cerrado | LEÍDO: pide tecla con la ventana activa | Laboratorio (E11) y segunda máquina |
| 8 | Receta `por-nombre` (sin `steam_api64.dll`): arranca, todos por nombre, sin esperas | SUPUESTO | Laboratorio (su instancia `c3`/variante de `s1`) |
| 9 | Regla del cortafuegos por programa+puerto en perfil Público; aviso de Windows al primer arranque | SUPUESTO / visto en la evidencia H2 del laboratorio que Windows creó reglas «DedicatedServer» Allow | Dueño + segunda máquina |
| 10 | Entrar desde OTRO PC por LAN, ZeroTier, Radmin, Hamachi, Tailscale; troceo con MTU 1280/1404; `-lenienthandshake` | SIN MEDIR | Segunda máquina (§9) |
| 11 | Contraseña: el juego la pide y se puede pegar | LEÍDO (la pide) | Laboratorio / segunda máquina |
| 12 | Con `datos = propios`, cómo llevar una campaña existente al servidor | SIN MIRAR | — |
| 13 | El lanzador en un Windows ajeno: SmartScreen, antivirus, juego de Epic, Windows 10 | SIN MEDIR (la búsqueda en manifiestos de Epic es SUPUESTA) | Segunda máquina |
| 14 | Versión distinta: mensaje del juego si se llegara a abrir | LEÍDO; el lanzador lo corta antes | No se puede medir sin otra versión |

## 8. Cómo debe ensayarlo el laboratorio (órdenes exactas)

`LAN="<carpeta de este proyecto>"` (en el PC del dueño, `Juegos\Barotrauma\Barotrauma LAN` dentro de su espacio de trabajo),
`PS5="C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File`.

### A. En seco (no lanza el juego, no cambia nada del sistema)
```
PS5 "LAN\pruebas\pruebas.ps1"                                   # 63 pruebas; escribe solo en pruebas\_tmp y lo borra
PS5 "LAN\anfitrion\servidor.ps1" -Accion estado                 # solo mira (ni crea los ajustes)
PS5 "LAN\anfitrion\cortafuegos.ps1" -Accion abrir -EnSeco       # enseña la regla; no la pone
```

### B. La sonda contra el dedicado real (lo primero: decide el modo por defecto)
Con `s1` abierto por `lab.py` (UDP 29015) y un punto de control antes (`lab.py punto -i s1 antes-sonda`):
```
PS5 "LAN\pruebas\sondear.ps1" -Direccion 127.0.0.1    -Puerto 29015 -Veces 20
PS5 "LAN\pruebas\sondear.ps1" -Direccion <IP de LAN del PC> -Puerto 29015 -Veces 20     # IP de LAN: aquí SÍ podría vetar
PS5 "LAN\pruebas\sondear.ps1" -Direccion <IP de cada VPN del PC> -Puerto 29015 -Veces 20   # y por cada VPN
```
Se da por LIMPIA si: (1) 20/20 `contesta … Wrong application identifier!`; (2) la consola del servidor y `ServerLogs`
no ganan ninguna línea (en particular, ningún `Incoming connection from`); (3) `servidor.clientes` y `clientlist`
siguen vacíos y no hay clientes pendientes; (4) `Data\bannedplayers.xml` no cambia; (5) después entra un cliente real
desde esa misma IP. Apuntar el tiempo medio. Con el servidor PARADO, la misma orden debe dar `puerto-cerrado` o
`silencio` (código 1). Opcional: `-Modo completa -Veces 3` (se espera `contesta ConnectResponse`, una línea `Incoming
connection` por vez, que el pendiente desaparezca con el `Disconnect` y ningún veto).
Si NO es limpia o no contesta: decirlo en `MEDIDAS-PARA-LA-ENTREGA.md`; aquí se pone `"sonda": "ninguna"` por defecto.

### C. La carpeta de servidor de la entrega, de verdad
Fichero de ajustes del laboratorio (por ejemplo `D:\BarotraumaLaboratorio\entrega\ajustes-anfitrion.json`):
```json
{ "nombreAnfitrion": "Lab", "nombreServidor": "BaroLAN-entrega", "puerto": 29025,
  "carpetaServidor": "D:\\BarotraumaLaboratorio\\instancias\\entrega",
  "carpetaPerfil":   "D:\\BarotraumaLaboratorio\\perfiles\\entrega",
  "importarAjustesDeMiJuego": true }
```
(con esas dos carpetas, el exe queda bajo `instancias\entrega\` y los datos bajo `perfiles\entrega\`, que es lo que
comprueba el guardia del laboratorio con `BAROLAB_INSTANCIA=entrega`; `importarAjustesDeMiJuego` LEE el
`serversettings.xml` de la instalación del dueño).
```
PS5 "LAN\anfitrion\servidor.ps1" -Accion preparar -Ajustes D:\BarotraumaLaboratorio\entrega\ajustes-anfitrion.json -CarpetaSalida D:\BarotraumaLaboratorio\entrega\paquete
```
`preparar` monta la carpeta, escribe los XML, genera el paquete y **no arranca nada**: imprime `ENTORNO: …` y `ORDEN: …`.
Vía recomendada: que el laboratorio lance ESA orden con ESE entorno desde su propio lanzador (añadiendo su gancho y
su guardia) y la cierre por su canal. Qué mirar: arranca y llega a «Server started»; `Get-NetUDPEndpoint` del proceso =
solo 29025; `serversettings.xml` reescrito conserva `IsPublic=False`, `RequireAuthentication=False` y los ajustes de
partida sembrados; `savepath` respetado (la consola dice que crea `…\partidas\Multiplayer`); centinela idéntico;
nada nuevo en `D:\SteamLibrary\…\Barotrauma` ni en los datos del dueño.
Vía «como el dueño» (abre una ventana de consola visible y se queda esperando hasta 120 s a que escuche):
```
PS5 "LAN\anfitrion\servidor.ps1" -Accion abrir -Ajustes D:\BarotraumaLaboratorio\entrega\ajustes-anfitrion.json -CarpetaSalida D:\BarotraumaLaboratorio\entrega\paquete
```
El guion NUNCA cierra el servidor: se cierra con `quit` en su ventana. Segunda pasada de `abrir`/`preparar` con el
servidor abierto: debe decir «YA ESTA ABIERTO» y no tocar la carpeta.

### D. El lanzador del amigo contra ese servidor
De verdad, `jugar.ps1` abre `Barotrauma.exe` de la carpeta que encuentre **con el perfil real de quien lo lanza**: en el
PC del dueño eso sería su juego y su cuenta, así que el laboratorio lo usa EN SECO y lanza la orden en su instancia:
```
PS5 "LAN\amigo\jugar.ps1" -EnSeco -NoPreguntar -Local -CarpetaJuego <vuestra instancia de cliente, p. ej. …\instancias\c3> -Jugador LabC3 -DatosServidor D:\BarotraumaLaboratorio\entrega\servidor-actual.json -CarpetaDatos D:\BarotraumaLaboratorio\entrega\datos-jugador
```
(`servidor-actual.json` lo deja `preparar`/`abrir` junto al fichero de ajustes; `-Local` prueba 127.0.0.1 y después
cada IP de este PC; `-CarpetaJuego` tiene que tener `Barotrauma.exe`, `Barotrauma.dll` y `Content\ContentPackages\Vanilla.xml`.)
Se espera: `[3/4]` con `Este mismo PC 127.0.0.1:29025 CONTESTA`, `ELEGIDA: local 127.0.0.1:29025` y
`ORDEN: "…\c3\Barotrauma.exe" -connect "BaroLAN-entrega" 127.0.0.1:29025 -username "LabC3" -skipintro`. Lanzar esa
orden en `c3` con el entorno del laboratorio y comprobar los cuatro puntos de siempre. Repetir con `-Forzar <IP de LAN del PC>`
y con la IP de ZeroTier (esas llevan `-lenienthandshake`). Con el servidor parado: código 4 y diagnóstico.
Casos del lanzador que solo el laboratorio puede cerrar: que la orden impresa entra sola; qué pide el juego (tecla,
avisos); `permisos` del que entra por 127.0.0.1; con contraseña en los ajustes, qué ve el cliente.

## 9. Prueba con la segunda máquina (la coordina la sesión principal)

**Antes, en el PC del dueño**: `1-ABRIR-SERVIDOR.bat` (o el laboratorio con §8.C) y la regla del cortafuegos puesta
por él (`CORTAFUEGOS-ABRIR-como-administrador.bat`, o «Permitir» con redes públicas marcado). Sin regla, el amigo verá
«no contesta» por todas las vías y no saldrá ningún aviso en ningún lado.

**Qué necesita el amigo**: Windows 10/11; SU Barotrauma instalado en la misma versión que el servidor (hoy 1.13.4.x);
estar en la red local del dueño o tener conectada la misma VPN; el `.zip` de `PARA COMPARTIR` extraído en cualquier
carpeta (no dentro del juego). Si la segunda máquina se maneja a distancia por un canal sin ventanas (SSH), los dobles clics los hace su dueño;
por el canal sí se puede dejar el `.zip` en su Escritorio y leer después `%APPDATA%\BarotraumaLAN\jugador.json`
(el canal y sus reglas están documentados fuera de este repositorio).

**Qué abre y qué debe ver**:
1. `COMPROBAR-SIN-ABRIR-EL-JUEGO.bat` (no abre el juego). Debe salir: `[1/4] Tu juego: <carpeta>` con `version
   1.13.4.0`; `[2/4]` le pide el nombre (primera vez); `[3/4] Buscando el servidor...` con UNA línea por dirección y
   al menos una `CONTESTA (N ms)`; `Elegida: <red> <ip>:<puerto>` (27715 de fábrica); y al final
   `ORDEN: "<su carpeta>\Barotrauma.exe" -connect "<servidor>" <ip>:<puerto> -username "<nombre>" -skipintro`
   (con `-lenienthandshake` detrás si la vía elegida es una VPN).
   Que mande captura. Si sale «NO CONTESTA NINGUNA DIRECCION», las frases de debajo dicen por qué (no tiene esa red /
   el PC contesta pero el servidor no / servidor cerrado).
2. `JUGAR-BAROTRAUMA-LAN.bat`. Mismas líneas y `[4/4] Abriendo Barotrauma...`. Se abre el juego; al terminar de cargar
   puede pedir una tecla o un clic; si Steam está cerrado puede salir un aviso de Steam (aceptar). Debe acabar en la
   sala del servidor (pantalla de lobby con el nombre del servidor).

**Qué confirma que entró** (formato MEDIDO por el laboratorio en su `s1`, evidencia H4):
- En la ventana del servidor (y en `D:\BarotraumaLAN\servidor\ServerLogs\<servidor>_<fecha>.txt`):
  `Incoming connection from [::ffff:<IP del amigo>]:<puerto>.` y, un segundo después, **`<nombre> has joined the server.`**
- Escribiendo `clientlist` en la ventana del servidor:
  `- 1: <nombre>, <IP del amigo>:<puerto>, Some<AccountId>(UNAUTHENTICATED_<nombre>), ping N ms`
  (con Steam conectado y validado saldría su SteamID en vez de `UNAUTHENTICATED_`: apuntar cuál sale).
- Al irse: `<nombre> has left the server.`
Si el amigo se queda fuera: en el servidor NO aparece `Incoming connection` → no llega el tráfico (cortafuegos o VPN);
aparece `Incoming connection` pero no `has joined` → mirar la línea siguiente (versión, nombre, autenticación).
Apuntar además: por qué vía entró, los ms de la sonda, si pidió tecla, qué avisos salieron, y si SmartScreen o el
antivirus pusieron pegas al `.bat`.

## 10. Pruebas sin el juego

`pruebas\EJECUTAR-PRUEBAS.bat` o `PS5 pruebas\pruebas.ps1 [-Solo <texto>] [-Conservar]`. 2026-10-08, PowerShell
5.1.26100: **63 bien, 0 fallan, 0 omitidas**. Cubren: VDF (formato nuevo y viejo, roto), búsqueda del juego en un
Steam de pega, versiones (incluida la instalación real, solo lectura: 1.13.4.0), nombres, órdenes de cliente y
servidor, comillas, clasificación y orden de redes (con las interfaces del dueño), «¿tengo esa red?», el datagrama byte
a byte (ejemplo del estudio), respuestas de Lidgren, la sonda contra el servidor de mentira (contesta / calla / lleno /
basura / puerto cerrado / varias a la vez / nunca datos), `sondear.ps1`, diagnóstico, `servidor.json` (bueno y ocho
malos), datos del jugador, ajustes, carpeta de servidor (crear, actualizar, receta, carpeta ajena, unión), XML,
permisos, perfil propio (se lanza `cmd.exe` con el entorno cambiado y se comprueba que este proceso queda igual),
regla del cortafuegos (texto), lectura del cortafuegos, paquete (contenido exacto del `.zip`), y de punta a punta en
seco los tres guiones en un PowerShell aparte. Los «juegos» son carpetas de pega con dos `.dll` vacías compiladas al
vuelo para llevar un número de versión. Red: solo 127.0.0.1 en puertos que elige Windows.
**No acreditan nada del juego real.** El servidor UDP de mentira imita lo LEÍDO en Lidgren; no es Lidgren.

## 11. Trampas ya pisadas

1. **PowerShell no distingue mayúsculas en variables**: `$salida = $entrada.Open()` dentro de una función con
   parámetro `[string]$Salida` convierte el flujo en texto. Y `@{ Direccion = …; direccion = … }` es clave duplicada.
2. **`.bat` con finales de línea de Unix** falla de formas raras; las herramientas de edición escriben LF. Tras editar:
   `pruebas\normalizar-ficheros.ps1` (hay prueba que lo vigila).
3. **Borrar una unión**: `Remove-Item -Recurse` sobre una unión en PowerShell 5.1 puede borrar lo de detrás (aquí sería
   el `Content` del juego). Solo `[IO.Directory]::Delete(ruta, $false)` (`Remove-ALUnion`), y en lo que se entrega no hay
   ningún borrado recursivo. Las pruebas quitan primero las uniones y comprueban que no queda ninguna antes de limpiar.
4. **Contar procesos `DedicatedServer`/`Barotrauma` no vale** como comprobación: el laboratorio tiene los suyos. Se
   mira por la RUTA del exe (`Get-ALServidorEnMarcha`, y «el juego ya está abierto» solo cuenta el de esa carpeta).
5. `Sort-Object` ordena sin distinguir mayúsculas; no comparar con listas ordenadas a mano.
6. Windows devuelve «puerto inalcanzable» como excepción 10054 en el `ReceiveFrom` de un zócalo UDP: es información
   (`puerto-cerrado`), no un fallo. Un cortafuegos en modo sigiloso da `silencio`.
7. La respuesta de la sonda llega desde la IPv4 normal aunque el servidor escuche en pila doble (visto con el servidor
   de mentira IPv4; con el real, el servidor ve al cliente como `[::ffff:a.b.c.d]`: MEDIDO por el laboratorio). Se
   descarta la respuesta que venga de OTRA IP (el juego tampoco la aceptaría).
8. `ConvertTo-Json` de PowerShell 5.1 mantiene las listas de un elemento solo si el valor ES una lista (`@(…)`).
9. `Start-Process` sin `-NoNewWindow` da ventana propia (lo que necesita la consola del servidor, que solo lee teclado
   real) y hereda el entorno de quien lo llama: por eso las variables se cambian un instante y se restauran.
10. Al mirar ejemplos a mano, no usar direcciones que no sean 127.x: el 2026-10-08 una vista previa mandó cuatro
    saludos de sonda y un ping a una dirección del rango de Hamachi por descuido. Las pruebas automáticas no lo hacen.
11. En Git Bash, `sed`/`cat -A` esconden los retornos de carro: para saber si un fichero está en CRLF, `file <fichero>`
    o contar bytes; no fiarse de lo que se ve.
12. La rama que ARRANCA el servidor de verdad (`servidor.ps1`, paso 8: `Start-ALProceso` + espera a que escuche + sonda
    a 127.0.0.1) no se ha ejecutado nunca con el juego; `Start-ALProceso` sí, con `cmd.exe`. Igual la rama de
    `jugar.ps1` que hace `Start-Process` del juego. El primer arranque real es del laboratorio o del dueño.

## 12. Preguntas concretas para el laboratorio

1. ¿La sonda limpia es limpia y contesta (§8.B)? ¿También desde una IP que no sea el bucle local? ¿Cuántos ms?
2. ¿Arranca una carpeta de servidor SIN `config_player.xml`, sin `Data\clientpermissions.xml`/`bannedplayers.xml` y con
   `LocalMods\` vacía (la de `servidor.ps1`), o echa algo de menos frente a vuestra copia completa de 248 ficheros?
3. Con el `serversettings.xml` sembrado del del dueño (`GameModeIdentifier="multiplayercampaign"`,
   `SelectedSubmarine="R-28"`…) y datos propios (sin sus partidas), ¿el servidor arranca limpio o se queja?
4. ¿`address="127.0.0.1"` con `permissions="All"` da permisos al que entra por bucle local? (Vuestro H4 muestra
   `permisos: None` sin ese fichero y «Saving client permissions» al entrar: ¿reescribe y conserva la entrada?)
5. Identidad «por nombre»: ¿qué receta es limpia? (sin `steam_api64.dll`; ¿y `EOSSDK-Win64-Shipping.dll`?) En vuestros
   registros sale «Refreshed server info on the Steam server list» con `-public false`: ¿el servidor queda con
   autenticador de Steam aunque sea privado?
6. ¿`-connect` por argumentos entra sin tecla? ¿Qué cuadros salen con Steam cerrado y con un `config_player.xml` normal?
7. ¿`-lenienthandshake` en el servidor cambia algo visible? ¿Lo dejamos puesto por defecto?
8. Aviso del cortafuegos de Windows al primer arranque de un exe nuevo: ¿qué creó exactamente al aceptar (vimos dos
   reglas «DedicatedServer» Allow, Private+Public, TCP y UDP)? ¿Y al cancelar?
9. Con contraseña: ¿el cuadro del juego acepta pegar con Ctrl+V?

## 13. Siguiente (cuando el laboratorio conteste)

- Ajustar el valor por defecto de `sonda` e `identidad` según las medidas, y reescribir el «SIN MEDIR» de `LEEME.txt`.
- Traer una campaña existente al servidor con datos propios; activar mods en el servidor (`LocalMods\` + su
  `config_player.xml`) y evitar la descarga repetida en los amigos.
- Si `-connect` pide tecla o los avisos estorban: es la única razón para plantear una pieza dentro del juego
  (`02-vias…` §6.3 y §10.3).
- Descubrimiento en la red local por difusión de la sonda (para no depender de `servidor.json` en casa): SUPUESTO.
