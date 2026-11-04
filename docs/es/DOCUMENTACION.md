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
