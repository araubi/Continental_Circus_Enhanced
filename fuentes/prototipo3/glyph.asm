; Impresión de caracteres del marcador: una sola dirección VRAM por celda en lugar de un RST 10h por byte.
; Sustituyen a A9F7h (normal) y AA1Ch (doble altura). Si DE no empieza en la línea 0 de una celda,
; se usa la rutina original. Al salir dejan DE/HL/B como las originales.
        INCLUDE "vars.inc"
        OUTPUT "glyph.bin"
        ORG 11A0h
FONT    EQU 3C00h
; Marcador incremental: CACHE guarda qué muestra cada celda de las filas 0-3 (índice = E de la
; dirección Spectrum 40xxh). Carácter normal: su código; doble altura: código|80h arriba y 1
; abajo; 0 = no se sabe. Si la celda ya muestra el carácter, no se escribe en la VRAM. El resto
; de rutinas que escriben ahí (RST 10h suelto, 0520h, 0743h, 0A69h, la ROM) ponen HUDINV y la
; caché se borra entera antes de volver a usarla.
CACHE   EQU 1900h               ; 128 bytes; zona del copiador de arranque, libre después

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

; borra la caché (no toca C ni DE)
cclr:   xor a
        ld (HUDINV),a
        ld hl,CACHE
        ld b,128
.l:     ld (hl),a
        inc hl
        djnz .l
        ret

; ---- A9F7h: A = carácter, DE = destino
chr1:   call fastok
        jr z,.ok
        ld bc,FONT
        jp 0A9FAh               ; ruta original
.ok:    ld c,a
        ld a,d
        cp 40h
        jr nz,.draw
        bit 7,e
        jr nz,.draw             ; fila 4 o más: sin caché
        ld a,(HUDINV)
        or a
        call nz,cclr
        ld h,high CACHE
        ld l,e
        ld a,(hl)
        cp c
        ld (hl),c
        jr nz,.draw
        ld b,0                  ; ya está en pantalla
        jr .end
.draw:  ld a,c
        ld bc,FONT
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
.end:   ld a,d
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
.ok:    ld c,a
        ld a,d
        cp 40h
        jr nz,.draw
        ld a,e
        cp 60h
        jr nc,.draw             ; la mitad de abajo caería fuera de la caché
        ld a,(HUDINV)
        or a
        call nz,cclr
        ld h,high CACHE
        ld l,e
        ld a,c
        or 80h
        ld b,a
        ld a,(hl)
        xor b
        ld (hl),b
        ld b,a                  ; B = 0 si la celda de arriba ya lo muestra
        ld a,l
        add a,20h
        ld l,a
        ld a,(hl)
        ld (hl),1
        dec a
        or b
        jr nz,.draw
        ld b,a                  ; ya está en pantalla: solo se avanza DE como el original
        ld a,e
        add a,20h
        ld e,a
        jr .end
.draw:  ld a,c
        add a,a
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
.end:   ld a,d
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
        ASSERT glyph_end <= 1300h           ; 1300h: TEMP del volcado
        DISPLAY "glyph fin: ",/H,glyph_end
