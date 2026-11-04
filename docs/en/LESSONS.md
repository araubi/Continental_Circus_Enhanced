# Lessons from Continental Circus Enhanced

What this project taught that may help with other MSX games, especially Spectrum ports that came on tape.

## 1. From tape to MegaROM

1. **The whole RAM in the ROM.** The state of the game once loaded (64 KB) is stored in banks 1-8 and the VRAM in banks 9-10. Boot code in bank 0 copies it all to RAM and jumps to the game. Later tape loads (here the circuits) become an `ldir` from their bank. Free banks are left for extras, such as the final screen.
2. **The loader is no longer needed:** the space of the tape loader (FB03h) is a good place for resident hooks.

## 2. Speeding up

1. **Measure before promising.** Two speed estimates (a faster copy on MSX2 and skipping the asphalt) turned out wrong once measured.
2. **The MSX1 ceiling is the VDP:** about 29 cycles per byte with the display on. An MSX2 does not shorten that loop if the buffer is laid out by lines and the VRAM by cells.
3. **Turbo R almost for free:** at boot, if `(002Dh) ≥ 3`, `ld a,81h / call 0180h` (CHGCPU: R800 in ROM mode).
4. **Clock per frame:** when speeding up a game that counts time with interrupts, tie the clock to the frame so the difficulty does not change. Here it was measured in tenths of TIME per frame: 1.050 against 1.045-1.050 in the original.

## 3. Reproducing a bug from an openMSX `.omr` recording

1. `omr_extrae.py` takes RAM, VRAM, the VDP and Z80 registers and the key matrix from each snapshot.
2. `omr_a_tcl.py N` writes a `rest.tcl` that boots C-BIOS with the ROM and, after 3 s, writes RAM, VRAM and registers (`debug write_block "Main RAM"`, `debug write "VDP regs"`, `reg ...`). It then presses the keys that were held and schedules the `KeyMatrixState` events with `after time`.
3. **To test a fix with the same recording,** copy the new code on top of the restored RAM, because the recording carries the old code.
4. **Also test with the original code:** remove what was added (here the sprites) and see whether the original does the same before looking for the bug in your own code. The "long-distance crash" turned out to be in the original game.

## 4. Crashes in pseudo-3D racing games

The original compares rival and player in road coordinates at the rival's depth, but your own car is drawn at the bottom. On bends and crests you crash into cars that look far away and to one side. Fix: also require the rival's picture, placed with the projection routine, to touch your car's columns on screen.

## 5. Rivals as sprites on a bitmap game

- Small ones: fixed patterns per picture.
- Large ones: dynamic patterns in free slots, only one at a time, with its silhouette in the bitmap.
- Four-sprites-per-line limit: send the large one first.

## 6. Sound

- Effects from another game (here Hyper Rally) can be used by grouping frames to match the game's interrupt rate. This one runs with DI almost all the time and services about 19 per second.
- Music quantised to the arcade's timing grid (tick and unit per song). If the songs are regenerated, the length table must be regenerated too.

## 7. Still screens from the arcade

- `screen2_desde_imagen.py`: crop, scale, sharpen and, for each 8x1 run, the best colour pair in Lab with low error diffusion (0.15). The result is recognisable, but it is worth retouching by hand.
- `screen2_desde_png.py`: turns the retouched PNG into SCREEN 2 and lists the runs with more than two colours. When a retouch comes in, report how many runs were corrected and where.
- A title copied from a Spectrum screen brings Spectrum colours with it: map them to the MSX palette.

## 8. Testing without hardware

- **Joystick:** a breakpoint right after the `in a,(0A2h)` that reads PSG register 14, then `reg a value` (FFh nothing, EFh fire, FEh up, FDh down).
- **Screens that are hard to reach:** jump to the routine with `reg pc` and its input registers.

## 9. Tcl pitfalls in openMSX

- `[debug read_block ... | binary encode hex]` is not Tcl: the breakpoint callback fails **silently**. Use `[binary encode hex [debug read_block memory addr n]]`.
- In scripts generated from Python or a heredoc, do not leave `\$` inside braces.
- Test on European MSX1 and MSX2: the same timed key presses may not start the game on another machine, and that is not a ROM bug.

## 10. Randomness from the R register

The game decides the rain with `ld a,r / and 28h`. Searching for `ld a,r` is the quick way to find random decisions.
