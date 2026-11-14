# Pruebas con openMSX

Scripts usados para medir y comprobar los cambios posteriores a la v1.0. Todos corren sin ventana:

```
cd fuentes/pruebas
. addr.sh                      # direcciones del volcado (salen de prototipo3/blit3.sym)
ROM=../ContinentalCircus_Enhanced.rom
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy openmsx -machine msx1 -cart $ROM -script fps.tcl
```

Máquinas: `C-BIOS_MSX1`, `C-BIOS_MSX2` o, con las ROM de sistema, `msx1`, `msx2`, `turbor`,
`Panasonic_FS-A1WX`… Los que guardan ficheros usan la variable `OUT` (un directorio, o un fichero en
`cap.tcl`).

| Script | Qué hace |
|---|---|
| `fps.tcl`, `fpsi.tcl` | Imágenes por segundo en carrera (100 imágenes); `fpsi` añade las interrupciones atendidas. Pulsan RETURN hasta que arranca la partida, así que valen con cualquier BIOS. |
| `fpsd.tcl` | Lo mismo con el coche dañado (letrero PIT IN). Variable `OLD`=1 para la v1.0. |
| `t17_sin_pantalla.tcl` | `t17.tcl` (imágenes en 20 s) sin ventana. Solo arranca bien con C-BIOS. |
| `vfy2.tcl`, `vfy2r.tcl` + `vfy3.py` | Guardan la VRAM y los búferes al acabar cada volcado y los comparan: `python3 vfy3.py $OUT/frames.bin`. `vfy2r` es la variante para BIOS reales. |
| `hud4.tcl` + `hudvfy.py` | Lo mismo para el marcador. |
| `cap.tcl` + `diff.py` | Prueba diferencial del generador de carretera (ver la cabecera de `diff.py`). |
| `prof.tcl` | Perfil de ciclos por rutina del bucle de carrera. |
| `r18.tcl` | Esperas de RST 18h por llamador, semáforo y menú (variable `TMAX`, segundos). |
| `menu.tcl`, `redef.tcl`, `brk.tcl` | Opción 4 del menú, redefinición de teclas y freno. |
| `gear.tcl`, `crash.tcl`, `map.tcl` | Rótulo de marcha, accidente (`HIT`, `HOLD`, `VERB`) y mapa de fin de carrera. |
| `wp.tcl` | Vigila escrituras del juego en la RAM que usan los parches. |
| `render.py` | Pasa un volcado de VRAM a PNG sin Pillow: `python3 render.py 24 vram.bin`. |
| `dis.py` | Desensambla rangos de la imagen de RAM: `python3 dis.py $ROM 9571-9710`. |

Ojo: `menu.tcl`, `redef.tcl` y `fpsi.tcl` llevan direcciones de variables de `ccrom.asm` (`SPDSEL`,
`ISTR`, `BRKMSK`, `BRKROW`) que cambian si se mueve el código: están en `rom/cc.sym`.
