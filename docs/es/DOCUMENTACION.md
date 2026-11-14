# Continental Circus Enhanced: documentación técnica

Notas de desarrollo de la versión mejorada (octubre de 2026). Las direcciones son de la memoria del juego ya cargado.

## 1. El original

- **Cinta de dos caras.** La cara A trae un BASIC (`10 SCREEN 2:BLOAD"cas:",R`), el cargador `alicia` (E000h-E2FFh) y bloques de estilo Spectrum (marca FFh + datos + XOR) que se leen con TAPION/TAPIN:
  - 8000h-9CC7h: pantalla de carga.
  - 0400h-17FFh: la capa MSX del port (VDP, teclado, joystick y cinta).
  - 3C00h-3FFFh: la fuente, como la ROM del Spectrum.
  - 5B00h-FFFDh: el juego, que arranca en 81A0h.
- **Cara B:** `TRACK1` a `TRACK9`, los circuitos, que se cargan durante la partida. El 9 es la pantalla final, una pantalla de Spectrum de 6912 bytes.
- **Pantalla:** SCREEN 2 con la tabla de nombres 0-255 tres veces, tratada como mapa de bits.
  - La zona de juego (filas 4 a 23, 160 líneas) se dibuja en un búfer lineal en E400h, 32 bytes por línea.
  - Cada imagen se vuelca a la VRAM línea a línea (1033h). Como en SCREEN 2 los bytes de una línea están separados 8 posiciones, fija la dirección en cada byte: unos 96 ciclos por byte.
  - El marcador se reimprime entero en cada imagen con RST 10h (unos 490 ciclos por byte).
  - Hay una espera fija de unos 63.000 ciclos por imagen.
- **Velocidad:** 3,8 imágenes por segundo en carrera en MSX1, unos 920.000 ciclos por imagen.
- **Reloj:** la interrupción suma a 8A0Eh solo la mitad de las veces, y el juego pasa casi todo el tiempo con DI. En la práctica el reloj va por imagen.

## 2. Velocidad: prototipo 3 (`fuentes/prototipo3/`)

Se aplica sobre la cara A con `mkcas.py`, que recalcula los XOR de los bloques.

- **Volcado nuevo** (`blit3.asm`, en 1500h; 1033h salta a él):
  - Va columna a columna en el orden de la VRAM y aprovecha el autoincremento.
  - Las filas que solo tienen cielo y horizonte no se reenvían si no han cambiado.
  - Unos ganchos (0520h, 0743h, 0A69h, RST 10h) obligan a volcarlo todo cuando otra rutina escribe en la zona de juego.
- **Marcador** (`rst10.asm`, `glyph.asm`): RST 10h va directo a la VRAM, sin pasar por las rutinas de conversión de direcciones, y los caracteres usan una sola dirección por celda. De 131.000 a 25.000 ciclos por imagen.
- **Sin la espera fija** (8940h = NOP): quita la espera con RST 18h de la imagen de carrera, unos 69.000 ciclos.
- **Reloj por imagen:** el volcado suma al reloj lo que el original sumaba de media, así que la carrera dura lo mismo en imágenes. Medido: 1,050 décimas de TIME por imagen, frente a 1,045-1,050 del original.
- **Comprobación:** 5.083 volcados de partidas automáticas idénticos al volcado completo.
- **Resultado:** unos 480.000 ciclos por imagen, 7,25 imágenes por segundo conduciendo (145 en 20 s en openMSX), en MSX1, MSX2 y MSX2+.
- **Techo:** el bucle de volcado ya va a unos 29-32 ciclos por byte, que es lo mínimo que acepta el VDP del MSX1 con la pantalla activa. Un MSX2 no lo acorta, porque el búfer está por líneas y la VRAM por celdas. Se midió que saltar el asfalto daría solo un 5 %.

### 2.1. Después de la v1.0: volcado desenrollado y marcador incremental

Medido con `pruebas/t17.tcl` en openMSX (C-BIOS), imágenes en 20 s conduciendo:

| | v1.0 | volcado desenrollado | + marcador incremental |
|---|---|---|---|
| MSX1 | 144 | 149 | 153 (+6 %) |
| MSX2 | 144 | 154 | 158 (+10 %) |

- **Volcado desenrollado** (`blit3.asm`, `FASTROW`):
  - El bucle anterior gastaba 32 ciclos entre bytes de una columna, pero el cambio de columna (PUSH, POP, INC, DJNZ) subía la media a unos 36.
  - Una fila de 8 líneas son 256 bytes. Las de carretera (E400h + 256·fila), `TEMP` (1300h) y el bloque de cielo (1400h) empiezan en un múltiplo de 256, así que dentro de la fila H no cambia y L vale columna + 32·línea.
  - `FASTROW` son 256 veces `ld l,n / outi`: 26 ciclos por byte. En MSX1 lleva además un `nop` (31 ciclos), porque el TMS9918 necesita 29 entre escrituras.
  - No va en la ROM: la genera el arranque en RAM (`GENFAST`, banco 0) según `(002Dh)`, en dos trozos, 1C00h-1FFFh y 3AE0h-3BFFh.
  - Las filas enteras de franja del horizonte (E200h, sin alinear) siguen por el bucle anterior.
- **Marcador incremental** (`glyph.asm`):
  - Una caché de 128 bytes (1900h, la zona del copiador de arranque) guarda qué carácter muestra cada celda de las filas 0-3. Si la celda ya lo muestra, no se escribe en la VRAM.
  - Las demás rutinas que escriben ahí (RST 10h suelto, 0520h, 0743h, 0A69h y la pantalla final) ponen `HUDINV` y la caché se borra antes de volver a usarla.
  - Gana menos de lo estimado (un 2-3 %): lo que queda es montar las cadenas y pasar el BCD a cifras.
- **Ganchos:** `hook743`, `hook520` y `hookA69` pasan a 1036h, el hueco del volcado original, para dejar sitio en 1500h.
- **Comprobación:**
  - 551 volcados en MSX1 y 591 en MSX2: la VRAM de la zona de juego coincide con los búferes en todos (en MSX2 openMSX emula el acceso demasiado rápido a la VRAM; en MSX1 no, y ahí vale el margen de 31 ciclos).
  - 576 marcadores comparados cifra a cifra con un dibujo independiente: todos iguales.
  - 200 s de partida, tablas, menú y segunda partida con vigilancia de escrituras: el juego no toca 1036h-115Fh, 1900h-197Fh, 1C00h-1FFFh ni 3785h-3BFFh.
  - Con las BIOS reales (`msx1`, `msx2`, `msx2plus` y `turbor` de openMSX), 100 imágenes cronometradas en carrera: de 7,56 a 8,12 por segundo en MSX1, de 7,56 a 8,50 en MSX2, de 7,49 a 8,42 en MSX2+ y de 18,80 a 19,56 en turbo R. En turbo R, 595 volcados idénticos a los búferes.
  - Sin probar todavía en máquina real.

### 2.2. Perfil de la imagen y dos mejoras más del volcado

Perfil con puntos de ruptura de openMSX en el bucle de carrera (MSX1, 143 imágenes, unos 500.000 ciclos por imagen en ese tramo):

| Rutina | Ciclos | % |
|---|---|---|
| 8B3Fh volcado | 180.000 | 36 |
| 9571h carretera | 116.500 | 23 |
| A0D2h objetos y rivales | 72.900 | 15 |
| 9277h, 92E6h, 93BDh, 91A0h lógica | 94.000 | 19 |
| AE84h marcador | 14.700 | 3 |
| 8AB9h | 8.600 | 2 |
| resto (mandos, choques, reloj) | 13.000 | 2 |

- **El volcado, por tipo de fila:** las de carretera se llevan 114.500 ciclos (14,3 filas a 8.000, es decir, 31 ciclos por byte: el límite del VDP). El resto era cielo que se reenviaba sin hacer falta.
- **Cielo con el horizonte en movimiento** (`skysk`): antes, si la franja del horizonte se desplazaba (B50Ah ≠ 0) o cambiaba `n1`, se reenviaba todo. El cielo es FFh se mueva o no la franja, así que las filas que eran y siguen siendo cielo, min(`n1`, `ln1`), ya no se reenvían.
- **Letrero PIT IN** (`hookpit`): con el coche dañado el juego pinta el letrero (16E7h, filas 5 y 6) en casi todas las imágenes, y al pasar por 0520h ponía `FORCE`: se reenviaban las 20 filas en cada imagen. Ahora sus dos llamadas (16EEh y 172Ch) van a `hookpit`, que no pone `FORCE`. El letrero se queda en la VRAM mientras esas filas no se reenvíen (ya no parpadea) y el volcado las reenvía una vez cuando el juego deja de pintarlo (`pitnow`, `pitvram`, `pitdel`).
- **Medido:** con el coche dañado, de 7,01 a 7,71 imágenes por segundo en MSX1 y de 7,37 a 8,04 en MSX2. Sin daños, `t17.tcl` da 155 (MSX1) y 162 (MSX2) imágenes en 20 s.
- **Comprobación:** 589 volcados en MSX1 y 588 en MSX2 idénticos a los búferes (descontando el letrero mientras está en pantalla), con 4 borrados del letrero en cada tanda.
- **Lo que queda:**
  - Carretera (9571h): hecha, ver 2.3.
  - Objetos y rivales (A0D2h): el dibujo (9DB6h) ya va desenrollado con tabla de máscaras, unos 67 ciclos por byte. Depende de cuántos objetos haya.
  - Lógica (9277h, 92E6h, 93BDh): bucles de 100 líneas con tablas y PUSH, sin nada evidente que quitar.

### 2.3. Carretera: preparación de cada tramo

El generador de carretera (9571h) recorre la tabla de tramos (D600h: líneas de cada tramo; D800h: cuatro bytes con los bordes y sus patrones) y, por cada uno, prepara la máquina de PUSH de 9694h, que es la que escribe las líneas en el búfer. Hay unos 100 tramos por imagen. Los PUSH no se han tocado; la preparación está reescrita en el mismo sitio (`ccrom.asm`, `hk_9571.bin` y `hk_96f2.bin`):

- Los cuatro bytes del tramo y el patrón del borde izquierdo se leen con POP (el puntero de pila ya estaba secuestrado y las interrupciones van cortadas), en vez de con seis accesos por IY.
- El contador de fase del dibujo de los bordes vive en C' y no en memoria (antes era el operando de 95B1h).
- Las direcciones de la tabla de patrones (D000h) se montan con rotaciones de 8 bits y se guardan de dos en dos bytes.
- El `ld sp,hl / add hl,de` de la línea se hace al final, justo antes de saltar a los PUSH.
- Deja lo mismo que el original también en los casos raros: DE y H en los tramos sin bordes, y las direcciones de la tabla sin tocar cuando no se usan. El borde izquierdo usa D400h con el bit 2 del tramo y el derecho D200h, como en el original.
- La copia de 96D0h-9707h que hay en 7B30h es un resto entre datos gráficos: nadie la llama.

- **Medido** (BIOS reales de openMSX, 100 imágenes en carrera): de 8,27 a 8,63 imágenes por segundo en MSX1, de 8,64 a 9,03 en MSX2 y de 20,56 a 20,97 en turbo R. `t17.tcl` (C-BIOS): 162 (MSX1) y 169 (MSX2) imágenes en 20 s. La rutina pasa de 110.000 a 93.600 ciclos por imagen (un 15 % menos).
- **Comprobación:** prueba diferencial con el emulador de `fuentes/emu/`: se capturó la RAM al entrar en 9571h en 589 imágenes de una carrera en openMSX y se ejecutaron la rutina original y la nueva sobre cada estado. La memoria queda idéntica en las 589, y también en 4.711 variantes con las tablas de tramos alteradas al azar (bordes, anchos, patrones y líneas), que ejecutan todas las instrucciones nuevas. Al volver solo cambian registros que el bucle de carrera recarga antes de usar (HL, C', IX y los indicadores). Además, 611 volcados en MSX1, 591 en MSX2 y 600 en turbo R idénticos a los búferes.

### 2.4. Turbo de los MSX2+ de Panasonic

Los FS-A1FX, FS-A1WX y FS-A1WSX pueden poner el Z80 a 5,37 MHz desde el programa. El arranque (`INIT`, banco 0) lo activa si lo encuentra: selecciona el dispositivo 8 de los puertos conmutados (`out (40h),8`), comprueba que 40h devuelve F7h y que el bit 2 de 41h está a cero (hay turbo), y escribe 0 en 41h. En cualquier otra máquina no cambia nada.

- **Medido en openMSX** (100 imágenes en carrera): 11,41 imágenes por segundo en los tres modelos, frente a 9,03 sin turbo (un 26 % más). El FS-A1F (MSX2 con el mismo dispositivo pero sin turbo) se queda en 9,03, como cualquier MSX2.
- **VDP:** el volcado sigue a 26 ciclos por byte; con el turbo puesto la propia máquina espacia los accesos al VDP (openMSX lo emula). 590 volcados en el FS-A1WX idénticos a los búferes.
- **Sonido:** no cambia de ritmo: el juego sigue atendiendo unas 22 interrupciones por segundo en carrera, igual que sin turbo.
- **Sin probar en una máquina real.**

## 3. La ROM (`fuentes/rom/`)

MegaROM ASCII8 de 256 KB, montada por `mkrom.py`:

| Bancos | Contenido |
|---|---|
| 0 | Arranque (`ccrom.asm`) |
| 1-8 | Los 64 KB de RAM del prototipo 3 al llegar a 81A0h, con los enganches nuevos |
| 9-10 | VRAM (con los patrones de los sprites en 3800h) |
| 11-19 | `TRACK1` a `TRACK9` de la cara B |
| 20-21 | Pantalla final en SCREEN 2 |

- **Imagen de la RAM:** `snap.py` carga la cinta parcheada en el emulador de pruebas (`fuentes/emu/`) hasta 81A0h y guarda la RAM y la VRAM.
- **Sin cintas:** `construir_desde_rom.py` parte de la ROM publicada (imagen de RAM, VRAM, circuitos y pantalla final) y vuelve a poner encima todos los parches ensamblados. Sin cambios en las fuentes sale idéntica a la v1.0.
- **Arranque:**
  - Busca el slot de la RAM de la página 3 y lo pone en las cuatro páginas (con subslot si hace falta).
  - Copia los bancos 1-8 a la RAM con un copiador en 1900h, zona que el juego no carga.
  - En turbo R, si `(002Dh) ≥ 3`, llama a CHGCPU (0180h) con 81h: R800 en modo ROM.
- **Circuitos:** FB03h, el cargador de cinta, llama a FD01h. Este pone la ROM en la página 1, copia el banco del circuito a E000h y vuelve a la RAM.
- **Mapper:** el código tiene 21 escrituras a registros ASCII8 (8 de Konami, 9 de ASCII16), así que openMSX y BlueMSX lo detectan solos.

## 4. Sonido

- **Interrupción:** el juego la atiende unas 19-20 veces por segundo en carrera (el resto del tiempo va con DI). El reproductor se engancha al final de 0582h (0599h → `SNDINT`).
- **Motor** (canal A): fórmula del Hyper Rally (Konami, 1985). La velocidad del Hyper Rally es la de aquí × 0,72, y el periodo depende de la marcha y del acelerador. Marcha en B507h, acelerador en el bit 3 de B501h, velocidad en B504h. El bucle de carrera (8323h → `RACEFR`) lo mantiene vivo; en pausa o fuera de carrera se calla solo.
- **Efectos** (8A15h → `SFXREQ2`, con prioridad choque > golpe > tiempo extra > adelantar > freno):
  - Golpe (10h) y choque (0Eh): efectos 42h y 4Ch del Hyper Rally, sacados con las herramientas del desensamblado de antxiko y agrupados de tres en tres cuadros por el ritmo de interrupciones.
  - Tiempo extra (0Ch): efecto 07h del Hyper Rally.
  - Adelantar (0Fh): `SFXPASO`, aire y el motor del rival bajando de tono (`herramientas/sonido/adelantar.py`).
  - Freno: efecto 46h del Hyper Rally.
  - Fanfarrias de clasificado, no clasificado y campeón: efectos 94h, 0Bh y 9Ah del Hyper Rally pasados al formato de las canciones.
- **Semáforo** (87D7h → `SEMBEEP`): pitido corto en cada luz roja y otro más largo y agudo con la verde.
- **Músicas del mapa** (A76Ah → `MAPMUS`):
  - Las ocho canciones de la recreativa, transcritas, arregladas a tres voces y batería, y cuadradas a la rejilla de la recreativa (`fuentes/musica/`).
  - Formato `.song`: cuatro desplazamientos (voces A, B y C y batería), pares (nota, duración) y envolventes sencillas.
  - El reproductor va a 60 ticks por segundo y a 50 Hz suma 12 en vez de 10, así que el tempo es el mismo. Una tecla o el disparo cortan la música.

## 5. Rivales en sprites

- **Medianos y pequeños** (imágenes 9-23 de la tabla C477h):
  - 9CE0h → `SPRCAR`. En el búfer queda solo la silueta negra: la rutina 9DB6h se usa con sus `OR C` cambiados por NOP.
  - Encima va un sprite de 16x16 de color según el rival: rojo, azul claro, amarillo, verde o magenta.
  - `gensp.py` saca los patrones y las piezas de las propias imágenes del juego.
- **Grandes** (imágenes 0-8, al lado del jugador): patrones dinámicos en los huecos 52-63, solo el primero del fotograma. `BIGSAT` sube sus patrones al acabar el volcado, solo si la imagen ha cambiado.
- **Tabla de sprites:** se sube al acabar el volcado (166Dh → `SATW`), de cerca a lejos, con el coche grande primero para que gane en el límite de cuatro sprites por línea.
- **Fuera de carrera:** 0743h y 0A69h llaman a `SPHIDE`, que quita los sprites.
- **Coste:** la velocidad no cambió (145 imágenes en 20 s).

## 6. Jugabilidad

- **Freno** (8C9Dh → `BRAKE`): con el cursor abajo o el joystick abajo, quita el acelerador y resta 8 km/h por imagen.
- **Tecla de freno redefinible** (después de la v1.0; `REDEF` en `ccrom.asm`):
  - La v1.0 leía el cursor abajo a pelo (fila 8, bit 6) y «Define keys» (AD0Ch → 0B70h) solo preguntaba las seis teclas del original.
  - Ahora AD0Ch va a `REDEF`, que pregunta siete: LEFT, RIGHT, PAUSE, ACCELERATOR, BRAKE, GEAR CHANGE y QUIT. Las seis de siempre siguen en 17F4h-17FFh (máscara y fila, a seis bytes de distancia) y el freno en `BRKMSK`/`BRKROW`, que es lo que lee `BRAKE`.
  - Comprobado en openMSX: las siete teclas quedan guardadas, la nueva frena y el cursor abajo deja de frenar; sin redefinir, la frenada es idéntica a la de antes.
- **Velocidad en turbo R** (después de la v1.0; `SPDWAIT`, `MENUSPD` y `MENU4` en `ccrom.asm`):
  - La lógica avanza un paso por imagen, así que a las 21 imágenes por segundo del R800 todo corre casi el doble que en un MSX2+ con turbo.
  - `RACEFR` (8323h, una vez por imagen de carrera) llama a `SPDWAIT`: espera, con DI, a que el temporizador del turbo R (puertos E6h/E7h; E7h avanza casi 1 ms por unidad) llegue al mínimo elegido y lo pone a cero.
  - Se elige con la tecla 4 del menú, que solo aparece en turbo R, en la línea del «4. Kempston Joystick» que el original no pintaba (A835h → `MENUSPD`, A889h → `MENU4`): `Normal` 88 ms (11,35 imágenes por segundo, como un MSX2+ con turbo), `Fast` 66 ms (15,1) y `Max` sin límite (21,0). Arranca en `Normal`.
  - Los efectos de sonido van al ritmo de las interrupciones atendidas: unas 25 por segundo en `Normal` y `Max` (22 en un MSX2) y unas 34 en `Fast`, donde suenan algo más deprisa.
  - Lo que no se ha hecho: mantener la velocidad de juego de `Normal` dibujando 21 imágenes por segundo. Habría que reescalar todo lo que la lógica suma por imagen (avance, aceleración, giro, rivales, reloj, temporizadores); solo la velocidad se lee o escribe en 21 sitios.
- **Esperas iguales en todas las máquinas** (después de la v1.0; `R18` en `ccrom.asm`):
  - Fuera de la carrera el juego mide el tiempo con RST 18h (0C89h): un LDIR de 3.000 bytes sobre sí mismo, 17,6 ms en un Z80 a 3,58 MHz. Lo usan el semáforo (8822h, 50 vueltas por luz), la cuenta atrás de continuar (A7F1h, 500 vueltas), las iniciales (AC78h y 0C82h), el menú (ABF1h) y el mapa (0BD1h). Con el R800 o con el turbo de Panasonic todo eso se aceleraba.
  - Ahora 0C89h salta a `R18`: en turbo R espera 20 ms con el temporizador (E7h); con el turbo de Panasonic el LDIR copia 4.500 bytes; en el resto no cambia nada.
  - Medido en openMSX, cada luz del semáforo: 1,00 s en MSX1, 1,00 s en turbo R (antes 0,17) y 0,99 s en el FS-A1WX con turbo (antes 0,66). Cuenta atrás de continuar: 11,4 s en MSX1, 10,6 s en turbo R (antes 2,3) y 10,8 s en el FS-A1WX (antes 7,7).
  - La pantalla de iniciales usa la misma espera, pero no se ha cronometrado (hace falta entrar en la tabla).
- **Indicador de marcha** (después de la v1.0; `GEARDRAW` en `ccrom.asm`):
  - El original ya lo tenía: 8C84h pinta un `1` o un `2` sin negrita en la primera celda del marcador, delante de `TOP`, cuando 8CB7h invierte la marcha (B507h: 0 corta, FFh larga). Casi no se ve.
  - Ahora es un rótulo en la fila 3 del marcador, que estaba vacía: `GEAR` y `LOW` en blanco sobre verde o `HIGH` en blanco sobre rojo. El `1` fijo de la cadena `1 TOP` (A66Ch) se quita.
  - Se escribe directo en la VRAM (patrones en 0300h, colores en 2300h) solo cuando hace falta: al cambiar de marcha (8C84h → `GEARDRAW`) y, al acabar cada volcado (`SATW` → `GEARCHK`), si la marcha no es la pintada o el juego ha repintado el marcador o sus colores (`GEARINV`, que pone `hook520`/`hook743`).
- **Toque y accidente** (después de la v1.0; rutina 8356h del juego, `GEARLOW` y `CRASHEND` en `ccrom.asm`):
  - En el original, el accidente anula los mandos (B50Eh = 0) durante 70 imágenes, unos 9 s: 33 de trompo (unas 8 vueltas), 7 parado y 30 volviendo al centro. Solo al final pone la marcha corta, y si la tecla de marcha sigue pulsada en ese momento la toma como pulsación nueva y vuelve a la larga.
  - Ahora la marcha corta se pone al instante, en el toque (8379h) y en el accidente (83C0h).
  - El accidente dura 16 imágenes, unos 2 s: un giro de 360° y la vuelta al centro. Los límites de cada fase (83ECh, 83FAh, 83FDh) y lo que frena por imagen (83DBh, de 20 a 80 km/h) son las constantes `CR_*`.
  - Al reanudar (8442h → `CRASHEND`) el coche está parado y la tecla de marcha mantenida no cuenta.
  - Medido en openMSX forzando el golpe (B513h = C0h): 69 imágenes y 9,7 s en la v1.0, 17 imágenes y 2,0 s ahora.
- **Mapa de fin de carrera** (después de la v1.0; `MAPSTEP` y `MAPNIB` en `ccrom.asm`):
  - El bucle de A78Ch pinta el tramo recorrido paso a paso y tras cada paso llama a 0801h, que convierte los 768 atributos a la tabla de colores de la VRAM (unos 0,14 s cada vez).
  - Ahora 0801h se llama un paso sí y otro no, y siempre en el último (0B26h → `MAPSTEP`) o al acabarse el trazado (A7A5h → `MAPNIB`).
  - Medido con 12 pasos: de 2,23 a 1,46 s, de los que unos 0,55 s son la espera inicial, que no cambia. La pantalla final queda idéntica.
- **Joystick:** `BRAKE` intercambia los bits de acelerar (3) y de marcha (4) cuando se juega con joystick (AF3Eh ≠ 0). Así el disparo acelera, arriba cambia de marcha y abajo frena.
- **Choques con rivales** (9098h → `VISHIT`):
  - El original da por pegado a ti a todo rival a menos de 0Ch de fondo y compara el lateral en la carretera a la altura del rival. Pero tu coche se pinta abajo, y en las curvas ese rival sale muy a un lado.
  - Ahora, además, se calcula con la rutina de proyección (A05Dh) la columna donde se dibuja el rival. Solo hay choque si toca las columnas de tu coche (110-155).
  - Los rivales que ya están a tu lado o detrás, que no se dibujan, chocan como antes.
- **Lluvia** (sin cambios, para quien tenga curiosidad): al empezar cada carrera, salvo en el primer circuito, el juego hace `ld a,r / and 28h`. Sale lluvia un 25 % de las veces. Empieza a una distancia de 1.024 a 1.372 unidades y dura 8.000. Sin neumáticos de lluvia se pierde un cuarto de la velocidad.

## 7. Pantalla final

- La de la cinta era la pantalla del Spectrum con sus atributos de 8x8.
- La nueva sale de la ilustración del podio de la recreativa (Taito):
  - `herramientas/pantalla_final/screen2_desde_imagen.py` hace un recorte, la reduce a 256x176, la enfoca y busca en cada tramo de 8x1 el mejor par de colores en el espacio Lab, con poca difusión de error.
  - Encima va el letrero «YOU'RE AN F1 CHAMPION!» de la pantalla original.
  - araubi la retocó a mano (`final_retocada.png`).
- `screen2_desde_png.py` pasa el PNG retocado a SCREEN 2 (`rom/final.scr`, 6144 bytes de patrones y 6144 de color) y lista los tramos que tengan más de dos colores.
- En la ROM: FB03h llama a `FINAL` (FD4Ch) en vez de a 0701h. `FINAL` copia E000h a 4000h como el original, quita los sprites, vuelca los bancos 20-21 a la VRAM y espera una tecla.

## 8. Pruebas

- **Emulador de pruebas** (`fuentes/emu/`): MSX1 mínimo en C con trampas de cinta, para sacar la imagen de memoria y comparar el volcado nuevo con el original.
- **openMSX** con C-BIOS (MSX1, MSX2 y MSX2+) mediante los scripts de `fuentes/pruebas/`:
  - `t17.tcl` cuenta las imágenes en 20 s.
  - `t26.tcl` graba el freno.
  - `joystick.tcl` fuerza la lectura del PSG R14 (breakpoint tras el `in a,(0A2h)` de 055Fh).
  - `pantalla_final.tcl` salta directamente a la pantalla final.
- **Grabaciones `.omr` de araubi** (`herramientas/omr/`): se restauran la RAM, la VRAM y los registros de una instantánea y se repiten las teclas. Así se reprodujo el choque a distancia y se comprobó el arreglo.
- **Probado por araubi** en turbo R y en el Sony HB-20P (emulado).
