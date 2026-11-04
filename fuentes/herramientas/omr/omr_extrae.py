import re,base64,zlib,sys
x=open('cc.xml').read()
snaps=x.split('<item id="')
# localizar bloques de snapshot por currentTime de scheduler
starts=[m.start() for m in re.finditer(r'<scheduler>',x)]
ev=x.index('<events>')
bounds=starts+[ev]
def gz(s): return zlib.decompress(base64.b64decode(s))
for k in range(len(starts)):
    blk=x[bounds[k]:bounds[k+1]]
    t=int(re.search(r'<time>(\d+)</time>',blk).group(1))
    ram=gz(re.search(r'<ram encoding="gz-base64">([^<]*)</ram>',blk).group(1))
    vr=re.findall(r'<vram>\s*<data encoding="gz-base64">([^<]*)</data>',blk)
    vram=gz(vr[0])
    vdp=re.search(r'<registers>(.*?)</registers>',blk,re.S).group(1)
    vdp=list(map(int,re.findall(r'<item>(\d+)</item>',vdp)))
    regs=dict(re.findall(r'<(af|bc|de|hl|af2|bc2|de2|hl2|ix|iy|pc|sp|i|r|im)>(\d+)</\1>',blk.split('<z80 ')[1]))
    iff=re.search(r'<iff1>(\w+)</iff1>',blk.split('<z80 ')[1]).group(1)
    psg=re.search(r'<PSG|<AY8910.*',blk)
    open('ram%d.bin'%k,'wb').write(ram); open('vram%d.bin'%k,'wb').write(vram)
    print(k,t,t/3436363200,len(ram),len(vram),vdp[:8],regs.get('pc'),iff)
    open('st%d.txt'%k,'w').write(repr((t,vdp[:8],regs,iff)))
