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

### 2.1. v1.1: unrolled screen copy and incremental score panel

Measured with `pruebas/t17.tcl` in openMSX (C-BIOS), frames in 20 s while driving:

| | v1.0 | unrolled screen copy | + incremental score panel |
|---|---|---|---|
| MSX1 | 144 | 149 | 153 (+6 %) |
| MSX2 | 144 | 154 | 158 (+10 %) |

- **Unrolled screen copy** (`blit3.asm`, `FASTROW`):
  - The previous loop spent 32 cycles between bytes of a column, but the column change (PUSH, POP, INC, DJNZ) raised the average to about 36.
  - A row of 8 lines is 256 bytes. The road rows (E400h + 256·row), `TEMP` (1300h) and the sky block (1400h) start at a multiple of 256, so within a row H does not change and L is column + 32·line.
  - `FASTROW` is 256 times `ld l,n / outi`: 26 cycles per byte. On MSX1 it also has a `nop` (31 cycles), because the TMS9918 needs 29 between writes.
  - It is not in the ROM: the boot code generates it in RAM (`GENFAST`, bank 0) according to `(002Dh)`, in two pieces, 1C00h-1FFFh and 3AE0h-3BFFh.
  - Full rows of the horizon strip (E200h, not aligned) still go through the previous loop.
- **Incremental score panel** (`glyph.asm`):
  - A 128-byte cache (1900h, the area of the boot copier) stores which character each cell of rows 0-3 shows. If the cell already shows it, nothing is written to VRAM.
  - The other routines that write there (RST 10h on its own, 0520h, 0743h, 0A69h and the final screen) set `HUDINV`, and the cache is cleared before it is used again.
  - It gains less than estimated (2-3 %): what is left is building the strings and turning the BCD into digits.
- **Hooks:** `hook743`, `hook520` and `hookA69` move to 1036h, the gap left by the original screen copy, to make room at 1500h.
- **Check:**
  - 551 screen copies on MSX1 and 591 on MSX2: the VRAM of the play area matches the buffers in all of them (on MSX2 openMSX emulates VRAM access that is too fast; on MSX1 it does not, and that is where the 31-cycle margin matters).
  - 576 score panels compared digit by digit with an independent drawing: all the same.
  - 200 s of play, tables, menu and a second game with write watchpoints: the game does not touch 1036h-115Fh, 1900h-197Fh, 1C00h-1FFFh or 3785h-3BFFh.
  - With the real BIOSes (openMSX's `msx1`, `msx2`, `msx2plus` and `turbor`), 100 timed frames while racing: from 7.56 to 8.12 per second on MSX1, from 7.56 to 8.50 on MSX2, from 7.49 to 8.42 on MSX2+ and from 18.80 to 19.56 on turbo R. On turbo R, 595 screen copies identical to the buffers.
  - Not yet tested on a real machine.

### 2.2. Frame profile and two more screen copy improvements

Profile with openMSX breakpoints in the race loop (MSX1, 143 frames, about 500,000 cycles per frame in that stretch):

| Routine | Cycles | % |
|---|---|---|
| 8B3Fh screen copy | 180,000 | 36 |
| 9571h road | 116,500 | 23 |
| A0D2h objects and rivals | 72,900 | 15 |
| 9277h, 92E6h, 93BDh, 91A0h logic | 94,000 | 19 |
| AE84h score panel | 14,700 | 3 |
| 8AB9h | 8,600 | 2 |
| rest (controls, crashes, clock) | 13,000 | 2 |

- **The screen copy, by row type:** road rows take 114,500 cycles (14.3 rows at 8,000, that is, 31 cycles per byte: the VDP limit). The rest was sky being resent for no reason.
- **Sky with the horizon moving** (`skysk`): before, if the horizon strip scrolled (B50Ah ≠ 0) or `n1` changed, everything was resent. The sky is FFh whether the strip moves or not, so the rows that were and still are sky, min(`n1`, `ln1`), are no longer resent.
- **PIT IN sign** (`hookpit`): with the car damaged the game draws the sign (16E7h, rows 5 and 6) in almost every frame, and going through 0520h set `FORCE`: all 20 rows were resent every frame. Now its two calls (16EEh and 172Ch) go to `hookpit`, which does not set `FORCE`. The sign stays in VRAM as long as those rows are not resent (it no longer flickers), and the screen copy resends them once when the game stops drawing it (`pitnow`, `pitvram`, `pitdel`).
- **Measured:** with the car damaged, from 7.01 to 7.71 frames per second on MSX1 and from 7.37 to 8.04 on MSX2. Without damage, `t17.tcl` gives 155 (MSX1) and 162 (MSX2) frames in 20 s.
- **Check:** 589 screen copies on MSX1 and 588 on MSX2 identical to the buffers (leaving out the sign while it is on screen), with 4 removals of the sign in each run.
- **What is left:**
  - Road (9571h): done, see 2.3.
  - Objects and rivals (A0D2h): the drawing routine (9DB6h) is already unrolled with a mask table, about 67 cycles per byte. It depends on how many objects there are.
  - Logic (9277h, 92E6h, 93BDh): 100-line loops with tables and PUSH, with nothing obvious to remove.

### 2.3. Road: setting up each segment

The road generator (9571h) goes through the segment table (D600h: lines of each segment; D800h: four bytes with the edges and their patterns) and, for each one, sets up the PUSH machine at 9694h, which is what writes the lines into the buffer. There are about 100 segments per frame. The PUSHes have not been touched; the setup is rewritten in place (`ccrom.asm`, `hk_9571.bin` and `hk_96f2.bin`):

- The four bytes of the segment and the left edge pattern are read with POP (the stack pointer was already hijacked and interrupts are disabled), instead of with six accesses through IY.
- The phase counter for drawing the edges lives in C' and not in memory (it used to be the operand at 95B1h).
- The pattern table addresses (D000h) are built with 8-bit rotations and stored two bytes at a time.
- The line's `ld sp,hl / add hl,de` is done at the end, just before jumping to the PUSHes.
- It leaves the same as the original in the unusual cases too: DE and H in segments without edges, and the table addresses untouched when they are not used. The left edge uses D400h with bit 2 of the segment and the right one D200h, as in the original.
- The copy of 96D0h-9707h found at 7B30h is a leftover among graphics data: nothing calls it.

- **Measured** (openMSX real BIOSes, 100 frames while racing): from 8.27 to 8.63 frames per second on MSX1, from 8.64 to 9.03 on MSX2 and from 20.56 to 20.97 on turbo R. `t17.tcl` (C-BIOS): 162 (MSX1) and 169 (MSX2) frames in 20 s. The routine goes from 110,000 to 93,600 cycles per frame (15 % less).
- **Check:** differential test with the emulator in `fuentes/emu/`: the RAM was captured on entering 9571h in 589 frames of a race in openMSX, and the original and new routines were run on each state. Memory ends up identical in all 589, and also in 4,711 variants with the segment tables randomly altered (edges, widths, patterns and lines), which run all the new instructions. On return, only registers that the race loop reloads before using change (HL, C', IX and the flags). Also, 611 screen copies on MSX1, 591 on MSX2 and 600 on turbo R identical to the buffers.

### 2.4. Panasonic MSX2+ turbo

The FS-A1FX, FS-A1WX and FS-A1WSX can set the Z80 to 5.37 MHz from software. The boot code (`INIT`, bank 0) enables it if it finds it: it selects device 8 of the switched I/O ports (`out (40h),8`), checks that 40h returns F7h and that bit 2 of 41h is zero (turbo present), and writes 0 to 41h. On any other machine nothing changes.

- **Measured in openMSX** (100 frames while racing): 11.41 frames per second on all three models, against 9.03 without turbo (26 % more). The FS-A1F (an MSX2 with the same device but no turbo) stays at 9.03, like any MSX2.
- **VDP:** the screen copy still runs at 26 cycles per byte; with the turbo on, the machine itself spaces out VDP accesses (openMSX emulates this). 590 screen copies on the FS-A1WX identical to the buffers.
- **Sound:** its pace does not change: the game still services about 22 interrupts per second while racing, the same as without turbo.
- **Not tested on a real machine.**

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
- **Without the tapes:** `construir_desde_rom.py` starts from the published ROM (RAM image, VRAM, circuits and final screen) and applies all the assembled patches on top again. With the v1.0 sources it comes out identical to v1.0. With the v1.1 sources it plays the same as v1.1, but keeps 33 bytes of v1.0 in gaps nothing uses any more (1193h-119Fh and 16C6h-16DAh). The v1.1 in `releases/` was built from the tapes with `construir.py`.
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
- **Redefinable brake key** (v1.1; `REDEF` in `ccrom.asm`):
  - v1.0 read cursor down directly (row 8, bit 6), and "Define keys" (AD0Ch → 0B70h) only asked for the six keys of the original.
  - Now AD0Ch goes to `REDEF`, which asks for seven: LEFT, RIGHT, PAUSE, ACCELERATOR, BRAKE, GEAR CHANGE and QUIT. The usual six are still at 17F4h-17FFh (mask and row, six bytes apart) and the brake at `BRKMSK`/`BRKROW`, which is what `BRAKE` reads.
  - Checked in openMSX: all seven keys are saved, the new one brakes and cursor down no longer brakes; without redefining, braking is identical to before.
- **Speed on turbo R** (v1.1; `SPDWAIT`, `MENUSPD` and `MENU4` in `ccrom.asm`):
  - The logic advances one step per frame, so at the R800's 21 frames per second everything runs almost twice as fast as on an MSX2+ with turbo.
  - `RACEFR` (8323h, once per race frame) calls `SPDWAIT`: it waits, with DI, for the turbo R timer (ports E6h/E7h; E7h advances almost 1 ms per unit) to reach the chosen minimum, and resets it to zero.
  - It is chosen with key 4 in the menu, which only appears on turbo R, on the "4. Kempston Joystick" line that the original did not draw (A835h → `MENUSPD`, A889h → `MENU4`): `Normal` 88 ms (11.35 frames per second, like an MSX2+ with turbo), `Fast` 66 ms (15.1) and `Max` with no limit (21.0). It starts in `Normal`.
  - Sound effects follow the rate of serviced interrupts: about 25 per second in `Normal` and `Max` (22 on an MSX2) and about 34 in `Fast`, where they play somewhat faster.
  - What has not been done: keeping the `Normal` game speed while drawing 21 frames per second. Everything the logic adds per frame would have to be rescaled (movement, acceleration, steering, rivals, clock, timers); the speed alone is read or written in 21 places.
- **Same waits on every machine** (v1.1; `R18` in `ccrom.asm`):
  - Outside a race the game measures time with RST 18h (0C89h): an LDIR of 3,000 bytes onto itself, 17.6 ms on a Z80 at 3.58 MHz. It is used by the start lights (8822h, 50 loops per light), the continue countdown (A7F1h, 500 loops), the initials (AC78h and 0C82h), the menu (ABF1h) and the map (0BD1h). With the R800 or the Panasonic turbo all of that sped up.
  - Now 0C89h jumps to `R18`: on turbo R it waits 20 ms with the timer (E7h); with the Panasonic turbo the LDIR copies 4,500 bytes; on the rest nothing changes.
  - Measured in openMSX, each start light: 1.00 s on MSX1, 1.00 s on turbo R (0.17 before) and 0.99 s on the FS-A1WX with turbo (0.66 before). Continue countdown: 11.4 s on MSX1, 10.6 s on turbo R (2.3 before) and 10.8 s on the FS-A1WX (7.7 before).
  - The initials screen uses the same wait, but it has not been timed (it needs getting into the table).
- **Gear indicator** (v1.1; `GEARDRAW` in `ccrom.asm`):
  - The original already had one: 8C84h draws a non-bold `1` or `2` in the first cell of the score panel, before `TOP`, when 8CB7h flips the gear (B507h: 0 low, FFh high). It is hard to see.
  - Now it is a label on row 3 of the score panel, which was empty: `GEAR` and `LOW` in white on green or `HIGH` in white on red. The fixed `1` of the `1 TOP` string (A66Ch) is removed.
  - It is written straight to VRAM (patterns at 0300h, colours at 2300h) only when needed: when the gear changes (8C84h → `GEARDRAW`) and, at the end of each screen copy (`SATW` → `GEARCHK`), if the gear is not the one drawn or the game has redrawn the score panel or its colours (`GEARINV`, set by `hook520`/`hook743`).
- **Bump and crash** (v1.1; game routine 8356h, `GEARLOW` and `CRASHEND` in `ccrom.asm`):
  - In the original, a crash disables the controls (B50Eh = 0) for 70 frames, about 9 s: 33 spinning (about 8 turns), 7 stopped and 30 returning to the centre. Only at the end does it set low gear, and if the gear key is still held at that moment it takes it as a new press and goes back to high.
  - Now low gear is set at once, on a bump (8379h) and on a crash (83C0h).
  - The crash lasts 16 frames, about 2 s: one 360° spin and the return to the centre. The limits of each phase (83ECh, 83FAh, 83FDh) and the braking per frame (83DBh, from 20 to 80 km/h) are the `CR_*` constants.
  - On resuming (8442h → `CRASHEND`) the car is stopped and a held gear key does not count.
  - Measured in openMSX by forcing the hit (B513h = C0h): 69 frames and 9.7 s in v1.0, 17 frames and 2.0 s now.
- **End-of-race map** (v1.1; `MAPSTEP` and `MAPNIB` in `ccrom.asm`):
  - The loop at A78Ch draws the stretch covered step by step, and after each step calls 0801h, which converts the 768 attributes to the VRAM colour table (about 0.14 s each time).
  - Now 0801h is called every other step, and always on the last one (0B26h → `MAPSTEP`) or when the track runs out (A7A5h → `MAPNIB`).
  - Measured with 12 steps: from 2.23 to 1.46 s, of which about 0.55 s is the initial wait, which does not change. The final screen is identical.
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
