; Impresión de caracteres del marcador: una sola dirección VRAM por celda en lugar de un RST 10h por byte.
; Sustituyen a A9F7h (normal) y AA1Ch (doble altura). Si DE no empieza en la línea 0 de una celda,
; se usa la rutina original. Al salir dejan DE/HL/B como las originales.
        INCLUDE "vars.inc"
        OUTPUT "glyph.bin"
        ORG 1190h
FONT    EQU 3C00h

setvram: ; DE = dirección Spectrum (línea 0 de celda) -> dirección de escritura VRAM
        push af
        ld a,e
        add a,a
        add a,a
        add a,a
        di
        out (99h),a
        ld a,e
        rlca
        rlca
        rlca
        and 7
        ld c,a
        ld a,d
        and 18h
        or c
        cp 4                    ; fila >= 4: zona de juego
        jr c,.hud
        ld (FORCE),a            ; blit3
.hud:   or 40h
        out (99h),a
        ei
        pop af
        ret

; RST 10h puede apuntar a otra rutina (p. ej. dibujar en RAM): solo se acelera si va a 0CB9h
fastok: ld c,a
        ld a,d
        and 7
        jr nz,.no
        push hl
        ld hl,(0011h)
        ld a,l
        cp 0B9h
        jr nz,.nh
        ld a,h
        cp 0Ch
.nh:    pop hl
.no:    ld a,c
        ret

; ---- A9F7h: A = carácter, DE = destino
chr1:   call fastok
        jr z,.ok
        ld bc,FONT
        jp 0A9FAh               ; ruta original
.ok:    ld bc,FONT
        add a,a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,bc
        cp 0DAh
        jr nz,.g
        ld hl,0AA14h
.g:     call setvram
        ld b,8
.lp:    ld a,(hl)
        srl a
        or (hl)
        out (98h),a
        inc hl
        djnz .lp
        ld a,d
        add a,8
        ld d,a
        ld c,b                  ; BC = 0000h como el original
        ret

; ---- AA1Ch: A = carácter, DE = destino (doble altura: dos celdas en vertical)
chr2:   call fastok
        jr z,.ok
        add a,a
        ld l,a
        ld h,0
        jp 0AA20h               ; ruta original
.ok:    add a,a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld bc,FONT
        add hl,bc
        call setvram
        call .half
        ld a,e                  ; misma aritmética que el original: e+=20h, d-=8 si no hay acarreo
        add a,20h
        ld e,a
        jr c,.c
        ; d no cambia (el original suma 8 con INC D y luego resta 8)
.c0:    call setvram
        call .half
        ld a,d
        add a,8
        ld d,a
        ld c,b
        ret
.c:     ld a,d
        add a,8
        ld d,a
        jr .c0
.half:  ld b,4
.hl:    ld a,(hl)
        srl a
        or (hl)
        inc l
        out (98h),a
        push af
        pop af
        out (98h),a
        djnz .hl
        ret
glyph_end:
        DISPLAY "glyph fin: ",/H,glyph_end
