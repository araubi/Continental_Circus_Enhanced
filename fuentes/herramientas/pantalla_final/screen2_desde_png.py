# Pasa un PNG de 256x192 retocado a mano (paleta TMS9918) a SCREEN 2 (6144 patrones + 6144 colores)
# y avisa de los tramos de 8x1 con más de 2 colores (los arregla quedándose con los 2 más frecuentes).
# Uso: python3 screen2_desde_png.py entrada.png salida.scr
import sys
from PIL import Image
from collections import Counter
PAL={1:(0,0,0),2:(33,200,66),3:(94,220,120),4:(84,85,237),5:(125,118,252),6:(212,82,77),7:(66,235,245),
 8:(252,85,84),9:(255,121,120),10:(212,193,84),11:(230,206,128),12:(33,176,59),13:(201,91,186),14:(204,204,204),15:(255,255,255)}
# colores del Spectrum que suelen colarse al copiar letreros
EXTRA={(255,255,0):11,(215,215,0):10,(255,0,255):13,(215,0,215):13,(0,215,0):2,(0,255,0):3}
inv={v:k for k,v in PAL.items()}
d=lambda a,b:sum((x-y)**2 for x,y in zip(a,b))
def ci(c): return inv.get(c) or EXTRA.get(c) or min(PAL,key=lambda k:d(PAL[k],c))
im=Image.open(sys.argv[1]).convert('RGB'); assert im.size==(256,192)
vp=bytearray(6144); vc=bytearray(6144); bad=[]
for y in range(192):
    for cx in range(32):
        px=[ci(im.getpixel((cx*8+i,y))) for i in range(8)]; cnt=Counter(px)
        if len(cnt)>2: bad.append((y,cx*8))
        top=[k for k,_ in cnt.most_common(2)]
        if len(top)==1: top.append(1 if top[0]!=1 else 15)
        fg,bg=top[1],top[0]; bits=0
        for i,p in enumerate(px):
            q=p if p in (fg,bg) else min((fg,bg),key=lambda k:d(PAL[k],PAL[p]))
            if q==fg: bits|=0x80>>i
        o=(y//8)*256+cx*8+(y&7); vp[o]=bits; vc[o]=(fg<<4)|bg
print(len(bad),'tramos con más de 2 colores (línea, x):',bad)
open(sys.argv[2],'wb').write(bytes(vp)+bytes(vc))
