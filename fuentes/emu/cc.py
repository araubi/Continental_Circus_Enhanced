"""Arranque de Continental Circus en el arnés: cargador 'alicia' + cinta emulada (TAPION/TAPIN)."""
import os, sys, ctypes as C
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from msx import MSX
X = os.path.join(HERE, '..', 'x')
H = bytes([0x1F,0xA6,0xDE,0xBA,0xCC,0x13,0x7D,0x74])

def chunks(path):
    d = open(path, 'rb').read(); pos = []; i = 0
    while (j := d.find(H, i)) >= 0: pos.append(j); i = j + 1
    return [d[p+8:(pos[k+1] if k+1 < len(pos) else len(d))] for k, p in enumerate(pos)]

def boot(casA, casB, inst=None):
    m = MSX(inst)
    m.L.emu_add_rom(0, 0, bytes([0xC9])*0x8000, 0x8000, 0)   # BIOS ficticia: solo trampas de cinta
    m.add_ram(3, 0)
    A = chunks(casA); B = chunks(casB)
    blks = A[4:] + B
    stream = b''; offs = []
    for b in blks: offs.append(len(stream)); stream += b
    arr = (C.c_uint32 * len(offs))(*offs)
    m.L.emu_set_tape(stream, len(stream), arr, len(offs))
    m.slots(0xFF)
    ldr = A[3][6:]
    for i, v in enumerate(ldr): m.poke(0xE000 + i, v)
    m.slots(0xFF)
    for r, v in enumerate([2, 0xE0, 6, 0xFF, 3, 0x36, 7, 0]): m.set_vreg(r, v)
    v = m.vram   # lo que deja SCREEN 2 de BASIC
    for i in range(768): v[0x1800+i] = i & 255
    for i in range(32): v[0x1B00+i*4] = 0xD1
    m.set('pc', 0xE148); m.set('sp', 0xF000); m.set('iff', 0)
    return m

def patch(m, specs, F=59736):
    """Espera a 81A0h (código ya cargado) y aplica parches 'nodelay' o 'ADDR@fichero'."""
    assert m.run_until([0x81A0], F*2000)
    for p in specs:
        if p == 'nodelay': m.poke(0x8940, 0x00)
        else:
            a, f = p.split('@'); d = open(f, 'rb').read()
            for i, v in enumerate(d): m.poke(int(a, 16) + i, v)
