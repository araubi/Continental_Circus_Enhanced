; Continental Circus MSX - volcado de la zona de juego, prototipo 3.
; Sustituye a la rutina 1033h del port de New Frontier (S. Casamiquela).
; Igual que el prototipo 2 (filas en orden de VRAM con autoincremento), y además:
;  - no reenvía las filas que quedan enteras por encima de la carretera (cielo y franja del
;    horizonte) si no han cambiado: misma posición (n1, n12), franja sin desplazar (B50Ah = 0)
;    y nadie más ha escrito en la VRAM de la zona de juego (FORCE, que ponen los ganchos);
;  - reloj por fotograma fijo: la interrupción sigue sumando a 8A0Eh (los menús lo usan),
;    pero en carrera el volcado quita lo que ha sumado (ICNT) y pone una cantidad fija por
;    fotograma, sea cual sea su duración.
        OUTPUT "blit3.bin"
        ORG 1500h
B4CA    EQU 0B4CAh
B4DC    EQU 0B4DCh
B4FE    EQU 0B4FEh
B4FF    EQU 0B4FFh
B50A    EQU 0B50Ah
TICK    EQU 059Dh
CLOCK   EQU 8A0Eh
BUF     EQU 0E400h
STRIP   EQU 0E200h
TEMP    EQU 1300h
FFBLK   EQU 1400h
FASTROW EQU 1C00h               ; volcado desenrollado de una fila (lo genera el arranque de la ROM)
CLKFRAC EQU 62                  ; parte fraccionaria (/256) de los ticks fijos por fotograma
CLKINT  EQU 2                   ; parte entera

blit:   call TICK
        di
        ; Reloj por fotograma: se quitan los ticks que ha sumado la interrupción desde el
        ; último volcado (ICNT) y se suma una cantidad fija. En el primer fotograma de una
        ; carrera no se quita nada.
        ld hl,ICNT
        ld c,(hl)
        ld (hl),0
        ld a,(B4DC)
        dec a
        ld hl,lastdc
        cp (hl)
        jr z,.cons
        ld c,0
.cons:  ld hl,CLOCK
        ld a,(hl)
        sub c
        jr nc,.cl1
        xor a
.cl1:   ld (hl),a
        ld a,(frac)
        add a,CLKFRAC
        ld (frac),a
        ld a,CLKINT
        adc a,0
        add a,(hl)
        ld (hl),a
        ; n2 = max(B4FF-16,0) líneas de franja; n1 = 90h - n2 - B4FE líneas de cielo
        ld a,(B4FF)
        sub 16
        jr nc,.n2ok
        xor a
.n2ok:  ld (n2),a
        ld hl,B4FE
        add a,(hl)
        add a,20h
        sub 0C0h
        neg
        sub 10h
        ld c,0
        jr c,.nosky
        ld c,a
        ld e,a
        srl e
        add a,e
        ld (B4CA),a             ; misma contabilidad de tiempo que el original
.nosky: ld a,c
        ld (n1),a
        ld hl,n2
        add a,(hl)
        ld (n12),a              ; primera línea de carretera
        ld a,(n2)
        or a
        jr z,.road
        ld hl,B4CA
        add a,(hl)
        ld (hl),a
.road:  ld a,(B4FE)
        add a,10h
        ld hl,B4CA
        add a,(hl)
        ld (hl),a
        ; ¿se pueden saltar las filas de arriba?  skip = 0 / FFh
        ld hl,pitnow            ; letrero PIT IN: si está en la VRAM y el juego no lo ha vuelto
        ld a,(hl)               ; a pintar desde el último volcado, hay que borrarlo
        ld (hl),0
        inc hl
        ld b,(hl)
        ld (hl),a               ; pitvram = pitnow
        cpl
        and b
        inc hl
        ld (hl),a               ; pitdel = estaba y ya no
        ld b,0
        ld a,b
        ld (skysk),a
        ld a,(B4DC)             ; fotogramas de carrera seguidos
        dec a
        ld hl,lastdc
        cp (hl)
        jr nz,.noskip
        ld a,(force)
        or a
        jr nz,.noskip
        ld a,(ln1)              ; el cielo (FFh) no cambia aunque la franja se desplace: las
        ld hl,n1                ; filas que eran y son cielo, min(n1, ln1), no se reenvían
        cp (hl)
        jr c,.sk1
        ld a,(hl)
.sk1:   ld (skysk),a
        ld hl,(B50A)            ; la franja se desplazó tras el último volcado
        ld a,h
        or l
        jr nz,.noskip
        ld a,(n1)
        ld hl,ln1
        cp (hl)
        jr nz,.noskip
        ld a,(n12)
        ld hl,ln12
        cp (hl)
        jr nz,.noskip
        dec b
.noskip:
        ld a,b
        ld (skip),a
        xor a
        ld (force),a
        ld a,(B4DC)
        ld (lastdc),a
        ld a,(n1)
        ld (ln1),a
        ld a,(n12)
        ld (ln12),a
        xor a
        ld (line),a
        ld a,04h
        ld (vrow),a
.row:   ld a,(line)             ; A = primera línea de la fila
        ld b,a
        add a,8
        ld c,a                  ; C = línea siguiente a la fila
        ld a,(pitdel)
        or a
        jr z,.nopit
        ld a,b                  ; filas del letrero (líneas 8-23): se reenvían para borrarlo
        cp 8
        jr z,.doit
        cp 16
        jr z,.doit
.nopit: ld a,(skysk)
        cp c
        jp nc,.next             ; fila de cielo, igual que antes
        ld a,(skip)
        or a
        jr z,.doit
        ld a,(n12)
        cp c
        jp nc,.next             ; fila entera por encima de la carretera: igual que antes
.doit:  ld a,(vrow)             ; dirección VRAM de la fila
        di
        push af
        xor a
        out (99h),a
        pop af
        or 40h
        out (99h),a
        ld a,(n1)
        cp c
        jr c,.notsky            ; n1 < L0+8
        ld hl,FFBLK
        jr .blast
.notsky:
        ld a,(n12)
        cp b
        jr z,.isroad
        jr c,.isroad            ; n12 <= L0
        ld a,(n1)
        dec a
        cp b
        jr nc,.mixed
        ld a,(n12)
        cp c
        jr c,.mixed
        ld a,b
        call strip_ptr
        jr .blast
.isroad:
        ld a,b
        call road_ptr
        jr .blast
.mixed: ; fila mixta: copia las 8 líneas a TEMP
        ld de,TEMP
.ml:    push bc
        ld a,b
        ld hl,n1
        cp (hl)
        jr nc,.m1
        ld hl,FFBLK
        jr .mcp
.m1:    ld hl,n12
        cp (hl)
        jr nc,.m2
        call strip_ptr
        jr .mcp
.m2:    call road_ptr
.mcp:   ld bc,32
        ldir
        pop bc
        inc b
        ld a,b
        cp c
        jr nz,.ml
        ld hl,TEMP
.blast: ; HL = origen de la fila (8 líneas con paso 32)
        ld a,l                  ; fila alineada a página (carretera, TEMP, FFBLK): rutina
        or a                    ; desenrollada FASTROW (ld l,n / outi), que genera el arranque
        jr nz,.slow
        ld c,98h
        call FASTROW
        jr .next
.slow:  ld de,32
        ld b,32
.col:   push hl
        ld a,(hl)
        out (98h),a
        add hl,de
        ld a,(hl)
        out (98h),a
        add hl,de
        ld a,(hl)
        out (98h),a
        add hl,de
        ld a,(hl)
        out (98h),a
        add hl,de
        ld a,(hl)
        out (98h),a
        add hl,de
        ld a,(hl)
        out (98h),a
        add hl,de
        ld a,(hl)
        out (98h),a
        add hl,de
        ld a,(hl)
        out (98h),a
        pop hl
        inc hl
        djnz .col
.next:  ld hl,vrow
        inc (hl)
        ld a,(line)
        add a,8
        ld (line),a
.tail:  cp 160                  ; (la ROM engancha aquí SATW)
        jp nz,.row
        ei
        ret

n1:     db 0
n2:     db 0
n12:    db 0
line:   db 0
vrow:   db 0
frac:   db 0
skip:   db 0
skysk:  db 0                    ; líneas de cielo que no hace falta reenviar
pitnow: db 0                    ; el juego ha pintado el letrero PIT IN desde el último volcado
pitvram: db 0                   ; el letrero está en la VRAM
pitdel: db 0                    ; hay que borrarlo en este volcado
force:  db 1
lastdc: db 0
ln1:    db 0FFh
ln12:   db 0FFh
ICNT:   db 0                    ; ticks que la interrupción ha sumado a 8A0Eh
hudinv: db 1                    ; algo ha escrito en las filas 0-3 sin pasar por glyph.asm: su caché no vale
gearinv: db 1                   ; ídem para el rótulo de la marcha de la fila 3 (lo pinta la ROM)
blit_end:
blit_row EQU blit.row
blit_tail EQU blit.tail
        DISPLAY "blit3 fin: ",/H,blit_end
        DISPLAY "force: ",/H,force
        DISPLAY "ICNT: ",/H,ICNT
        DISPLAY "hookint: ",/H,hookint
        DISPLAY "hook743: ",/H,hook743
        DISPLAY "hookA69: ",/H,hookA69
        ASSERT blit_end <= 16E7h          ; 16E7h: rutina del letrero (sigue en uso)

; ---- ganchos: otras rutinas que escriben en la VRAM. Si es en la zona de juego obligan a
; volcarlo todo (FORCE); si es en el marcador (filas 0-3), a reimprimirlo entero (HUDINV).
; Van en el hueco que dejó el volcado original (1036h-115Fh).
        OUTPUT "hooks3.bin"
        ORG 1036h
hook743:                        ; 0743h: copia la pantalla Spectrum entera
        push af
        ld a,1
        ld (force),a
        ld (hudinv),a
        ld (gearinv),a
        pop af
        push hl
        push de
        push bc
        push af
        jp 0747h
hook520:                        ; 0520h (SETWRT del port): dirección en la zona de juego -> FORCE
        di                      ; (lo usan 0743h, el letrero de 16E7h y otros)
        ld a,h
        and 3Fh
        cp 18h
        jr nc,.c
        cp 4
        jr c,.h
        ld (force),a
.n:     ld a,l
        out (99h),a
        jp 0524h                ; el JP del parche ocupa 0520h-0522h
.h:     ld a,1                  ; patrones de las filas 0-3
        ld (hudinv),a
        ld (gearinv),a
        jr .n
.c:     and 3Ch                 ; colores de las filas 0-3 (2000h-23FFh): pisan los del rótulo
        cp 20h
        jr nz,.n
        ld (gearinv),a
        jr .n
hookA69:                        ; 0A69h: textos grandes desde E280h
        push af
        ld a,1
        ld (force),a
        ld (hudinv),a
        pop af
        jp TICK
; HL = E200h + 32*(A - n1)
strip_ptr:
        ld hl,n1
        sub (hl)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        push de
        ld de,STRIP
        add hl,de
        pop de
        ret
; HL = E400h + 32*A
road_ptr:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        push de
        ld de,BUF
        add hl,de
        pop de
        ret
hookint:                        ; desde 0593h (interrupción, tras PUSH HL): 8A0Eh += 1 y ICNT += 1
        ld hl,CLOCK             ; sin CALL: la pila queda igual de honda que en el original
        inc (hl)
        ld hl,ICNT
        inc (hl)
        pop hl
        jp 0599h
hookpit:                        ; 16EEh y 172Ch (letrero PIT IN, filas 5 y 6): como 0520h pero sin
        ld a,1                  ; FORCE. El letrero se queda en la VRAM mientras esas filas no se
        ld (pitnow),a           ; reenvíen, y el volcado lo borra cuando el juego deja de pintarlo
        di
        ld a,l
        out (99h),a
        jp 0524h
hooks_end:
        ASSERT hooks_end <= 1160h
