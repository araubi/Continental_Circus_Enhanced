import sys,re
sys.path.insert(0,'../repo/tools')
import motor_musica as mm, numpy as np
HZ=20
def steps_from_inc(name):
    s=open('../../cc/rom/sfxhr.inc').read()
    blk=s.split(name+':')[1].split(':')[0]
    nums=[int(x.rstrip('h'),16) for x in re.findall(r'0?[0-9A-Fa-f]+h',blk)]
    out=[];cur=[];i=0
    while i<len(nums):
        x=nums[i]
        if x==0xFF: out.append(cur);cur=[];i+=1
        elif x==0xFE: out.append(cur);break
        else: cur.append((x,nums[i+1]));i+=2
    return out
def per(f): return round(111861/f)
def whoosh(tone=True):
    vb=[4,7,10,12,12,10,8,6,4,2,0]
    vc=[3,5,7,9,9,7,6,4,3,1,0] if tone else [4,8,11,12,11,9,7,5,3,1,0]
    fb=[225,222,218,212,195,170,158,152,150,150,150]
    npd=[5,5,6,7,8,10,12,13,14,15,15]
    out=[]
    for k in range(len(vb)):
        st=[]
        if k==0: st+=[(7,0x9C if tone else 0x9E)]
        if tone:
            p=per(fb[k]); st+=[(2,p&255),(3,p>>8),(9,vb[k])]
        st+=[(6,npd[k]),(10,vc[k])]
        out.append(st)
    out.append([(7,0xB8),(9,0),(10,0)])
    return out
def scene(eff):
    eng=[[(7,0xB8),(0,0x80),(1,1),(8,9)]]+[[] for _ in range(HZ-1)]
    return eng+eff+[[] for _ in range(HZ)]
def mp3(fr,path):
    import soundfile as sf, subprocess
    w=mm.sintetiza(fr,HZ).astype(np.float64); w=w/32768
    sf.write('/tmp/_x.wav',w,mm.MUESTREO); subprocess.run(['ffmpeg','-loglevel','error','-y','-i','/tmp/_x.wav','-b:a','96k',path])
cands={'actual_HR05':steps_from_inc('SFX05'),'A_paso_con_motor':whoosh(True),'B_soplido':whoosh(False)}
allf=[]
for k,e in cands.items():
    mp3(scene(e),k+'.mp3'); allf+=scene(e)
    print(k,len(e),'pasos')
mp3(allf,'adelantar_opciones.mp3')
