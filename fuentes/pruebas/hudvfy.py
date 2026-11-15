import sys
rom=open(sys.argv[2],'rb').read(); ram=rom[0x2000:0x12000]
def glyph(c):
    g=ram[0xAA14:0xAA1C] if c==0x6D else ram[0x3C00+c*8:0x3C00+c*8+8]
    return bytes(b|(b>>1) for b in g)
d=open(sys.argv[1],'rb').read(); R=1+28+0x300; n=len(d)//R; bad=0; first=None
for i in range(n):
    r=d[i*R:(i+1)*R]; tenth=r[0]; strs=r[1:29].split(b'\0'); v=r[29:]
    speed,score,rank,qual,tim=strs[:5]
    exp={}
    def normal(s,row,col):
        for k,c in enumerate(s): exp[row*32+col+k]=glyph(c)
    def double(s,row,col):
        for k,c in enumerate(s):
            g=glyph(c); exp[row*32+col+k]=bytes(g[j//2] for j in range(8)); exp[(row+1)*32+col+k]=bytes(g[4+j//2] for j in range(8))
    normal(speed,2,6); normal(score,1,6); double(rank,1,20); double(qual,1,28); double(tim,1,14); normal(bytes([tenth]),2,17)
    ok=all(v[c*8:c*8+8]==g for c,g in exp.items())
    if not ok:
        bad+=1
        if first is None: first=(i,[c for c,g in exp.items() if v[c*8:c*8+8]!=g],strs[:5],chr(tenth))
print('marcadores',n,'incorrectos',bad,'primero',first)
