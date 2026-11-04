"""Rivales 9-23 de la tabla C477h -> sprites 16x16 (3800h) y tabla sprtab.inc."""
import os
D=os.path.dirname(os.path.abspath(__file__))
d=open(os.path.join(D,'ram.bin'),'rb').read()
base=0xC477
pats=bytearray(); adrs=[]; pieces=[]
for k in range(9,24):
    off=(d[base+2*k]<<8)|d[base+2*k+1]; p=base+off
    w,h=d[p],d[p+1]; adrs.append(p)
    px=[[(d[p+2+y*w+x//8]>>(7-x%8))&1 for x in range(w*8)] for y in range(h)]
    pl=[]
    for dy in range(0,h,16):
        for dx in range(0,w*8,16):
            pat=bytearray(32)
            for yy in range(16):
                for xx in range(16):
                    y,x=dy+yy,dx+xx
                    if y<h and x<w*8 and px[y][x]:
                        pat[(xx//8)*16+yy]|=0x80>>(xx%8)
            if any(pat):
                pl.append((dy,dx,len(pats)//32*4)); pats+=pat
    pieces.append(pl)
assert len(pats)<=0x800, len(pats)
open(os.path.join(D,'sprpat.bin'),'wb').write(pats)
with open(os.path.join(D,'sprtab.inc'),'w') as f:
    f.write('; generado por gensp.py\nIMGADR: dw '+','.join('%05Xh'%a for a in adrs)+'\n')
    f.write('IMGPCS: dw '+','.join('PC%d'%k for k in range(9,24))+'\n')
    for k,pl in zip(range(9,24),pieces):
        f.write('PC%d: db %d'%(k,len(pl))+''.join(', %d,%d,%d'%t for t in pl)+'\n')
print(len(pats)//32,'patrones;', [len(p) for p in pieces])
