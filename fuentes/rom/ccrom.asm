; =====================================================================
; Continental Circus - versión MegaROM ASCII8 (256 KB) del prototipo 3
; Juego original: Continental Circus (Taito 1987), versión MSX de
; Virgin Mastertronic 1989, conversión de NEW FRONTIER, código de
; S. Casamiquela. Conversión a ROM y mejoras: 2026.
;
; Bancos de 8 KB:
;   0      arranque (este fichero)
;   1-8    imagen de RAM de 64 KB al empezar el juego (81A0h)
;   9-10   imagen de VRAM de 16 KB
;   11-19  circuitos TRACK1-TRACK9 de la cara B
; =====================================================================

TRKBANK equ 11
RAMBANK equ 1
VRMBANK equ 9
FINBANK equ 20                  ; pantalla final (bancos 20-21)
COPIER  equ 1900h               ; zona sin datos del juego (pila 1C00h hacia abajo)
TMP     equ 0C000h
T_A8R   equ TMP
T_A8A   equ TMP+1
T_FFR   equ TMP+2
T_FFA   equ TMP+3
T_EXP   equ TMP+4
T_PRAM  equ TMP+5
T_PAL   equ TMP+6

; ---------------------------------------------------------------------
; Código residente dentro de la imagen de RAM (se superpone al cargador
; de cinta, que ya no hace falta)
; ---------------------------------------------------------------------
        output "rt_fb03.bin"
        org 0FB03h
; Entrada original: HL = rutina de texto, A = circuito (0..8).
; Tras la carga el juego sigue en FB42h (copia de E000h a sus destinos).
; Se quitan los mensajes de cinta; el circuito 9 (pantalla final) se sigue
; mostrando con la rutina original de 0701h, que espera una tecla.
        ld (0FB01h),hl
        add a,31h
        ld (0FDF5h),a
        call ROMTRK
        ld a,(0FDF5h)
        cp 39h
        call z,FINAL
        jp 0FB42h
        assert $ <= 0FB42h

        output "rt_fd01.bin"
        org 0FD01h
ROMTRK: di
        ld a,(0FDF5h)
        sub 31h
        add a,TRKBANK
        ld b,a
        ld a,(A8ROM)
        out (0A8h),a
        ld a,(EXPF)
        or a
        jr z,.n1
        ld a,(FFROM)
        ld (0FFFFh),a
.n1:    ld a,b
        ld (6000h),a            ; banco del circuito en 4000h-5FFFh
        ld hl,4000h
        ld de,0E000h
        ld bc,12FEh
        ld a,(0FDF5h)
        cp 39h
        jr nz,.n2
        ld bc,1B00h
.n2:    ldir
        ld a,(A8ALL)
        out (0A8h),a
        ld a,(EXPF)
        or a
        jr z,.n3
        ld a,(FFALL)
        ld (0FFFFh),a
.n3:    xor a                   ; Z y NC: carga correcta
        ret
; Configuración de slots (la rellena el arranque)
A8ROM:  db 0                    ; A8h con la ROM en la página 1
A8ALL:  db 0                    ; A8h con RAM en las 4 páginas
FFROM:  db 0                    ; registro de subslot (si hay expansión)
FFALL:  db 0
EXPF:   db 0                    ; 1 si el slot de la RAM está expandido
; Pantalla final (circuito 9): en vez de la pantalla Spectrum (0701h), una
; SCREEN 2 hecha a partir de la de la recreativa (bancos FINBANK y +1:
; patrones y colores, 6144 bytes cada uno). Luego espera tecla como 0719h.
FINAL:  ld hl,0E000h            ; como 0701h: la copia en 4000h
        ld de,4000h
        ld bc,1B00h
        ldir
        call SPHIDE
        di
        ld a,(A8ROM)
        out (0A8h),a
        ld a,(EXPF)
        or a
        jr z,.f1
        ld a,(FFROM)
        ld (0FFFFh),a
.f1:    ld a,FINBANK
        ld (6000h),a
        inc a
        ld (6800h),a
        xor a
        ld hl,4000h
        call .vr                ; patrones en 0000h
        ld a,20h                ; colores en 2000h
        call .vr
        ld a,RAMBANK+1
        ld (6800h),a
        ld a,(A8ALL)
        out (0A8h),a
        ld a,(EXPF)
        or a
        jp z,0719h
        ld a,(FFALL)
        ld (0FFFFh),a
        jp 0719h
.vr:    ld c,a                  ; A = byte alto de la dirección en VRAM
        xor a
        out (99h),a
        ld a,c
        or 40h
        out (99h),a
        ld bc,1800h
.l:     ld a,(hl)
        out (98h),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.l
        ret
        assert $ <= 0FDF0h


; ---------------------------------------------------------------------
; Sonido: motor y choques con los del Hyper Rally (Konami 1985)
; Fórmula del motor y efectos 42h (golpe) y 4Ch (choque) tomados del
; desensamblado de Hyper Rally de antxiko (licencia MIT).
; Vive en 2000h, zona de RAM que el juego no usa (la cinta no la carga).
; ---------------------------------------------------------------------
        output "snd_2000.bin"
        org 2000h
KEEP    equ 40                  ; interrupciones que sigue sonando el motor sin carrera
BEEPC   equ 8                   ; duración del pitido corto (interrupciones)
BEEPL   equ 30                  ; duración del pitido de salida

; Interrupción: sustituye al final de la rutina 0582h (pop af / ei / reti)
SNDINT: push bc
        push de
        push hl
        call MUSINT             ; música del mapa (si suena)
        ; --- efecto: un cuadro de escrituras (registro, valor) hasta FFh
        ld hl,(SFXPTR)
        ld a,h
        or l
        jr z,.eng
.sl:    ld a,(hl)
        inc hl
        cp 0FFh
        jr z,.sf
        cp 0FEh
        jr z,.sd
        out (0A0h),a
        ld a,(hl)
        inc hl
        out (0A1h),a
        jr .sl
.sd:    ld hl,0
.sf:    ld (SFXPTR),hl
        ; --- pitido del semáforo (canal B)
.eng:   ld a,(BEEPT)
        or a
        jr z,.eng2
        dec a
        ld (BEEPT),a
        jr nz,.eng2
        ld a,9
        out (0A0h),a
        xor a
        out (0A1h),a
        ; --- motor (canal A)
.eng2:   ld a,(ENGT)
        or a
        jp z,.out
        dec a
        ld (ENGT),a
        jr nz,.run
        ld a,8                  ; fuera de carrera: silencio
        out (0A0h),a
        xor a
        out (0A1h),a
        jp .out
.run:   ld hl,(0B504h)          ; velocidad en km/h
        ld d,h
        ld e,l
        srl d
        rr e
        srl d
        rr e                    ; DE = v/4
        or a
        sbc hl,de
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e                    ; DE = v/32
        or a
        sbc hl,de               ; HL = v*0,72 (escala del Hyper Rally)
        ld a,h
        or a
        ld a,l
        jr z,.v8
        ld a,0FFh
.v8:    ld e,a
        ld d,0
        ld l,a
        ld h,d
        ld a,(0B507h)           ; marcha: 0 corta, FFh larga
        or a
        jr nz,.x9
        ld a,(0B501h)           ; mandos: bit 3 acelerador
        and 8
        jr z,.x9
        ld a,e
        cp 60h
        jr nc,.ge60
        add hl,hl               ; corta acelerando: v*24
        add hl,de
        add hl,hl
        add hl,hl
        add hl,hl
        jr .per
.ge60:  ld de,5Fh
        sbc hl,de
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,08E8h
        add hl,de
        jr .per
.x9:    add hl,hl               ; larga o sin acelerar: v*9
        add hl,hl
        add hl,hl
        add hl,de
.per:   ex de,hl
        ld a,(PHASE)
        xor 8
        ld (PHASE),a
        or 0E0h
        ld l,a
        ld h,0Dh                ; base 0DE0h / 0DE8h alternando, como el Hyper Rally
        or a
        sbc hl,de
        jr c,.min
        ld a,h
        or a
        jr nz,.wr
        ld a,l
        cp 40h
        jr nc,.wr
.min:   ld hl,40h
.wr:    xor a
        out (0A0h),a
        ld a,l
        out (0A1h),a
        ld a,1
        out (0A0h),a
        ld a,h
        out (0A1h),a
        ld a,8
        out (0A0h),a
        ld a,0Ch
        out (0A1h),a
.out:   pop hl
        pop de
        pop bc
        pop af
        ei
        reti

; Freno (Hyper Rally 46h, más suave): ruido en B y chirrido en C
SFX46:  db 6,0Fh, 7,0AAh, 9,9, 4,5Ah, 5,0, 10,12, 0FFh
        db 9,11, 4,66h, 0FFh
        db 9,9, 4,65h, 10,11, 0FFh
        db 7,0B8h, 9,0, 10,0, 0FEh

; Llamada del bucle de carrera en cada fotograma (antes call 8919h)
RACEFR: push af
        ld a,KEEP
        ld (ENGT),a
        pop af
        jp 8919h

; Semáforo (87D7h, antes ld a,(B4CFh)): HL = B511h, luz que se enciende
; (0 y 1 rojas, 2 verde). Pitido en el canal B a volumen fijo; lo apaga
; SNDINT al pasar BEEPT interrupciones: corto en las rojas y más largo y
; agudo en la salida.
SEMBEEP:
        push bc
        ld a,i
        push af
        di
        ld a,(hl)
        cp 2
        ld b,BEEPC
        ld a,8Eh                ; ~790 Hz
        jr c,.s
        ld b,BEEPL
        ld a,47h                ; ~1580 Hz
.s:     ld c,a
        ld a,b
        ld (BEEPT),a
        ld a,2
        out (0A0h),a
        ld a,c
        out (0A1h),a
        ld a,3
        out (0A0h),a
        xor a
        out (0A1h),a
        ld a,9
        out (0A0h),a
        ld a,0Dh
        out (0A1h),a
        pop af
        pop bc
        jp po,.di
        ei
.di:    ld a,(0B4CFh)
        ret

BEEPT:  db 0
SFXPTR: dw 0
SFXPRI: db 0
ENGT:   db 0
PHASE:  db 0

; Efectos: pasos de pares (registro, valor) cerrados con FFh; FEh termina.
; El juego atiende la interrupción unas 19 veces por segundo (no 60, como
; el Hyper Rally), así que cada paso junta 2-3 cuadros del original.
SFX42:  db 6,1Fh, 7,98h, 5,00h, 4,0F4h, 10,0Ah, 0FFh
        db 5,00h, 4,0FEh, 10,0Dh, 0FFh
        db 7,0B8h, 10,0, 0FEh
SFX4C:  db 6,1Bh, 7,8Ah, 9,0Eh, 5,01h, 4,34h, 10,0Eh, 0FFh
        db 6,19h, 9,0Bh, 5,01h, 4,74h, 10,0Eh, 0FFh
        db 6,1Ch, 9,06h, 5,01h, 4,0B4h, 10,0Dh, 0FFh
        db 9,0, 5,03h, 4,0C0h, 10,0Dh, 0FFh
        db 5,03h, 4,0A0h, 10,0Ch, 0FFh
        db 5,03h, 4,0D0h, 10,0Ch, 0FFh
        db 5,03h, 4,0C0h, 10,0Bh, 0FFh
        db 5,03h, 4,0E0h, 10,0Ah, 0FFh
        db 5,03h, 4,0B0h, 10,09h, 0FFh
        db 5,03h, 4,0D0h, 10,08h, 0FFh
        db 5,03h, 4,0A0h, 10,07h, 0FFh
        db 5,03h, 4,0B0h, 10,06h, 0FFh
        db 5,03h, 4,0D0h, 10,06h, 0FFh
        db 5,03h, 4,0F0h, 10,06h, 0FFh
        db 7,0B8h, 10,0, 0FEh
        assert $ <= 2400h


; ---------------------------------------------------------------------
; Música del mapa de cada circuito: arreglos para PSG de las músicas de
; la recreativa (Taito 1987, Masahiko Takaki), transcritas de las
; grabaciones que pasó Rubén. Datos a 60 ticks/s; en máquinas de 50 Hz
; se dan 6 ticks cada 5 interrupciones.
; Canción: cabecera con 4 desplazamientos (voces A, B, C y percusión).
; Voz: pares (nota, duración); nota bit 7 = ataque nuevo, 7Eh = silencio,
; FFh = fin. Percusión: pares (espera, tipo 1 bombo / 2 caja / 0 nada), 0 = fin.
; ---------------------------------------------------------------------
        output "mus_2400.bin"
        org 2400h
VSIZE   equ 11                  ; ptr(2) cnt per(2) act age v0 vmin vol reg

MUSINT: ld a,(RACY)
        or a
        jr z,.m
        dec a
        ld (RACY),a
.m:     ld a,(MUSON)
        or a
        ret z
        push ix
        ld a,(TACC)
        ld hl,TSTEP
        add a,(hl)
        ld c,a
        ld a,(RACY)             ; mientras el juego vuelca imágenes de carrera la
        or a                    ; interrupción llega ~20 veces por segundo, no 60:
        ld a,c                  ; tres pasos por cada una
        jr z,.l
        add a,(hl)
        add a,(hl)
.l:     cp 10
        jr c,.d
        sub 10
        push af
        call MUSTICK
        pop af
        ld hl,MUSON
        bit 0,(hl)
        jr nz,.l
.d:     ld (TACC),a
        pop ix
        ret

; Arranca la canción A (0..7)
MUSPLAY:
        add a,a
        ld e,a
        ld d,0
        ld hl,SONGS
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld (MBASE),hl
        ld ix,VOICES
        ld b,3
.p:     push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld hl,(MBASE)
        add hl,bc
        ld (ix+0),l
        ld (ix+1),h
        ld (ix+2),1
        ld (ix+5),0
        ld (ix+6),0
        ld bc,VSIZE
        add ix,bc
        pop hl
        pop bc
        djnz .p
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld hl,(MBASE)
        add hl,bc
        ld a,(hl)
        ld (DWAIT),a
        inc hl
        ld a,(hl)
        ld (DTYPE),a
        inc hl
        ld (DPTR),hl
        xor a
        ld (DK),a
        ld a,9
        ld (DAGE),a
        ret

MUSEND: xor a
        ld (MUSON),a
        ld b,8
        call .z
        ld b,9
        call .z
        ld b,10
        call .z
        ld a,7
        out (0A0h),a
        ld a,0B8h
        out (0A1h),a
        ret
.z:     ld a,b
        out (0A0h),a
        xor a
        out (0A1h),a
        ret

MUSTICK:
        ld hl,(MTICK)
        inc hl
        ld (MTICK),hl
        ld ix,VOICES
        ld b,3
.v:     dec (ix+2)
        jr nz,.vol
        ld l,(ix+0)
        ld h,(ix+1)
        ld a,(hl)
        cp 0FFh
        jp z,MUSEND
        inc hl
        ld c,(hl)
        inc hl
        ld (ix+2),c
        ld (ix+0),l
        ld (ix+1),h
        ld c,a
        and 7Fh
        cp 7Eh
        jr nz,.nt
        ld (ix+5),0
        jr .ag
.nt:    add a,a
        ld e,a
        ld d,0
        ld hl,PERTAB
        add hl,de
        ld a,(hl)
        ld (ix+3),a
        inc hl
        ld a,(hl)
        ld (ix+4),a
        ld (ix+5),1
.ag:    bit 7,c
        jr z,.vol
        ld (ix+6),0
.vol:   xor a
        bit 0,(ix+5)
        jr z,.wv
        ld a,(ix+6)
        ld c,a
        inc a
        jr z,.na
        ld (ix+6),a
.na:    ld a,c
        rrca
        rrca
        and 3Fh
        ld c,a
        ld a,(ix+7)
        sub c
        jr c,.mn
        cp (ix+8)
        jr nc,.wv
.mn:    ld a,(ix+8)
.wv:    ld (ix+9),a
        ld de,VSIZE
        add ix,de
        djnz .v
        ; --- percusión
        ld a,(DWAIT)
        or a
        jr z,.dd
        dec a
        ld (DWAIT),a
        jr nz,.dd
        ld a,(DTYPE)
        or a
        jr z,.rd
        ld (DK),a
        xor a
        ld (DAGE),a
.rd:    ld hl,(DPTR)
        ld a,(hl)
        ld (DWAIT),a
        or a
        jr z,.dd
        inc hl
        ld a,(hl)
        ld (DTYPE),a
        inc hl
        ld (DPTR),hl
.dd:    ; --- canales A y B
        ld ix,VOICES
        call VOUT
        ld ix,VOICES+VSIZE
        call VOUT
        ; --- canal C: percusión o tercera voz
        ld a,(DK)
        cp 1
        jr nz,.sn
        ld a,(DAGE)
        cp 4
        jr nc,.nod
        ld e,a
        inc a
        ld (DAGE),a
        ld d,0
        ld hl,KICKV
        add hl,de
        ld c,(hl)               ; volumen
        ld hl,KPERT
        add hl,de
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; tono que baja con cada cuadro
        ld a,28
        ld b,98h
        jr .cw
.sn:    cp 2
        jr nz,.nod
        ld a,(DAGE)
        cp 3
        jr nc,.nod
        ld e,a
        inc a
        ld (DAGE),a
        ld d,0
        ld hl,SNAREV
        add hl,de
        ld c,(hl)
        ld hl,(VOICES+2*VSIZE+3) ; el tono no suena (mezclador)
        ld a,4
        ld b,9Ch
        jr .cw
.nod:   ld ix,VOICES+2*VSIZE
        call VOUT
        ld a,7
        out (0A0h),a
        ld a,0B8h
        out (0A1h),a
        ret
.cw:    push af                 ; A = ruido, B = mezclador, C = volumen, HL = tono
        ld a,4
        out (0A0h),a
        ld a,l
        out (0A1h),a
        ld a,5
        out (0A0h),a
        ld a,h
        out (0A1h),a
        ld a,10
        out (0A0h),a
        ld a,c
        out (0A1h),a
        ld a,6
        out (0A0h),a
        pop af
        out (0A1h),a
        ld a,7
        out (0A0h),a
        ld a,b
        out (0A1h),a
        ret

VOUT:   ld a,(ix+10)            ; registro de tono
        out (0A0h),a
        ld a,(ix+3)
        out (0A1h),a
        ld a,(ix+10)
        inc a
        out (0A0h),a
        ld a,(ix+4)
        out (0A1h),a
        ld a,(ix+10)
        rrca
        add a,8
        out (0A0h),a
        ld a,(ix+9)
        out (0A1h),a
        ret

; Mapa (A76Ah, antes ld hl,C8A6h / jp 8A0Fh): C = circuito
MAPMUS: ld hl,0B4CBh            ; sonido activado
        bit 0,(hl)
        ret z
        ld a,c
        cp 8
        ret nc
        ld b,a
        ld (MSONG),a
        ld a,i
        push af
        di
        push bc
        call MUSEND
        pop af
        push ix
        call MUSPLAY
        pop ix
        xor a
        ld (TACC),a
        ld h,a
        ld l,a
        ld (MTICK),hl
        inc a
        ld (MUSON),a
        ld (MPLAYED),a
        ; El mapa se queda mientras suena la música (a tempo, con HALT);
        ; una tecla o el disparo la cortan, como en la espera del juego.
        pop af
        push af
        ei
        ld a,(MSONG)
        add a,a
        ld e,a
        ld d,0
        ld hl,SONGLEN
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = duración en ticks
.w:     ld a,(MUSON)
        or a
        jr z,.x
        ld hl,(MTICK)
        or a
        sbc hl,de
        jr nc,.x
        push de
        call 0AE07h             ; teclas/joystick, como en 8822h
        pop de
        and 1Fh
        jr z,.h
        di
        call MUSEND
        jr .x
.h:     ei
        halt                    ; espera a la siguiente interrupción
        jr .w
.x:     pop af
        ret pe
        di
        ret

; Espera del mapa (86DAh, antes ld b,40h / jp 8833h): la de siempre y,
; si la música sigue, hasta que acabe
MAPWAIT:
        ld b,40h
        call 8833h
.w:     ld a,(MUSON)
        or a
        ret z
        ld b,1
        call 8833h
        jr .w

; Espera tras el mapa (876Bh, antes ld b,0 delante / call 8822h): si ya
; ha sonado la música, solo una pausa corta en vez de los ~7,5 s
MAPW2:  ld a,(MPLAYED)
        or a
        jp z,8822h
        xor a
        ld (MPLAYED),a
        ld b,40
        jp 8822h

; Antes del semáforo (87CCh, antes ld hl,B511h): la música se corta
MUSOFF: ld a,i
        push af
        di
        ld a,(MUSON)
        or a
        call nz,MUSEND
        ld hl,0B511h
        pop af
        ret po
        ei
        ret

KICKV:  db 14,12,9,6
SNAREV: db 13,10,7
KPERT:  dw PERIOD36, PERIOD36+40, PERIOD36+80, PERIOD36+120
MBASE:  dw 0
MTICK:  dw 0
MSONG:  db 0
MPLAYED: db 0
        include "songlen.inc"
MUSON:  db 0
RACY:   db 0                    ; interrupciones desde el último volcado de carrera (cuenta atrás)
TACC:   db 0
TSTEP:  db 10                   ; 10 a 60 Hz, 12 a 50 Hz (lo pone el arranque)
DPTR:   dw 0
DWAIT:  db 0
DTYPE:  db 0
DK:     db 0
DAGE:   db 9
VOICES: ; A, B, C
        dw 0
        db 0
        dw 0
        db 0,0,13,9,0,0
        dw 0
        db 0
        dw 0
        db 0,0,13,10,0,2
        dw 0
        db 0
        dw 0
        db 0,0,10,6,0,4
        include "pertab.inc"
SONGS:  dw S_BRA,S_USA,S_FRA,S_MON,S_GER,S_SPA,S_MEX,S_JAP
        dw J_META,J_CAMP,J_NOCAL      ; 8-10: fanfarrias del Hyper Rally

        assert $ <= 2800h
        output "songs_2800.bin"
        org 2800h
S_BRA:  incbin "../musica/Brazil.song"
S_USA:  incbin "../musica/America.song"
S_FRA:  incbin "../musica/France.song"
S_MON:  incbin "../musica/Monaco.song"
S_GER:  incbin "../musica/Germany.song"
S_SPA:  incbin "../musica/Spain.song"
S_MEX:  incbin "../musica/Mexico.song"
S_JAP:  incbin "../musica/Japan.song"

; Freno con cursor ABAJO (o joystick abajo): sustituye a call 0AE07h en
; 8C9Dh. Quita el acelerador, resta BRK km/h por fotograma y, por encima de
; BRKS km/h, suena el chirrido del Hyper Rally si no suena otro efecto.
BRK     equ 8
BRKS    equ 80
BRAKE:  call 0AE07h
        ld b,a                  ; joystick (Rubén, 28-10-2026): disparo acelera,
        ld a,(0AF3Eh)           ; arriba cambia de marcha, abajo frena
        or a
        ld a,b
        jr z,.kb
        and 0E7h                ; bit 3 = acelerar, bit 4 = marcha
        bit 3,b
        jr z,.j1
        or 10h
.j1:    bit 4,b
        jr z,.kb
        or 08h
.kb:
        push af
        di
        in a,(0AAh)
        and 0F0h
        or 8
        out (0AAh),a
        in a,(0A9h)
        ei
        bit 6,a
        jr z,.br
        ld a,(0AF3Eh)
        or a
        jr z,.no
        pop af
        push af
        bit 2,a
        jr nz,.br
.no:    pop af
        ret
.br:    pop af
        and 0F7h
        push af
        ld hl,(0B504h)
        ld de,-BRK
        add hl,de
        jr c,.s
        ld hl,0
.s:     ld (0B504h),hl
        ld de,-BRKS
        add hl,de
        jr nc,.no
        ld hl,(SFXPTR)
        ld a,h
        or l
        jr nz,.no
        ld (SFXPRI),a
        ld hl,SFX46
        ld (SFXPTR),hl
        jr .no

; ---------------------------------------------------------------------------
; Rivales grandes en sprites: el primer coche grande (imágenes 0-8) que se
; pinta en el fotograma deja su imagen en BIGIMG; al final del volcado
; BIGSAT sube sus patrones (12 huecos, 52-63; solo si cambió la imagen) y
; añade sus piezas al final de la lista, que SATW manda la primera: así el
; coche grande gana a los pequeños en el límite de 4 sprites por línea.
FINDW:  ; busca DE en la tabla HL de B palabras; Z = hallado (B = restantes)
        ld a,(hl)
        inc hl
        cp e
        jr nz,.n
        ld a,(hl)
        cp d
        ret z
.n:     inc hl
        djnz FINDW
        or 1
        ret
POSCOL: ; DE = búfer, IX = rival -> SPY, SPX, SPC
        ld a,d
        sub 0E0h
        add a,a
        add a,a
        add a,a
        ld c,a
        ld a,e
        rlca
        rlca
        rlca
        and 7
        or c
        dec a                   ; el VDP pinta el sprite una línea más abajo
        ld (SPY),a
        ld a,e
        and 1Fh
        add a,a
        add a,a
        add a,a
        ld (SPX),a
        ld a,ixl                ; color según el rival (IX = A3B9h + 5*n)
        sub 0B9h
        ld c,0
.cl:    sub 5
        jr c,.ce
        inc c
        jr .cl
.ce:    ld a,c
        cp 5
        jr c,.cok
        xor a
.cok:   ld hl,COLS
        add a,l
        ld l,a
        jr nc,.c2
        inc h
.c2:    ld a,(hl)
        ld (SPC),a
        ret
PUTPC:  ; D = dy, C = dx, E = patrón: añade una pieza en SPY/SPX con color SPC
        ld a,(SPN)
        cp 32
        ret nc
        push hl
        ld l,a
        inc a
        ld (SPN),a
        ld h,0
        add hl,hl
        add hl,hl
        push de
        ld de,SPL
        add hl,de
        pop de
        ld a,(SPX)
        add a,c
        ld c,a
        ld a,0C0h               ; se sale por la derecha: fuera de pantalla
        jr c,.y
        ld a,(SPY)
        add a,d
.y:     ld (hl),a
        inc hl
        ld (hl),c
        inc hl
        ld (hl),e
        inc hl
        ld a,(SPC)
        ld (hl),a
        pop hl
        ret
BIGSAT: ld hl,(BIGIMG)
        ld a,h
        or a
        ret z
        ld de,0
        ld (BIGIMG),de
        ld de,(BIGLAST)
        or a
        sbc hl,de
        add hl,de
        call nz,BUILD
        ld hl,BIGY
        ld de,SPY
        ld bc,3
        ldir
        ld a,(BIGN)
        or a
        ret z
        ld b,a
        ld hl,BIGPL
.p:     ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld e,(hl)
        inc hl
        call PUTPC
        djnz .p
        ret
BUILD:  ; HL = imagen (ancho en bytes, alto, 1 bit por punto)
        ld (BIGLAST),hl
        ld a,(hl)
        ld (BW),a
        inc hl
        ld a,(hl)
        ld (BH),a
        inc hl
        ld (BD),hl
        xor a
        ld (BIGN),a
        ld (BR),a
.rl:    ld a,(BR)
        ld hl,BH
        cp (hl)
        ret nc
        xor a
        ld (BCL),a
.cl:    ld a,(BCL)
        ld hl,BW
        cp (hl)
        jr nc,.nr
        call PIECE
        ld a,(BCL)
        add a,2
        ld (BCL),a
        jr .cl
.nr:    ld a,(BR)
        add a,16
        ld (BR),a
        jr .rl
PIECE:  ld de,PB
        ld a,(BCL)
        call HALF
        ld a,(BCL)
        inc a
        call HALF
        ld hl,PB
        ld b,32
        xor a
.t:     or (hl)
        inc hl
        djnz .t
        or a
        ret z                   ; pieza vacía: no gasta sprite
        ld a,(BIGN)
        cp 12
        ret nc
        ld c,a
        add a,0C0h+52           ; (3800h/32 + hueco) = 1C0h + 52 + n
        ld l,a
        ld h,1
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        out (99h),a
        ld a,h
        or 40h
        out (99h),a
        ld hl,PB
        ld b,32
.u:     ld a,(hl)
        out (98h),a
        inc hl
        djnz .u
        ld a,c
        add a,a
        add a,c
        ld l,a
        ld h,0
        ld de,BIGPL
        add hl,de
        ld a,(BR)
        ld (hl),a
        inc hl
        ld a,(BCL)
        add a,a
        add a,a
        add a,a
        ld (hl),a
        inc hl
        ld a,c
        add a,52
        add a,a
        add a,a
        ld (hl),a
        ld a,c
        inc a
        ld (BIGN),a
        ret
HALF:   ; A = columna (byte), DE = destino: 16 filas desde BR
        ld hl,BW
        cp (hl)
        jr nc,.zf
        ld hl,(BD)
        ld c,a
        ld b,0
        add hl,bc
        ld a,(BW)
        ld c,a
        ld a,(BR)
        or a
        jr z,.m2
.m:     add hl,bc
        dec a
        jr nz,.m
.m2:    ld a,(BR)
        neg
        push hl
        ld hl,BH
        add a,(hl)
        pop hl
        cp 16
        jr c,.n
        ld a,16
.n:     push af
.c:     push af
        ld a,(hl)
        ld (de),a
        inc de
        add hl,bc
        pop af
        dec a
        jr nz,.c
        pop af
        neg
        add a,16
        ret z
        ld b,a
        xor a
.zz:    ld (de),a
        inc de
        djnz .zz
        ret
.zf:    ld b,16
        xor a
        jr .zz
BIGIMG: dw 0
BIGLAST: dw 0
BIGY:   db 0,0,0                ; Y, X, color
BIGN:   db 0
BW:     db 0
BH:     db 0
BD:     dw 0
BR:     db 0
BCL:    db 0
PB:     ds 32
BIGPL:  ds 36
SPL:    ds 128                  ; 32 piezas (Y, X, patrón, color)
; Choque con coches (9098h): el juego compara rival y jugador en la carretera
; a la altura del rival, pero tu coche se pinta abajo; en las curvas un rival
; un poco por delante sale muy a un lado y aun así chocabas. Ahora, además,
; el dibujo del rival (posición de A05Dh) tiene que tocar el tuyo en pantalla.
VPL     equ 110                 ; tu coche ocupa las columnas 106-159 (con margen)
VPR     equ 156
VISHIT: bit 0,(ix+4)            ; ya a tu lado o detrás: no se dibuja, choca
        jr nz,.hit
        push bc
        push de
        push hl
        exx
        push bc
        push de
        push hl
        exx
        ld b,0
        call 0A05Dh             ; C: HL = búfer (E000h + 32*y + col); cambia de banco
        ld a,l
        pop hl
        pop de
        pop bc
        exx
        pop hl
        pop de
        pop bc
        jr nc,.hit              ; fuera de pantalla: como antes
        and 1Fh
        add a,a
        add a,a
        add a,a
        push bc
        ld b,a                  ; X izquierda del rival
        push hl
        ld l,(ix+1)
        ld h,0DAh
        ld a,(hl)
        pop hl
        cp 4Bh                  ; como 9C6Fh: grande (48+ px) o mediano (32 px)
        ld c,VPL-48+1
        jr nc,.w
        ld c,VPL-32+1
.w:     ld a,b
        cp c
        pop bc
        jp c,90A3h              ; a tu izquierda
        cp VPR
        jp nc,90A3h             ; a tu derecha
.hit:   set 7,(ix+0)
        jp 909Ch
        include "bigtab.inc"
        include "sfxpaso.inc"
        assert $ <= 3C00h


; ---------------------------------------------------------------------------
; Rivales en sprites (idea de Penguin Adventure y G.P. World). Los coches
; rivales de tamaño mediano, pequeño y mínimo (imágenes 9-23 de C477h) se
; pintan en el búfer solo como silueta negra (la máscara, sin el OR del
; dibujo) y encima va un sprite 16x16 del color de cada rival. Los coches
; grandes y el propio siguen en el mapa de bits.
        output "spr_21e0.bin"
        org 21E0h
MAXPC   equ 20
SPRCAR: ; en 9CE0h, en vez de call 9DB6h. HL = imagen, DE = búfer (E000h + 32*y + col)
        push hl
        push de
        push bc
        ex de,hl                ; DE = imagen
        ld hl,IMGADR
        ld b,15
        call FINDW
        jr z,.hit
        ld a,(BIGIMG+1)         ; coche grande: solo el primero (el más lejano)
        or a
        jr nz,.no
        ld hl,BIGADR
        ld b,9
        call FINDW
        jr z,.big
.no:    pop bc
        pop de
        pop hl
        jp 9DB6h                ; no va en sprites: como siempre
.big:   ld (BIGIMG),de          ; SATW sube sus patrones y sus piezas
        pop bc
        pop de
        push de
        push bc
        call POSCOL
        ld hl,SPY
        ld de,BIGY
        ld bc,3
        ldir
        jr .full
.hit:   ld a,15
        sub b                   ; A = 0..14
        add a,a
        ld l,a
        ld h,0
        ld bc,IMGPCS
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                  ; HL = piezas
        pop bc
        pop de
        push de
        push bc
        push hl
        call POSCOL
        pop hl
        ld b,(hl)               ; piezas
        inc hl
.pc:    ld a,(SPN)
        cp MAXPC
        jr nc,.full
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld e,(hl)
        inc hl
        call PUTPC
        djnz .pc
.full:  ; silueta: el dibujo de 9DB6h sin los OR C
        xor a
        call ORPATCH
        pop bc
        pop de
        pop hl
        call 9DB6h
        push af
        ld a,0B1h               ; OR C
        call ORPATCH
        pop af
        ret
ORPATCH:
        ld (9DDEh),a
        ld (9DE7h),a
        ld (9DF0h),a
        ld (9DF9h),a
        ld (9E02h),a
        ld (9E0Bh),a
        ld (9E14h),a
        ld (9E1Dh),a
        ld (9E26h),a
        ld (9E2Fh),a
        ret

; Al final del volcado (166Dh, antes cp 160 / jp nz,fila / ei / ret; queda
; call SATW / jp nz,fila / ret): en la última fila sube la tabla de sprites,
; de cerca a lejos (A0D2h pinta de lejos a cerca y el VDP da prioridad al
; primero), y vacía la lista.
SATW:   cp 160
        ret nz
        call BIGSAT
        xor a
        out (99h),a
        ld a,5Bh                ; 1B00h, escritura
        out (99h),a
        ld a,(SPN)
        or a
        jr z,.end
        ld b,a
.e:     ld a,b
        dec a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,SPL
        add hl,de
        ld c,4
.o:     ld a,(hl)
        out (98h),a
        inc hl
        dec c
        jr nz,.o
        djnz .e
.end:   ld a,0D0h
        out (98h),a
        xor a
        ld (SPN),a
        ld a,1
        ld (SPV),a
        ld a,30
        ld (RACY),a             ; la música va a ritmo de carrera
        ei
        xor a                   ; Z: se acabó el volcado
        ret

; Quita los sprites (pantallas fuera de carrera)
SPHIDE: push af
        ld a,(SPV)
        or a
        jr z,.r
        ld a,i
        push af
        di
        xor a
        ld (SPV),a
        ld (SPN),a
        out (99h),a
        ld a,5Bh
        out (99h),a
        ld a,0D0h
        out (98h),a
        pop af
        jp po,.r
        ei
.r:     pop af
        ret
H743:   call SPHIDE
        jp 1696h
HA69:   call SPHIDE
        jp 16B9h

COLS:   db 08h,05h,0Bh,03h,0Dh  ; rojo, azul claro, amarillo, verde claro, magenta
SPN     equ 1800h           ; variables en 1800h-1854h (el juego no usa 1800h-1BD3h)
SPV     equ 1801h
SPY     equ 1802h
SPX     equ 1803h
SPC     equ 1804h
        include "sprtab.inc"
        assert $ <= 2400h

        output "hk_9ce0.bin"
        org 9CE0h
        call SPRCAR
        output "hk_166d.bin"
        org 166Dh
        call SATW
        jp nz,15BFh
        ret
        output "hk_0743.bin"
        org 0743h
        jp H743
        output "hk_0a69.bin"
        org 0A69h
        call HA69


; ---------------------------------------------------------------------------
; Más efectos (21-10-2026), sacados del Hyper Rally con musica.py de antxiko
; (Penguin Adventure no trae la ROM en su repositorio). Van en 1A30h, que el
; juego no usa; el arranque los copia al final (el copiador está en 1900h). Prioridad: choque 4 > golpe 3 > tiempo extra 2 > adelantar 1.
        output "sfx_1a30.bin"
        org 1A30h
XSTART:
SFXREQ2:                        ; 8A15h, A = número que pide el juego
        cp 1
        ld c,8                  ; 01h: carrera acabada clasificado -> pieza 94h
        jr z,JINGLE
        cp 0Ah
        ld c,10                 ; 0Ah: acabada sin clasificar -> efecto 0Bh
        jr z,JINGLE
        cp 0Bh
        ld c,9                  ; 0Bh: campeón -> pieza 9Ah
        jr z,JINGLE
        ld hl,SFXT
.f:     ld c,(hl)
        inc c
        ret z                   ; no está en la tabla: sin sonido
        dec c
        inc hl
        cp c
        jr z,.hit
        inc hl
        inc hl
        inc hl
        jr .f
.hit:   ld b,(hl)               ; prioridad
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(SFXPTR)
        ld a,h
        or l
        jr z,.go
        ld a,(SFXPRI)
        cp b
        ret nc                  ; suena otro igual o más importante
        ;  (mismo efecto: se deja acabar; el adelantamiento es muy frecuente)
.go:    ld a,b
        ld (SFXPRI),a
        ld (SFXPTR),de
        ret
SFXT:   db 0Eh,4
        dw SFX4C
        db 10h,3
        dw SFX42
        db 0Ch,2
        dw SFX07
        db 0Fh,1
        dw SFXPASO
        db 0FFh
; Fanfarria C (8-10) con el reproductor de la música del mapa
JINGLE: push ix
        ld a,i
        push af
        di
        push bc
        call MUSEND
        pop af
        ld a,c
        call MUSPLAY
        xor a
        ld (TACC),a
        ld (SFXPTR),a
        ld (SFXPTR+1),a
        ld h,a
        ld l,a
        ld (MTICK),hl
        ld (ENGT),a             ; el motor se calla (canal A para la fanfarria)
        inc a
        ld (MUSON),a
        pop af
        pop ix
        ret po
        ei
        ret
        include "sfxhr.inc"
J_META: incbin "j_meta.song"
J_NOCAL: incbin "j_nocalif.song"
XEND:
        assert $ <= 1BD0h
        output "jc_1858.bin"
        org 1858h
J_CAMP: incbin "j_campeon.song"
J_CEND:
        assert $ <= 18F0h

        output "hk_a76a.bin"
        org 0A76Ah
        jp MAPMUS
        output "hk_86da.bin"
        org 86DAh
        jp MAPWAIT
        output "hk_876b.bin"
        org 876Bh
        call MAPW2
        output "hk_87cc.bin"
        org 87CCh
        call MUSOFF

; Enganches en el código del juego
        output "hk_0599.bin"
        org 0599h
        jp SNDINT
        output "hk_8c9d.bin"
        org 8C9Dh
        call BRAKE
        output "hk_9098.bin"
        org 9098h
        jp VISHIT
        nop
        output "hk_8a15.bin"
        org 8A15h
        jp SFXREQ2
        output "hk_87d7.bin"
        org 87D7h
        call SEMBEEP
        output "hk_8323.bin"
        org 8323h
        call RACEFR

; ---------------------------------------------------------------------
; Banco 0: cabecera y arranque
; ---------------------------------------------------------------------
        output "boot.bin"
        org 4000h
        db "AB"
        dw INIT
        dw 0,0,0,0,0,0
INIT:   di
        im 1
        ld sp,0F380h
        ld a,(002Dh)            ; versión del MSX: 3 = turbo R
        cp 3
        jr c,.z80
        ld a,81h                ; CHGCPU: R800 (modo ROM) y LED de turbo
        call 0180h
        di
.z80:
        ld a,(002Bh)            ; bit 7: 50 Hz
        and 80h
        ld a,10
        jr z,.hz
        ld a,12
.hz:    ld (T_PAL),a
        ; --- slot de la ROM (página 1)
        in a,(0A8h)
        ld e,a                  ; E = A8h actual
        rrca
        rrca
        and 3
        ld c,a                  ; C = primario de la ROM
        ld hl,0FCC1h            ; EXPTBL
        call SUBOF
        ld a,(hl)               ; SLTTBL del primario (si expandido)
        and 0Ch
        ld d,a                  ; D = subslot de la ROM ya en bits 2-3
        ; --- slot de la RAM (el de la página 3)
        ld a,e
        rlca
        rlca
        and 3
        ld b,a                  ; B = primario de la RAM
        ld (T_PRAM),a
        ld a,b
        ld hl,0FCC1h
        add a,l
        ld l,a
        ld a,(hl)
        and 80h
        ld (T_EXP),a
        ld a,0FFh
        ld (T_FFR),a
        ld (T_FFA),a
        jr z,.noexp
        ld a,(0FFFFh)
        cpl
        rlca
        rlca
        and 3
        ld h,a                  ; H = subslot de la RAM
        add a,a
        add a,a
        or h
        ld l,a
        add a,a
        add a,a
        add a,a
        add a,a
        or l                    ; H * 55h
        ld (T_FFA),a
        ld (T_FFR),a
        ld a,c
        cp b
        jr nz,.noexp
        ld a,(T_FFA)            ; mismo primario: la página 1 apunta a la ROM
        and 0F3h
        or d
        ld (T_FFR),a
.noexp: ld a,b                  ; A8h todo RAM = B * 55h
        add a,a
        add a,a
        or b
        ld l,a
        add a,a
        add a,a
        add a,a
        add a,a
        or l
        ld (T_A8A),a
        and 0F3h
        ld l,a
        ld a,c
        add a,a
        add a,a
        or l
        ld (T_A8R),a
        ; --- VDP: pantalla apagada mientras se copia
        ld hl,VDPOFF
        call SETVDP
        ; --- RAM en las páginas 0, 2 y 3; ROM en la página 1
        call MODEROM
        ; --- copiar el copiador a la RAM baja y saltar a él
        ld hl,CPSRC
        ld de,COPIER
        ld bc,CPEND-CPSTART
        ldir
        ld hl,T_A8R
        ld de,V_A8R
        ld bc,7
        ldir
        jp COPIER

SUBOF:  ; HL = EXPTBL; C = primario -> HL = SLTTBL[C] si expandido, si no D=0
        ld a,l
        add a,c
        ld l,a
        ld a,(hl)
        and 80h
        jr nz,.e
        ld hl,ZERO
        ret
.e:     ld a,l
        add a,4                 ; SLTTBL = EXPTBL + 4
        ld l,a
        ret
ZERO:   db 0

MODEROM:
        ld a,(T_A8R)
        out (0A8h),a
        ld a,(T_EXP)
        or a
        ret z
        ld a,(T_FFR)
        ld (0FFFFh),a
        ret

SETVDP: ; HL = lista de 8 registros
        ld b,8
        ld c,80h
.l:     ld a,(hl)
        out (99h),a
        ld a,c
        out (99h),a
        inc hl
        inc c
        djnz .l
        ret

VDPOFF: db 2,80h,6,0FFh,3,36h,7,0
VDPON:  db 2,0E2h,6,0FFh,3,36h,7,0

; Variables de arranque (en la imagen se copian con el copiador)
CPSRC:
        disp COPIER
CPSTART:
        ld sp,COPIER
        ; 1) VRAM desde los bancos 9-10
        xor a
        out (99h),a
        ld a,40h
        out (99h),a
        ld a,VRMBANK
        ld (6000h),a
        inc a
        ld (6800h),a
        ld hl,4000h
        ld bc,4000h
.v:     ld a,(hl)
        out (98h),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.v
        ; 2) página 1 de la imagen (bancos 3-4): se deja en 8000h,
        ;    se pone RAM en la página 1 y se mueve a 4000h
        ld a,RAMBANK+2
        ld (6000h),a
        inc a
        ld (6800h),a
        ld hl,4000h
        ld de,8000h
        ld bc,4000h
        ldir
        call CMODEALL
        ld hl,8000h
        ld de,4000h
        ld bc,4000h
        ldir
        call CMODEROM
        ; 3) páginas 2 y 3 (bancos 5-8), sin tocar FFFEh-FFFFh
        ld a,RAMBANK+4
        ld (6000h),a
        inc a
        ld (6800h),a
        ld hl,4000h
        ld de,8000h
        ld bc,4000h
        ldir
        ld a,RAMBANK+6
        ld (6000h),a
        inc a
        ld (6800h),a
        ld hl,4000h
        ld de,0C000h
        ld bc,3FFEh
        ldir
        ; 4) página 0 (bancos 1-2), salvo la zona del copiador 1800h-1BFFh
        ld a,RAMBANK
        ld (6000h),a
        inc a
        ld (6800h),a
        ld hl,4000h
        ld de,0
        ld bc,1800h
        ldir
        ld hl,5C00h
        ld de,1C00h
        ld bc,2400h
        ldir
        ld hl,4000h+XSTART      ; efectos y fanfarrias (1A30h-1BCFh), detrás del copiador
        ld de,XSTART
        ld bc,XEND-XSTART
        ldir
        ld hl,4000h+J_CAMP      ; y la fanfarria larga (1858h-18EFh), debajo de su pila
        ld de,J_CAMP
        ld bc,J_CEND-J_CAMP
        ldir
        ld hl,1800h             ; variables de los sprites a cero
        ld b,5
.z:     ld (hl),0
        inc hl
        djnz .z
        ; 5) configuración de slots para el cargador de circuitos
        ld hl,V_A8R
        ld de,A8ROM
        ld bc,5
        ldir
        ld a,(V_PAL)
        ld (TSTEP),a
        ; 6) todo RAM, PSG y VDP como los deja la cinta, y al juego
        call CMODEALL
        ld b,14
        ld c,0
        ld hl,PSGTAB
.p:     ld a,c
        out (0A0h),a
        ld a,(hl)
        out (0A1h),a
        inc hl
        inc c
        djnz .p
        ld hl,CVDPON
        ld b,8
        ld c,80h
.r:     ld a,(hl)
        out (99h),a
        ld a,c
        out (99h),a
        inc hl
        inc c
        djnz .r
        ld sp,01F3h
        jp 81A0h

CMODEROM:
        ld a,(V_A8R)
        out (0A8h),a
        ld a,(V_EXP)
        or a
        ret z
        ld a,(V_FFR)
        ld (0FFFFh),a
        ret
CMODEALL:
        ld a,(V_A8A)
        out (0A8h),a
        ld a,(V_EXP)
        or a
        ret z
        ld a,(V_FFA)
        ld (0FFFFh),a
        ret

PSGTAB: db 0,0,0,0,0,0,0,0B8h,0,0,0,0,0,0
CVDPON: db 2,0E2h,6,0FFh,3,36h,7,0
; mismo orden que A8ROM, A8ALL, FFROM, FFALL, EXPF
V_A8R:  db 0
V_A8A:  db 0
V_FFR:  db 0
V_FFA:  db 0
V_EXP:  db 0
V_PRAM: db 0
V_PAL:  db 10
CPEND:
        assert $ <= XSTART
        ent

        ; Escrituras a los registros del mapper ASCII8 para que openMSX
        ; reconozca el tipo (nunca se ejecutan)
        ld (6800h),a
        ld (7800h),a
        ld (6800h),a
        ld (7800h),a
        ld (6800h),a
        ld (7800h),a
        ld (7000h),a
        ld (6000h),a
        assert $ <= 6000h
