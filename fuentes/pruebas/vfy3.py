import sys
d=open(sys.argv[1],'rb').read(); R=3+0x1600+0x1400; n=len(d)//R; bad=0; pit=0; trans=0; prev=0; badrows={}
for i in range(n):
    r=d[i*R:(i+1)*R]; n1,n12,pv=r[0],r[1],r[2]; ram=r[3:3+0x1600]; v=r[3+0x1600:]
    pit+=pv!=0; trans+=(prev!=0 and pv==0); prev=pv
    fb=False
    for L in range(160):
        if L<n1: exp=b'\xff'*32
        elif L<n12: o=(L-n1)*32; exp=ram[o:o+32]
        else: o=0x200+L*32; exp=ram[o:o+32]
        got=bytes(v[(L//8)*256+c*8+L%8] for c in range(32))
        if pv and 8<=L<24: got=got[:24]+exp[24:29]+got[29:]   # letrero PIT IN en la VRAM
        if got!=exp: fb=True; badrows[L//8]=badrows.get(L//8,0)+1
    bad+=fb
print('imágenes',n,'| con letrero en VRAM',pit,'| borrados del letrero',trans,'| con diferencias',bad,dict(sorted(badrows.items())))
