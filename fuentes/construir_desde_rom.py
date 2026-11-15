"""Construye Continental Circus Enhanced a partir de una ROM ya publicada (sin las cintas).

uso: python3 construir_desde_rom.py [ROM_base] [ROM_salida]

Por defecto parte de releases/ContinentalCircus_Enhanced_v1.0.rom y deja el resultado en
fuentes/ContinentalCircus_Enhanced.rom. De la ROM base se aprovechan la imagen de RAM del juego
(bancos 1-8), la VRAM, los circuitos y la pantalla final; encima se vuelven a poner todos los
parches ensamblados desde las fuentes (prototipo3/ y rom/). Necesita Python 3 y sjasmplus 1.24
(variable SJASMPLUS si no está en el PATH). Para construir desde las cintas, ver construir.py.
"""
import sys, os, re, hashlib, subprocess
D = os.path.dirname(os.path.abspath(__file__))
SJ = os.environ.get('SJASMPLUS', 'sjasmplus')
BASE = os.path.join(D, '..', 'releases', 'ContinentalCircus_Enhanced_v1.0.rom')
BASE_SHA1 = '1a067c66ccf9b57c7da0d1251f9dccff6c5e6909'
# (fichero, dirección) de rom/, en el mismo orden que mkrom.py
ROM_PARCHES = [('rt_fb03.bin', 0xFB03), ('rt_fd01.bin', 0xFD01), ('snd_2000.bin', 0x2000),
    ('hk_0599.bin', 0x0599), ('hk_8a15.bin', 0x8A15), ('hk_8323.bin', 0x8323), ('hk_87d7.bin', 0x87D7),
    ('mus_2400.bin', 0x2400), ('songs_2800.bin', 0x2800), ('hk_a76a.bin', 0xA76A), ('hk_86da.bin', 0x86DA),
    ('hk_87cc.bin', 0x87CC), ('hk_876b.bin', 0x876B), ('spr_21e0.bin', 0x21E0), ('hk_9ce0.bin', 0x9CE0),
    ('hk_166d.bin', 0x166D), ('hk_0743.bin', 0x0743), ('hk_0a69.bin', 0x0A69), ('sfx_1a30.bin', 0x1A30),
    ('jc_1858.bin', 0x1858), ('hk_8c9d.bin', 0x8C9D), ('hk_9098.bin', 0x9098),
    ('hk_8c84.bin', 0x8C84), ('hk_a66c.bin', 0xA66C),
    ('hk_8379.bin', 0x8379), ('hk_83c0.bin', 0x83C0), ('hk_83db.bin', 0x83DB), ('hk_83ec.bin', 0x83EC), ('hk_83fa.bin', 0x83FA), ('hk_83fd.bin', 0x83FD), ('hk_8442.bin', 0x8442),
    ('hk_0b26.bin', 0x0B26), ('hk_a7a5.bin', 0xA7A5),
    ('hk_9571.bin', 0x9571), ('hk_96f2.bin', 0x96F2),
    ('hk_ad0c.bin', 0xAD0C), ('hk_a835.bin', 0xA835), ('hk_a889.bin', 0xA889), ('hk_0c89.bin', 0x0C89)]

def sha1(b): return hashlib.sha1(b).hexdigest()
def run(cmd, cwd):
    print('>', ' '.join(cmd))
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if r.returncode or ('Errors: 0' not in r.stdout + r.stderr and cmd[0] == SJ):
        sys.exit(r.stdout + r.stderr)
    return r.stdout

base = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else BASE)
out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else os.path.join(D, 'ContinentalCircus_Enhanced.rom'))
rom = bytearray(open(base, 'rb').read())
assert len(rom) == 0x40000, 'la ROM base no mide 256 KB'
if sha1(rom) != BASE_SHA1: print('OJO: la ROM base no es la v1.0 (SHA-1 %s)' % sha1(rom))
ram = rom[0x2000:0x12000]

# 1. Prototipo 3 (volcado, marcador y reloj): se ensambla y se pone en la imagen de RAM
P = os.path.join(D, 'prototipo3')
print(run([sys.executable, 'build.py'], P).strip())
open(os.path.join(P, 'ffblk.bin'), 'wb').write(b'\xff' * 256)
for p in open(os.path.join(P, 'parches3.txt')).read().split():
    if p == 'nodelay': ram[0x8940] = 0; continue
    a, f = p.split('@'); b = open(os.path.join(P, f), 'rb').read()
    a = int(a, 16); ram[a:a+len(b)] = b

# 2. Código de la ROM: sprites desde las imágenes del juego, ensamblado y parches
R = os.path.join(D, 'rom')
open(os.path.join(R, 'ram.bin'), 'wb').write(ram)
run([sys.executable, 'gensp.py'], R)
run([SJ, '--nologo', '--sym=cc.sym', 'ccrom.asm'], R)
# la cola del volcado (enganche de SATW) se mueve si cambia blit3.asm: su dirección sale de p3sym.inc
tail = int(re.search(r'BLITTAIL equ 0*([0-9A-F]+)h', open(os.path.join(R, 'p3sym.inc')).read()).group(1), 16)
for f, a in ROM_PARCHES:
    if f == 'hk_166d.bin': a = tail
    b = open(os.path.join(R, f), 'rb').read(); ram[a:a+len(b)] = b
ram[0x1800:0x1805] = bytes(5)   # variables de los sprites a cero (como mkrom.py)

# 3. Montaje: banco 0 nuevo e imagen de RAM; el resto de la ROM base no cambia
boot = open(os.path.join(R, 'boot.bin'), 'rb').read()
rom[0:0x2000] = b'\xFF' * 0x2000
rom[0:len(boot)] = boot
rom[0x2000:0x12000] = ram
sp = open(os.path.join(R, 'sprpat.bin'), 'rb').read(); rom[0x12000+0x3800:0x12000+0x3800+len(sp)] = sp
open(out, 'wb').write(rom)
print('ROM:', out, 'SHA-1', sha1(rom))
print('Idéntica a la base' if sha1(rom) == sha1(open(base, 'rb').read()) else 'Distinta de la base (normal si hay cambios)')
