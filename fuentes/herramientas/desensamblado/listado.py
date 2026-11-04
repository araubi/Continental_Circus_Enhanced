#!/usr/bin/env python3
"""listado.py mem.bin exec1.bin [exec2.bin...] > listado.asm
Listado comentado de Continental Circus MSX (imagen de memoria tras la carga).
Código = direcciones ejecutadas en el emulador + recorrido estático desde ellas; el resto, db.
Etiquetas solo en destinos de salto/llamada."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import z80dis as Z

C = {
0x0400:'Tablas 0400h-04FFh: conversión de nibbles para atributos Spectrum -> color MSX',
0x0500:'Rellena BC bytes de VRAM desde HL con A (fija dirección con 0520h)',
0x0520:'SETWRT propio: HL = dirección VRAM de escritura (DI ... EI)',
0x052F:'SETRD propio: HL = dirección VRAM de lectura',
0x0540:'Borde (R#7) = 44h',
0x0549:'Lee joystick 1 (PSG R#14) y lo reordena en los bits 0-4',
0x0582:'Interrupción (0038h): lee el estado del VDP y suma 1 al reloj 8A0Eh en la mitad de las interrupciones',
0x059D:'Reloj: 8A0Eh += 2 (se llama al empezar cada volcado de pantalla)',
0x05E4:'Dirección de pantalla Spectrum (DE) -> dirección VRAM SCREEN 2 (automodificable en 05FDh)',
0x0645:'Lee el teclado entero y devuelve ASCII de la tecla pulsada (tabla 0671h)',
0x0701:'Muestra la pantalla de carga guardada en E000h',
0x0743:'Copia la pantalla Spectrum de RAM (4000h-57FFh) a los patrones VRAM 0000h-17FFh',
0x0801:'Atributos Spectrum (5800h, 768 bytes) -> tabla de color VRAM 2000h, 8 bytes por celda',
0x0850:'Igual que 0801h pero solo filas 8-17, y solo si cambió la columna 0 (comparación con 0840h)',
0x09AD:'Cargador de cinta en tiempo de juego (TAPION/TAPIN de la BIOS con stub en FC9Ah, formato flag+datos+XOR)',
0x0A69:'Dibuja un texto de 10 filas desde el búfer E280h',
0x0AE9:'Borra la pantalla Spectrum en RAM y la vuelca entera (0743h + 0801h)',
0x0B39:'Lectura de teclado: fila del PPI en A',
0x0B5A:'Menú: comprueba RETURN para empezar',
0x0B70:'Redefinir teclas (6 teclas -> tabla 17F4h: máscaras + filas)',
0x0C82:'RST 18h: espera fija de ~63.000 ciclos (LDIR de 0040h sobre sí mismo, 3000 bytes) con DI',
0x0CB9:'RST 10h: escribe A en la dirección de pantalla Spectrum DE, directamente en VRAM (un byte por llamada, ~490 ciclos)',
0x0D33:'Tabla del volcado: por cada línea de la zona de juego, (dirección VRAM, línea del búfer). Se recorre con POP',
0x1033:'VOLCADO DE LA ZONA DE JUEGO (160 líneas, filas 4-23). Cada byte: dos OUT a 99h para fijar la dirección y un OUT a 98h. ~484.000 ciclos por fotograma',
0x1065:'  Bucle 1: líneas de cielo, 32 bytes FFh por línea',
0x124D:'  Bucle 2: franja del horizonte desde E200h',
0x14AC:'  Bucle 3: líneas de carretera desde el búfer lineal E400h (32 bytes por línea)',
0x16E2:'  Sale con SP fijo a 1BF6h y EI',
0x17F4:'Tabla de teclas: 6 máscaras + 6 filas de la matriz (valores por defecto: O, P, STOP, Q, A, ESC)',
0x81A0:'ENTRADA DEL JUEGO (tras la carga)',
0x81C6:'Bucle principal: menú, partida, tabla de récords',
0x827A:'Inicio de carrera',
0x88C5:'Modo demostración',
0x8919:'FOTOGRAMA DE CARRERA: lógica, carretera, objetos, volcado, marcador',
0x8940:'RST 18h: espera fija (se puede quitar)',
0x8941:'Volcado de la zona de juego (8B3Fh -> 1033h)',
0x8944:'B4CAh cuenta líneas volcadas; cada 160 suma 1 al reloj (89C0h): compensa las interrupciones perdidas con DI',
0x8966:'Tiempo de carrera: 8A0Eh / 6 -> décimas que se restan a AF35h-AF36h (BCD)',
0x8998:'Marcador (AE84h)',
0x89C0:'Reloj: 8A0Eh += 1',
0x91A0:'Lógica de carrera (sin analizar en detalle), ~2.000 ciclos/fotograma',
0x92E6:'Lógica de carrera (sin analizar en detalle), ~25.000 ciclos/fotograma',
0x9277:'Lógica de carrera (sin analizar en detalle), ~29.000 ciclos/fotograma',
0x93BD:'Lógica de carrera (sin analizar en detalle), ~23.000 ciclos/fotograma',
0x9571:'GENERADOR DE CARRETERA: rellena el búfer lineal E400h-F7FFh de abajo arriba con PUSH (~117.000 ciclos)',
0xA0D2:'Sin analizar en detalle (~40.000 ciclos/fotograma)',
0xA927:'BCD -> dígitos ASCII (con supresión de ceros)',
0xA9F7:'Imprime un carácter (fuente 3C00h, negrita x|x>>1) con 8 RST 10h',
0xAA1C:'Imprime un carácter de doble altura con 16 RST 10h',
0xAA4C:'Imprime cadena (normal) terminada en 0: HL texto, DE dirección Spectrum',
0xAA5A:'Imprime cadena (doble altura)',
0xAE84:'MARCADOR: suma puntos y reimprime puntuación, velocidad, tiempo, puesto (~131.000 ciclos)',
}
SEC = {0x0400:'Bloque 0400h-17FFh (capa MSX del port: VDP, teclado, cinta)', 0x3C00:'Bloque 3C00h-3FFFh: fuente (como la ROM del Spectrum)',
       0x5B00:'Bloque 5B00h-FFFDh: juego (código Spectrum + adaptaciones)'}

def main():
    mem = open(sys.argv[1], 'rb').read()
    ex = bytearray(65536)
    for f in sys.argv[2:]:
        e = open(f, 'rb').read()
        for i in range(65536):
            if e[i]: ex[i] = 1
    D = Z.Dis(mem, 0)
    code = set(); labels = set(); seen = set()
    work = [i for i in range(65536) if ex[i]] + list(C.keys())
    for pc in work:
        while pc not in seen and 0 <= pc < 0x10000:
            if not (0x400 <= pc < 0x1800 or 0x5B00 <= pc): break
            if pc in (0x0D33, 0x17F4, 0x0400): break
            seen.add(pc)
            t, l, f, tg = D.dec(pc)
            if t == '?': break
            for k in range(l): code.add(pc + k)
            for x in tg: labels.add(x)
            if f in ('jp', 'ret', 'stop'): break
            pc += l
    out = ['; Continental Circus (Virgin Mastertronic, 1989) - versión MSX en cinta',
           '; Conversión: NEW FRONTIER, código S. Casamiquela (créditos del propio juego).',
           '; Listado generado a partir de la imagen de memoria tras la carga. "*" = ejecutado en el emulador.', '']
    for lo, hi in ((0x0400, 0x1800), (0x3C00, 0x4000), (0x5B00, 0x10000)):
        out.append(''); out.append('; ' + '=' * 70); out.append('; ' + SEC[lo]); out.append('; ' + '=' * 70)
        pc = lo
        while pc < hi:
            if pc in C: out.append(''); out.append('; ---- ' + C[pc])
            if pc in labels: out.append('L%04X:' % pc)
            if pc in code:
                t, l, f, tg = D.dec(pc)
                hx = ' '.join('%02X' % mem[(pc + k) & 0xFFFF] for k in range(l))
                out.append('  %04X %s %-12s  %s' % (pc, '*' if ex[pc] else ' ', hx, t))
                pc += l
            else:
                q = pc; bs = []
                while q < hi and q not in code and len(bs) < 16 and (q == pc or (q not in labels and q not in C)):
                    bs.append(mem[q]); q += 1
                asc = ''.join(chr(c) if 32 <= c < 127 else '.' for c in bs)
                out.append('  %04X   db %-48s ; %s' % (pc, ','.join('%02X' % c for c in bs), asc))
                pc = q
    print('\n'.join(out))

if __name__ == '__main__': main()
