# Continental Circus Enhanced: technical documentation

Development notes for the enhanced version (October 2026). Addresses refer to the game's memory once loaded. Folder and file names in the repository are in Spanish.

## 1. The original

- **Two-sided tape.** Side A holds a BASIC loader (`10 SCREEN 2:BLOAD"cas:",R`), the `alicia` loader (E000h-E2FFh) and Spectrum-style blocks (FFh flag + data + XOR) read with TAPION/TAPIN:
  - 8000h-9CC7h: loading screen.
  - 0400h-17FFh: the MSX layer of the port (VDP, keyboard, joystick and tape).
  - 3C00h-3FFFh: the font, as in the Spectrum ROM.
  - 5B00h-FFFDh: the game, which starts at 81A0h.
- **Side B:** `TRACK1` to `TRACK9`, the circuits, loaded during play. Number 9 is the final screen, a 6912-byte Spectrum screen.
- **Display:** SCREEN 2 with the name table 0-255 three times, used as a bitmap.
  - The play area (rows 4 to 23, 160 lines) is drawn into a linear buffer at E400h, 32 bytes per line.
  - Every frame is copied to VRAM line by line (1033h). In SCREEN 2 the bytes of one line are 8 positions apart, so it sets the address for every byte: about 96 cycles per byte.
  - The score panel is reprinted in full every frame through RST 10h (about 490 cycles per byte).
  - There is a fixed delay of about 63,000 cycles per frame.
- **Speed:** 3.8 frames per second while racing on MSX1, about 920,000 cycles per frame.
- **Clock:** the interrupt adds to 8A0Eh only half of the time, and the game runs with DI almost all the time. In practice the clock advances per frame.

## 2. Speed: prototype 3 (`fuentes/prototipo3/`)

Applied to side A with `mkcas.py`, which recomputes the block XORs.

- **New screen copy** (`blit3.asm`, at 1500h; 1033h jumps to it):
  - Goes column by column in VRAM order and uses the auto-increment.
  - Rows with only sky and horizon are not resent if they have not changed.
  - A few hooks (0520h, 0743h, 0A69h, RST 10h) force a full copy when another routine writes into the play area.
- **Score panel** (`rst10.asm`, `glyph.asm`): RST 10h writes straight to VRAM, without the address conversion routines, and characters use a single address per cell. From 131,000 to 25,000 cycles per frame.
- **No fixed delay** (8940h = NOP): removes the RST 18h wait from the race frame, about 69,000 cycles.
- **Clock per frame:** the screen copy adds to the clock what the original added on average, so a race lasts the same number of frames. Measured: 1.050 tenths of TIME per frame, against 1.045-1.050 in the original.
- **Check:** 5,083 screen copies from automatic games, identical to the full copy.
- **Result:** about 480,000 cycles per frame, 7.25 frames per second while driving (145 in 20 s in openMSX), on MSX1, MSX2 and MSX2+.
- **Ceiling:** the copy loop already runs at about 29-32 cycles per byte, the minimum the MSX1 VDP accepts with the display on. An MSX2 does not shorten it, because the buffer is laid out by lines and the VRAM by cells. Skipping the asphalt was measured at only 5 %.

## 3. The ROM (`fuentes/rom/`)

256 KB ASCII8 MegaROM, put together by `mkrom.py`:

| Banks | Contents |
|---|---|
| 0 | Boot code (`ccrom.asm`) |
| 1-8 | The 64 KB of RAM of prototype 3 on reaching 81A0h, with the new hooks |
| 9-10 | VRAM (with the sprite patterns at 3800h) |
| 11-19 | `TRACK1` to `TRACK9` from side B |
| 20-21 | Final screen in SCREEN 2 |

- **RAM image:** `snap.py` loads the patched tape in the test emulator (`fuentes/emu/`) up to 81A0h and saves RAM and VRAM.
- **Boot:**
  - Finds the RAM slot of page 3 and selects it on all four pages (with subslot when needed).
  - Copies banks 1-8 to RAM with a copier at 1900h, an area the game does not load.
  - On turbo R, if `(002Dh) ≥ 3`, it calls CHGCPU (0180h) with 81h: R800 in ROM mode.
- **Circuits:** FB03h, the tape loader, calls FD01h. That routine puts the ROM on page 1, copies the circuit's bank to E000h and switches back to RAM.
- **Mapper:** the code has 21 writes to ASCII8 registers (8 Konami, 9 ASCII16), so openMSX and BlueMSX detect it automatically.

## 4. Sound

- **Interrupt:** the game services it about 19-20 times per second while racing (the rest of the time it runs with DI). The player hooks the end of 0582h (0599h → `SNDINT`).
- **Engine** (channel A): the formula from Hyper Rally (Konami, 1985). Hyper Rally speed is the speed here × 0.72, and the period depends on gear and throttle. Gear in B507h, throttle in bit 3 of B501h, speed in B504h. The race loop (8323h → `RACEFR`) keeps it alive; it falls silent by itself when paused or outside a race.
- **Effects** (8A15h → `SFXREQ2`, priority crash > bump > extra time > overtaking > brake):
  - Bump (10h) and crash (0Eh): Hyper Rally effects 42h and 4Ch, extracted with the tools from antxiko's disassembly and grouped three frames at a time to match the interrupt rate.
  - Extra time (0Ch): Hyper Rally effect 07h.
  - Overtaking (0Fh): `SFXPASO`, a rush of air and the rival's engine dropping in pitch (`herramientas/sonido/adelantar.py`).
  - Brake: Hyper Rally effect 46h.
  - Qualified, not qualified and champion fanfares: Hyper Rally effects 94h, 0Bh and 9Ah converted to the song format.
- **Start lights** (87D7h → `SEMBEEP`): a short beep for each red light and a longer, higher one for green.
- **Map music** (A76Ah → `MAPMUS`):
  - The eight arcade tunes, transcribed, arranged for three voices and drums, and quantised to the arcade's timing grid (`fuentes/musica/`).
  - `.song` format: four offsets (voices A, B and C and drums), (note, length) pairs and simple envelopes.
  - The player runs at 60 ticks per second and adds 12 instead of 10 at 50 Hz, so the tempo is the same. A key or the fire button stops the music.

## 5. Rivals as sprites

- **Medium and small** (pictures 9-23 of table C477h):
  - 9CE0h → `SPRCAR`. Only the black silhouette is left in the buffer: routine 9DB6h runs with its `OR C` instructions replaced by NOP.
  - On top goes a 16x16 sprite coloured by rival: red, light blue, yellow, green or magenta.
  - `gensp.py` builds the patterns and pieces from the game's own pictures.
- **Large** (pictures 0-8, next to the player): dynamic patterns in slots 52-63, only the first one in each frame. `BIGSAT` uploads its patterns at the end of the screen copy, only when the picture has changed.
- **Sprite table:** uploaded at the end of the screen copy (166Dh → `SATW`), near to far, with the large car first so it wins against the four-sprites-per-line limit.
- **Outside a race:** 0743h and 0A69h call `SPHIDE`, which removes the sprites.
- **Cost:** the speed did not change (145 frames in 20 s).

## 6. Gameplay

- **Brake** (8C9Dh → `BRAKE`): with cursor down or joystick down, it releases the throttle and takes 8 km/h off per frame.
- **Joystick:** `BRAKE` swaps the throttle bit (3) and the gear bit (4) when playing with the joystick (AF3Eh ≠ 0). So fire accelerates, up changes gear and down brakes.
- **Crashes with rivals** (9098h → `VISHIT`):
  - The original treats any rival less than 0Ch deep as right next to you and compares the lateral position on the road at the rival's depth. But your car is drawn at the bottom, and on bends that rival appears far to one side.
  - Now the column where the rival is drawn is also computed with the projection routine (A05Dh). There is a crash only if it touches your car's columns (110-155).
  - Rivals already beside or behind you, which are not drawn, crash as before.
- **Rain** (unchanged, for the curious): at the start of each race, except on the first circuit, the game does `ld a,r / and 28h`. It rains 25 % of the time. Rain starts at a distance of 1,024 to 1,372 units and lasts 8,000. Without rain tyres you lose a quarter of your speed.

## 7. Final screen

- The one on the tape was the Spectrum screen with its 8x8 attributes.
- The new one comes from the arcade's podium artwork (Taito):
  - `herramientas/pantalla_final/screen2_desde_imagen.py` crops it, scales it to 256x176, sharpens it and picks the best colour pair for each 8x1 run in Lab space, with little error diffusion.
  - The "YOU'RE AN F1 CHAMPION!" title from the original screen goes on top.
  - araubi retouched it by hand (`final_retocada.png`).
- `screen2_desde_png.py` turns the retouched PNG into SCREEN 2 (`rom/final.scr`, 6144 bytes of patterns and 6144 of colour) and lists any run with more than two colours.
- In the ROM: FB03h calls `FINAL` (FD4Ch) instead of 0701h. `FINAL` copies E000h to 4000h like the original, removes the sprites, copies banks 20-21 to VRAM and waits for a key.

## 8. Testing

- **Test emulator** (`fuentes/emu/`): a minimal MSX1 in C with tape traps, used to take the memory image and to compare the new screen copy with the original.
- **openMSX** with C-BIOS (MSX1, MSX2 and MSX2+), using the scripts in `fuentes/pruebas/`:
  - `t17.tcl` counts frames in 20 s.
  - `t26.tcl` records the brake.
  - `joystick.tcl` overrides the PSG R14 reading (breakpoint after the `in a,(0A2h)` at 055Fh).
  - `pantalla_final.tcl` jumps straight to the final screen.
- **araubi's `.omr` recordings** (`herramientas/omr/`): RAM, VRAM and registers are restored from a snapshot and the keys are replayed. That is how the long-distance crash was reproduced and the fix checked.
- **Tested by araubi** on turbo R and on the Sony HB-20P (emulated).
