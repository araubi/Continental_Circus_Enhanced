"""Construye Continental Circus Enhanced a partir de TU cinta original (las dos caras).

uso: python3 construir.py Continental_Circus_SideA.cas Continental_Circus_SideB.cas

Necesita Python 3 con Pillow, gcc y sjasmplus 1.24 (variable SJASMPLUS si no está en el PATH).
Deja la ROM en fuentes/ContinentalCircus_Enhanced.rom y comprueba que es idéntica a la de releases/.
"""
import sys, os, hashlib, subprocess, shutil
D = os.path.dirname(os.path.abspath(__file__))
SJ = os.environ.get('SJASMPLUS', 'sjasmplus')
SHA1 = {'A': 'a5a62d3f779caea14f62e7505d5874811f6504af', 'B': 'd36e8832612a9e949a8b38735f6397b05edbfedf'}
ROM_SHA1 = '1a067c66ccf9b57c7da0d1251f9dccff6c5e6909'

def sha1(p): return hashlib.sha1(open(p, 'rb').read()).hexdigest()
def run(cmd, cwd):
    print('>', ' '.join(cmd))
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if r.returncode or 'Errors: 0' not in r.stdout + r.stderr and cmd[0] == SJ:
        sys.exit(r.stdout + r.stderr)
    return r.stdout

if len(sys.argv) != 3: sys.exit(__doc__)
casA, casB = (os.path.abspath(a) for a in sys.argv[1:])
for k, p in zip('AB', (casA, casB)):
    if sha1(p) != SHA1[k]: sys.exit('La cara %s no es la cinta esperada (SHA-1 %s)' % (k, SHA1[k]))
B = os.path.join(D, 'build'); os.makedirs(B, exist_ok=True)

# 1. Prototipo 3: volcado rápido, marcador y reloj, parcheados sobre la cara A
P = os.path.join(D, 'prototipo3')
run([sys.executable, 'build.py'], P)
open(os.path.join(P, 'ffblk.bin'), 'wb').write(b'\xff' * 256)
protoA = os.path.join(B, 'A_prototipo3.cas')
run([sys.executable, 'mkcas.py', casA, protoA] + open(os.path.join(P, 'parches3.txt')).read().split(), P)

# 2. Emulador de pruebas: carga la cinta y guarda RAM y VRAM con el juego cargado
E = os.path.join(D, 'emu')
run(['gcc', '-O2', '-shared', '-fPIC', '-o', 'libmsx.so', 'msxemu.c', 'z80.c'], E)
R = os.path.join(D, 'rom')
run([sys.executable, 'snap.py', protoA, casB], R)
run([sys.executable, 'gensp.py'], R)          # sprites de los rivales desde sus imágenes

# 3. ROM ASCII8 de 256 KB
run([SJ, '--nologo', '--sym=cc.sym', 'ccrom.asm'], R)
out = os.path.join(D, 'ContinentalCircus_Enhanced.rom')
run([sys.executable, 'mkrom.py', casB, out], R)
h = sha1(out)
print('ROM:', out, 'SHA-1', h)
print('Idéntica a releases/' if h == ROM_SHA1 else 'OJO: distinta de releases/ (%s)' % ROM_SHA1)
