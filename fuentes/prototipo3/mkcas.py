"""mkcas.py A.cas salida.cas parche...  -> cara A con parches aplicados a los bloques 0400h y 5B00h (checksum XOR recalculado)."""
import sys
H = bytes([0x1F,0xA6,0xDE,0xBA,0xCC,0x13,0x7D,0x74])
d = bytearray(open(sys.argv[1],'rb').read())
pos=[]; i=0
while (j := d.find(H, i)) >= 0: pos.append(j); i = j+1
blocks = {0x0400: (pos[6]+8, 0x1400), 0x5B00: (pos[10]+8, 0xA4FE)}   # inicio del bloque (flag FFh), longitud
for p in sys.argv[3:]:
    if p == 'nodelay': a, data = 0x8940, b'\x00'
    else:
        s, f = p.split('@'); a = int(s,16); data = open(f,'rb').read()
    for base,(off,ln) in blocks.items():
        if base <= a and a+len(data) <= base+ln:
            d[off+1+a-base : off+1+a-base+len(data)] = data; break
    else: raise SystemExit('fuera de bloque: %s' % p)
for base,(off,ln) in blocks.items():
    x = 0
    for b in d[off:off+1+ln]: x ^= b
    d[off+1+ln] = x
open(sys.argv[2],'wb').write(d)
