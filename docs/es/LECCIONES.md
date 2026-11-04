# Lecciones de Continental Circus Enhanced

Lo aprendido en este proyecto que puede servir en otros juegos MSX, sobre todo en ports de Spectrum que venían en cinta.

## 1. De cinta a MegaROM

1. **La RAM entera en la ROM.** Se guarda el estado del juego ya cargado (64 KB) en los bancos 1-8 y la VRAM en los bancos 9-10. Un arranque en el banco 0 lo copia todo a la RAM y salta al juego. Las cargas posteriores de la cinta (aquí los circuitos) se cambian por un `ldir` desde su banco. Quedan bancos libres para extras, como la pantalla final.
2. **El cargador ya no hace falta:** el sitio del cargador de cinta (FB03h) es un buen lugar para los enganches residentes.

## 2. Acelerar

1. **Medir antes de prometer.** Dos estimaciones de velocidad (un volcado más rápido en MSX2 y saltar el asfalto) resultaron falsas al medirlas.
2. **El techo del MSX1 es el VDP:** unos 29 ciclos por byte con la pantalla activa. Un MSX2 no acorta ese bucle si el búfer está por líneas y la VRAM por celdas.
3. **Turbo R casi gratis:** en el arranque, si `(002Dh) ≥ 3`, `ld a,81h / call 0180h` (CHGCPU: R800 en modo ROM).
4. **Reloj por imagen:** si se acelera un juego que cuenta el tiempo con interrupciones, hay que fijar el reloj por imagen para que la dificultad no cambie. Aquí se midió en décimas de TIME por imagen: 1,050 frente a 1,045-1,050 del original.

## 3. Reproducir un fallo con una grabación `.omr` de openMSX

1. `omr_extrae.py` saca de cada instantánea la RAM, la VRAM, los registros del VDP y del Z80 y la matriz de teclas.
2. `omr_a_tcl.py N` genera un `rest.tcl` que arranca C-BIOS con la ROM y, a los 3 s, escribe la RAM, la VRAM y los registros (`debug write_block "Main RAM"`, `debug write "VDP regs"`, `reg ...`). Después pulsa las teclas que estaban pulsadas y programa los `KeyMatrixState` con `after time`.
3. **Para probar un arreglo con la misma grabación** hay que copiar el código nuevo encima de la RAM restaurada, porque la grabación lleva el código viejo.
4. **Probar también con el código original:** quitar lo añadido (aquí los sprites) y ver si el original hace lo mismo antes de buscar el fallo en lo nuestro. El «choque a distancia» resultó ser del juego original.

## 4. Choques en carreras pseudo-3D

El original compara rival y jugador en coordenadas de carretera a la altura del rival, pero el coche propio se pinta abajo. En curvas y rasantes se choca con coches que se ven lejos y a un lado. Arreglo: exigir además que el dibujo del rival, calculado con la rutina de proyección, toque las columnas del coche propio en pantalla.

## 5. Rivales en sprites sobre un juego de mapa de bits

- Pequeños: patrones fijos por imagen.
- Grandes: patrones dinámicos en huecos libres, uno solo a la vez, con su silueta en el mapa de bits.
- Límite de cuatro sprites por línea: mandar primero el grande.

## 6. Sonido

- Se pueden usar efectos de otro juego (aquí Hyper Rally) agrupando cuadros al ritmo de interrupciones del juego. Este va casi todo con DI y atiende unas 19 por segundo.
- Músicas cuadradas a la rejilla de la recreativa (tick y unidad por canción). Si se regeneran, hay que regenerar también la tabla de duraciones.

## 7. Pantallas fijas desde la recreativa

- `screen2_desde_imagen.py`: recorte, reducción, enfoque y, en cada tramo de 8x1, el mejor par de colores en Lab con difusión de error baja (0,15). Sale reconocible, pero conviene retocarla a mano.
- `screen2_desde_png.py`: pasa el PNG retocado a SCREEN 2 y lista los tramos con más de dos colores. Al recibir un retoque, conviene avisar de cuántos tramos se corrigieron y dónde.
- Un letrero copiado de una pantalla de Spectrum trae colores del Spectrum: hay que pasarlos a la paleta del MSX.

## 8. Probar sin hardware

- **Joystick:** breakpoint justo después del `in a,(0A2h)` que lee el registro 14 del PSG y `reg a valor` (FFh nada, EFh disparo, FEh arriba, FDh abajo).
- **Pantallas difíciles de alcanzar:** saltar a la rutina con `reg pc` y los registros de entrada.

## 9. Trampas de Tcl en openMSX

- `[debug read_block ... | binary encode hex]` no es Tcl: la llamada del breakpoint falla **en silencio**. Hay que usar `[binary encode hex [debug read_block memory dir n]]`.
- En scripts generados desde Python o con heredoc, no dejar `\$` dentro de llaves.
- Probar en MSX1 y MSX2 europeos: las mismas pulsaciones por tiempo pueden no arrancar la partida en otra máquina, y no es un fallo de la ROM.

## 10. Azar con el registro R

El juego decide la lluvia con `ld a,r / and 28h`. Buscar `ld a,r` es la forma rápida de encontrar las decisiones al azar.
