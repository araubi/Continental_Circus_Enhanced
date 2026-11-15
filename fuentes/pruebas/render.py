import sys
import zlib,struct
def png(path,w,h,rows):
    raw=b''.join(b'\0'+bytes(v for p in r for v in p) for r in rows)
    def ch(t,d): return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    open(path,'wb').write(b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+ch(b'IDAT',zlib.compress(raw))+ch(b'IEND',b''))
PAL=[(0,0,0),(0,0,0),(62,184,73),(116,208,125),(89,85,224),(128,118,241),(185,94,81),(101,219,239),(219,101,89),(255,137,125),(204,195,94),(222,208,135),(58,162,65),(183,102,181),(204,204,204),(255,255,255)]
def render(v, rows=24):
    class P(dict): pass
    px={}
    for r in range(rows):
        for c in range(32):
            n=v[0x1800+r*32+c]+256*(r//8)
            for y in range(8):
                p=v[n*8+y]; col=v[0x2000+n*8+y]; fg=PAL[col>>4]; bg=PAL[col&15]
                for x in range(8): px[c*8+x,r*8+y]=fg if p&(0x80>>x) else bg
    # sprites 16x16
    sat=v[0x1B00:0x1B80]; lst=[]
    for i in range(32):
        y,x,pt,cl=sat[i*4:i*4+4]
        if y==0xD0: break
        lst.append((y,x,pt,cl))
    for y,x,pt,cl in reversed(lst):
        y=(y+1)&255
        if cl&0x80: x-=32
        for yy in range(16):
            for xx in range(16):
                b=v[0x3800+(pt&0xFC)*8+(xx//8)*16+yy]
                if b&(0x80>>(xx%8)) and (cl&15) and 0<=x+xx<256 and 0<=y+yy<rows*8: px[x+xx,y+yy]=PAL[cl&15]
    return px
for f in sys.argv[2:]:
    v=open(f,'rb').read(); rows=int(sys.argv[1])
    px=render(v,rows); Z=3
    img=[[px[x//Z,y//Z] for x in range(256*Z)] for y in range(rows*8*Z)]
    png(f.replace('.bin','.png'),256*Z,rows*8*Z,img)
