# Convierte la imagen de la recreativa a SCREEN 2 (2 colores cada 8x1) con difusión de error.
import numpy as np, itertools, sys
from PIL import Image, ImageEnhance
PAL={1:(0,0,0),2:(33,200,66),3:(94,220,120),4:(84,85,237),5:(125,118,252),6:(212,82,77),7:(66,235,245),
 8:(252,85,84),9:(255,121,120),10:(212,193,84),11:(230,206,128),12:(33,176,59),13:(201,91,186),14:(204,204,204),15:(255,255,255)}
idx=list(PAL); P=np.array([PAL[i] for i in idx],float)
import os
W=np.array([1.0,float(os.environ.get("CW","1")),float(os.environ.get("CW","1"))])
def lab(c):
    c=np.asarray(c,float)/255; c=np.where(c>0.04045,((c+0.055)/1.055)**2.4,c/12.92)
    M=np.array([[0.4124,0.3576,0.1805],[0.2126,0.7152,0.0722],[0.0193,0.1192,0.9505]])
    xyz=c@M.T/np.array([0.9505,1,1.089])
    f=np.where(xyz>0.008856,np.cbrt(xyz),7.787*xyz+16/116)
    return np.stack([116*f[...,1]-16,500*(f[...,0]-f[...,1]),200*(f[...,1]-f[...,2])],-1)
PRGB=P.copy(); P=lab(P)
def conv(img, strength=0.8, top=0):
    a=lab(np.asarray(img.convert('RGB'),float)); H,Wd,_=a.shape
    pairs=list(itertools.combinations(range(len(idx)),2))
    PA=P[[p[0] for p in pairs]]; PB=P[[p[1] for p in pairs]]
    pat=np.zeros((H,Wd//8),np.uint8); col=np.zeros((H,Wd//8),np.uint8)
    out=np.zeros((H,Wd,3))
    for y in range(H):
        for bx in range(Wd//8):
            px=a[y,bx*8:bx*8+8]
            carry=np.zeros((len(pairs),3)); err=np.zeros(len(pairs))
            for i in range(8):
                v=px[i]+carry
                da=(((v-PA)**2)*W).sum(1); db=(((v-PB)**2)*W).sum(1)
                ch=np.where((da<=db)[:,None],PA,PB)
                err+=np.minimum(da,db); carry=(v-ch)*strength*7/16
            k=int(err.argmin()); A,B=P[pairs[k][0]],P[pairs[k][1]]
            bits=0
            for i in range(8):
                x=bx*8+i; v=a[y,x]
                da=(((v-A)**2)*W).sum(); db=(((v-B)**2)*W).sum()
                c=A if da<=db else B
                if da>db: bits|=0x80>>i
                out[y,x]=PRGB[[j for j in range(len(P)) if (P[j]==c).all()][0]]; e=(v-c)*strength
                if x+1<Wd: a[y,x+1]+=e*7/16
                if y+1<H:
                    if x>0: a[y+1,x-1]+=e*3/16
                    a[y+1,x]+=e*5/16
                    if x+1<Wd: a[y+1,x+1]+=e*1/16
            ia,ib=idx[pairs[k][0]],idx[pairs[k][1]]
            # normalizar: tinta = color de los bits a 1
            pat[y,bx]=bits; col[y,bx]=(ib<<4)|ia
    return pat,col,out.astype(np.uint8)
if __name__=='__main__':
    st=float(sys.argv[1]) if len(sys.argv)>1 else 0.8
    src=Image.open('arcade.png').convert('RGB')
    w,h=src.size; cw=w-12; ch=round(cw/(256/176)); y0=(h-ch)//2
    src=src.crop((6,y0,6+cw,y0+ch))
    src=ImageEnhance.Color(src).enhance(1.15)
    sm=src.resize((256,176),Image.LANCZOS)
    from PIL import ImageFilter
    if len(sys.argv)>2: sm=sm.filter(ImageFilter.UnsharpMask(1.2,int(sys.argv[2]),2))
    pat,col,out=conv(sm,st)
    np.save('pat.npy',pat); np.save('col.npy',col)
    Image.fromarray(out).save('img_%s.png'%st)
    Image.fromarray(out).resize((768,528),Image.NEAREST).save('img_%s_x3.png'%st)
