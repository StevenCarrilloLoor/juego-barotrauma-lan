# Barotrauma LAN

Para jugar a **Barotrauma** con amigos por **red local o red privada** (ZeroTier, Radmin, Hamachi, Tailscale) con el
**servidor dedicado** que trae el propio juego, tengan o no Steam conectado. No mete nada dentro del juego: son
guiones de Windows (`.bat` + PowerShell) para el anfitrión y un doble clic para cada amigo.

Cómo funciona, en una línea: el servidor dedicado del juego se monta en una carpeta aparte con el ajuste
`RequireAuthentication="False"` (pensado por los propios desarrolladores para red local sin Steam ni Epic), y el
lanzador del amigo prueba las direcciones del anfitrión (red local y cada VPN), elige la primera que contesta y abre el
juego con `Barotrauma.exe -connect "<servidor>" <ip>:<puerto>`.

## Estado: versión 0.1

- **Probado en un laboratorio con el juego real** (Barotrauma 1.13.4, en UNA sola máquina): un cliente sin Steam entra
  al servidor por la IP local, la de la red local y la de cada adaptador de VPN; el sondeo de direcciones no deja
  rastro en el servidor; la carpeta de servidor que monta `anfitrion\servidor.ps1` arranca.
- **Sin probar todavía**: entrar desde OTRO PC por una VPN de verdad, y el lanzador del amigo en un PC real.
- **Pendiente para la 0.2** (ver `AGENTS.md`, aviso de arriba): identidad por nombre para todos por defecto, avisar de
  la tecla al entrar, sanear nombres, permisos del anfitrión, submarino de fábrica, aviso de MTU de las VPN, el consejo
  del cortafuegos y un `QUITAR-SERVIDOR.bat` seguro.

## Avisos importantes

- **Al terminar de cargar, pulsa una tecla.** El juego se queda en «PRESS ANY KEY TO CONTINUE» y no entra al servidor
  hasta que alguien pulsa con la ventana delante (después tarda menos de un segundo).
- **Todos con la misma versión del juego** (los tres primeros números iguales). El lanzador lo comprueba y avisa.
- **Cortafuegos del anfitrión**: si Windows saca su aviso la primera vez que arranca el servidor, aceptarlo crea reglas
  que abren TODOS los puertos de ese programa. Es mejor cancelarlo y usar `anfitrion\CORTAFUEGOS-ABRIR-como-administrador.bat`,
  que abre solo el puerto UDP del servidor (la 0.1 todavía aconseja lo contrario en pantalla; se corrige en la 0.2).
- **No borres la carpeta del servidor con `Remove-Item -Recurse` de PowerShell**: lleva una unión (enlace) a la carpeta
  `Content` del juego instalado y podría borrarla. Hasta la 0.2, quítala desde el Explorador de Windows.
- **Sin autenticación de Steam la identidad es el nombre**: cualquiera que llegue al puerto puede entrar con el nombre
  de otro. Úsalo solo en tu red local o tu VPN (el servidor se crea como privado) y pon contraseña.

## Requisitos

- Windows 10 u 11 con **Windows PowerShell 5.1** (viene con Windows). Nada que instalar.
- **Barotrauma** (Steam, app 602960) instalado en cada PC, en la misma versión (probado con la 1.13.4).
- Una red común: la misma red local o la misma VPN. Recomendadas **ZeroTier o Radmin** (el paquete más grande del
  juego, 1406 bytes, se trocea en Tailscale y Hamachi; con un túnel real está sin medir).
- Anfitrión: unos 150 MB libres para la carpeta del servidor (por defecto `D:\BarotraumaLAN`) y permiso de
  administrador solo para el fichero del cortafuegos.

## Uso

**Anfitrión**
1. `anfitrion\1-ABRIR-SERVIDOR.bat`: la primera vez copia la parte del juego que necesita el servidor a su carpeta
   (sin tocar la instalación de Steam), escribe su configuración, enseña las direcciones que dar a los amigos y genera
   el paquete para ellos en `PARA COMPARTIR\`. El servidor se cierra escribiendo `quit` en su ventana.
2. Una sola vez: `anfitrion\CORTAFUEGOS-ABRIR-como-administrador.bat` (clic derecho, ejecutar como administrador).
3. Manda a tus amigos el `.zip` de `PARA COMPARTIR\` (unos 23 KB: solo guiones y los datos del servidor).
4. Para jugar tú: `anfitrion\2-JUGAR-YO.bat`.

**Amigo**
1. Extrae el `.zip` en cualquier carpeta (no dentro del juego).
2. Doble clic en `JUGAR-BAROTRAUMA-LAN.bat`. La primera vez pide tu nombre de jugador y lo recuerda.
3. Si no conecta: `COMPROBAR-SIN-ABRIR-EL-JUEGO.bat` y manda una captura al anfitrión.

## Pruebas

`pruebas\EJECUTAR-PRUEBAS.bat`: 63 pruebas sin el juego (búsqueda del juego y de su versión, direcciones, configuración
del servidor, paquete, sondeo contra un servidor UDP de mentira). No acreditan nada del juego real: eso lo mide el
laboratorio.

## Qué no hace

No incluye ni reparte ficheros del juego (cada jugador usa su copia instalada), no quita ninguna protección y no sale a
internet: solo usa el ajuste del propio servidor del juego para red local.

## Documentación

- `AGENTS.md`: guía para IAs (ficheros, decisiones, qué está medido y qué no, cómo lo ensaya el laboratorio).
- `LEEME.txt` (anfitrión) y `amigo\LEEME.txt` (amigos): instrucciones cortas para personas.
