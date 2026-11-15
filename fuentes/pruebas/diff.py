"""Prueba diferencial del generador de carretera (9571h): rutina de la v1.0 contra la actual.

uso: python3 diff.py CAPTURA [semilla] [variantes_por_imagen]
CAPTURA es la salida de cap.tcl (64 KB de RAM por imagen, al entrar en 9571h). Con variantes > 0
altera al azar las tablas de tramos. Necesita ../emu/libmsx.so:
  cd ../emu && gcc -O2 -shared -fPIC -o libmsx.so msxemu.c z80.c
"""
import ctypes as C, sys, random, os
F=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..')
L=C.CDLL(os.path.join(F,'emu','libmsx.so'))
L.emu_add_ram.restype=C.POINTER(C.c_uint8); L.emu_ram_ptr.restype=C.POINTER(C.c_uint8)
L.emu_bp_map.restype=C.POINTER(C.c_uint8); L.emu_cycles.restype=C.c_ulong; L.emu_run.argtypes=[C.c_ulong]
L.emu_init(); L.emu_add_ram(3,0); L.emu_set_slots(0xFF,0,0,0,0)
ram=C.cast(L.emu_ram_ptr(3,0),C.POINTER(C.c_uint8*65536)).contents
new=open(os.path.join(F,'ContinentalCircus_Enhanced.rom'),'rb').read()[0x2000:0x12000]
old=open(os.path.join(F,'..','releases','ContinentalCircus_Enhanced_v1.0.rom'),'rb').read()[0x2000:0x12000]
stub=bytes.fromhex('228000 ed538200 ed438400 d9 228600 ed538800 ed438a00 dd228c00 fd228e00 f5e1229000 08 f5e1229200 00')
STUB=0x40; END=STUB+len(stub)-1
bp=L.emu_bp_map(); bp[END]=1
def run(state, code):
    ram=C.cast(L.emu_ram_ptr(3,0),C.POINTER(C.c_uint8*65536)).contents
    C.memmove(ram, bytes(state), 65536)
    ram[0x9571:0x9702]=list(code[0x9571:0x9702])
    for i,b in enumerate(stub): ram[STUB+i]=b
    ram[0xFFFC]=STUB; ram[0xFFFD]=0
    L.emu_set_reg(8,0)
    for r,v in ((1,0xFFFC),(2,0x1234),(3,0x5678),(4,0x9ABC),(5,0xDEF0),(6,0x1111),(7,0x2222),(0,0x9571)): L.emu_set_reg(r,v)
    c0=L.emu_cycles(); ok=L.emu_run(3000000); c=L.emu_cycles()-c0
    m=bytes(ram)
    if not ok:
        L.emu_init(); L.emu_add_ram(3,0); L.emu_set_slots(0xFF,0,0,0,0); L.emu_bp_map()[END]=1
    return ok, c, m
data=open(sys.argv[1],'rb').read(); n=len(data)//65536
random.seed(int(sys.argv[2]) if len(sys.argv)>2 else 1); FUZZ=int(sys.argv[3]) if len(sys.argv)>3 else 0
tot=[0,0]; bad=0; regdiff={}; skipped=0; cases=0; segs=0
names=['hl','de','bc',"hl'","de'","bc'",'ix','iy','af',"af'"]
def one(st, tag):
    global bad, skipped, cases, segs
    ok1,c1,m1=run(st,old); ok2,c2,m2=run(st,new)
    if not ok1: skipped+=1; 
    if not ok1 and not ok2: return
    cases+=1; tot[0]+=c1; tot[1]+=c2
    # memoria: todo salvo el código cambiado, la zona de registros y la pila
    d=[a for a in range(0x100,0xFFF0) if m1[a]!=m2[a] and not (0x9571<=a<0x9694 or 0x96F2<=a<0x9702)]
    if d or ok1!=ok2:
        bad+=1
        if bad<6: print('DIFERENCIA',tag,'ok',ok1,ok2,'n',len(d),['%04X:%02X/%02X'%(a,m1[a],m2[a]) for a in d[:12]])
    for i,nm in enumerate(names):
        a=0x80+2*i
        if m1[a:a+2]!=m2[a:a+2]: regdiff[nm]=regdiff.get(nm,0)+1
for i in range(n):
    st=bytearray(data[i*65536:(i+1)*65536])
    if not FUZZ:
        k=0
        while st[0xD600+k]!=0xFF and k<255: k+=1
        segs+=k
        one(st,'img%d'%i)
    else:
        for j in range(FUZZ):
            s=bytearray(st); k=0; mode=random.randrange(3)
            while s[0xD600+k]!=0xFF and k<255:
                q=0xD800+4*k
                if random.random()<(0.08,0.3,0.6)[mode]:
                    w=random.randrange(6)
                    if w==0: s[q]=(s[q]&0x0B)|random.randrange(16)<<4|random.choice([0,4])
                    elif w==1: s[q+2]=(s[q+2]&0x0F)|random.randrange(16)<<4
                    elif w==2: d=random.randrange(-4,5); s[q+1]=(s[q+1]+d)&255; s[q+3]=(s[q+3]+d)&255
                    elif w==3: s[q+3]=(s[q+1]+random.randrange(0,8))&255
                    elif w==4: s[q+1]=random.choice([random.randrange(0x0A,0x14),256-random.randrange(1,40)])
                    else: s[0xD600+k]=random.choice([0,1,1,2,3])
                k+=1
            one(s,'img%d/f%d'%(i,j))
print('casos',cases,'saltados(original no termina)',skipped,'DIFERENTES',bad)
print('registros que difieren al volver:',regdiff)
print('ciclos por llamada: original %.0f  nuevo %.0f  (%.1f %%)'%(tot[0]/cases,tot[1]/cases,100.0*(tot[1]-tot[0])/tot[0]))
if segs: print('tramos por imagen: %.1f'%(segs/n))
L.emu_exec_map.restype=C.POINTER(C.c_uint8); em=L.emu_exec_map()
sys.path.insert(0,os.path.join(F,'herramientas','desensamblado'))
from z80dis import Dis
d=Dis(new,0); pc=0x9571; miss=[]
while pc<0x9694:
    r=d.dec(pc)
    if not em[pc]: miss.append('%04X %s'%(pc,r[0]))
    pc+=r[1]
print('instrucciones nuevas sin ejecutar:',miss)
