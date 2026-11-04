"""snap.py cara_A_prototipo3.cas cara_B.cas: carga el juego en el emulador de pruebas hasta 81A0h
(codigo ya cargado) y guarda la RAM (ram.bin) y la VRAM (vram.bin) que usa mkrom.py."""
import sys, os
D = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, os.path.join(D, '..', 'emu'))
from cc import boot
m = boot(sys.argv[1], sys.argv[2])
assert m.run_until([0x81A0], 200_000_000)
open(os.path.join(D, 'ram.bin'), 'wb').write(bytes(m.peek(a) for a in range(65536)))
open(os.path.join(D, 'vram.bin'), 'wb').write(bytes(m.vram[:16384]))
