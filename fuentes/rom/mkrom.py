"""Monta Continental Circus ROM (ASCII8 256 KB) a partir del estado del prototipo 3 en 81A0h."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'emu'))
from cc import chunks
D = os.path.dirname(os.path.abspath(__file__))
rd = lambda f: open(os.path.join(D, f), 'rb').read()
ram = bytearray(rd('ram.bin'))
for f, a in [('rt_fb03.bin', 0xFB03), ('rt_fd01.bin', 0xFD01), ('snd_2000.bin', 0x2000),
             ('hk_0599.bin', 0x0599), ('hk_8a15.bin', 0x8A15), ('hk_8323.bin', 0x8323), ('hk_87d7.bin', 0x87D7),
             ('mus_2400.bin', 0x2400), ('songs_2800.bin', 0x2800), ('hk_a76a.bin', 0xA76A), ('hk_86da.bin', 0x86DA), ('hk_87cc.bin', 0x87CC), ('hk_876b.bin', 0x876B), ('spr_21e0.bin', 0x21E0), ('hk_9ce0.bin', 0x9CE0), ('hk_166d.bin', 0x166D), ('hk_0743.bin', 0x0743), ('hk_0a69.bin', 0x0A69), ('sfx_1a30.bin', 0x1A30), ('jc_1858.bin', 0x1858), ('hk_8c9d.bin', 0x8C9D), ('hk_9098.bin', 0x9098)]:
    b = rd(f); ram[a:a+len(b)] = b
# teclas por defecto (Rubén): cursores izq./der. giran, ARRIBA acelera, ESPACIO cambia de marcha,
# STOP pausa, ESC abandona. Orden: izquierda, derecha, pausa, acelerador, marcha, abandonar
ram[0x1800:0x1805] = bytes(5)   # variables de los sprites a cero
ram[0x17F4:0x1800] = bytes([0x10,0x80,0x10,0x20,0x01,0x04, 0xF8,0xF8,0xF7,0xF8,0xF8,0xF7])
vram = bytearray(rd('vram.bin'))
sp = rd('sprpat.bin'); vram[0x3800:0x3800+len(sp)] = sp   # rivales en sprites
B = chunks(sys.argv[1])
tracks = {}
for i in range(0, len(B), 2):
    h, d = B[i], B[i+1]
    assert h[0] == 0 or len(h) < 20, (i, len(h))
    name = h[1:7].decode()
    data = d[1:-1]
    x = 0
    for c in d[:-1]: x ^= c
    assert x == d[-1], name
    tracks[name] = data
    print(name, len(data), 'cabecera', h.hex())
boot = rd('boot.bin')
rom = bytearray(b'\xFF' * 0x40000)
rom[0:len(boot)] = boot
rom[0x2000:0x12000] = ram
rom[0x12000:0x16000] = vram
for n in range(1, 10):
    t = tracks['TRACK%d' % n]
    o = (10 + n) * 0x2000
    rom[o:o+len(t)] = t
fin = rd('final.scr'); rom[20*0x2000:20*0x2000+len(fin)] = fin   # pantalla final MSX1
open(os.path.join(D, sys.argv[2]), 'wb').write(rom)
# heurística de openMSX: escrituras LD (nn),A
cnt = {}
for i in range(len(rom) - 2):
    if rom[i] == 0x32:
        a = rom[i+1] | rom[i+2] << 8
        if a in (0x5000,0x9000,0xB000,0x4000,0x8000,0xA000,0x6800,0x7800,0x6000,0x7000,0x77FF): cnt[hex(a)] = cnt.get(hex(a),0)+1
print(cnt)
