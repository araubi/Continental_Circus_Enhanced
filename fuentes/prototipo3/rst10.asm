; RST 10h rápido: escribe A en la dirección de pantalla Spectrum DE (4000h-57FFh) de la VRAM SCREEN 2.
; Mismo contrato que 0CB9h del port (conserva todos los registros, deja EI), sin pasar por 05E4h/0520h.
        INCLUDE "vars.inc"
        OUTPUT "rst10.bin"
        ORG 1160h
rst10:  push af
        push hl
        ld a,e                  ; H = tercio*8 + fila  (d&18h | e>>5)
        rlca
        rlca
        rlca
        and 7
        ld h,a
        ld a,d
        and 18h
        or h
        ld h,a
        cp 4                    ; fila >= 4: zona de juego, el volcado no puede saltarse filas
        jr c,.hud
        ld (FORCE),a            ; blit3
        jr .go
.hud:   ld a,0FFh               ; filas 0-3: la caché del marcador de glyph.asm ya no vale
        ld (HUDINV),a
.go:
        ld a,e                  ; L = columna*8 + línea (e<<3 | d&7)
        add a,a
        add a,a
        add a,a
        ld l,a
        ld a,d
        and 7
        or l
        di
        out (99h),a
        ld a,h
        or 40h
        out (99h),a
        ei
        pop hl
        pop af
        out (98h),a
        ret
rst10_end:
        ASSERT rst10_end <= 11A0h
