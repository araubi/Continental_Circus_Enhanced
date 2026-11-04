"""Codifica el arreglo en el formato del reproductor y lo simula igual que el Z80."""
import sys, pickle, numpy as np
from arr import render, CLK
NOTE0=24                                    # índice 0 = C1
VOX=(('lead',13,9),('bass',13,10),('mid',10,6))
TAB=[max(1,min(4095,round(CLK/16/(440*2**((n+NOTE0-69)/12))))) for n in range(96)]
KICK=[14,12,9,6]; SNARE=[13,10,7]; KPER=TAB[36-NOTE0]

def encode(A):
    N=A['N']; streams=[]
    for key,_,_ in VOX:
        notes=A[key]; on=A['on_'+key[0]] if key!='mid' else A['on_m']
        ev=[]; cur=None; dur=0
        for i in range(N):
            n=notes[i]
            n=None if n is None else min(95,max(0,n-NOTE0))
            new = (i==0) or n!=cur or (n is not None and on[i]) or dur==255
            if new:
                if i: ev.append(dur)
                b=0x7E if n is None else n
                if n is not None and (n!=cur or on[i] or i==0): b|=0x80
                ev.append(b); cur=n; dur=0
            dur+=1
        ev.append(dur); ev.append(0xFF)
        streams.append(bytes(ev))
    d=[]; last=-1
    hits=[(i,t) for i,t in enumerate(A['drum']) if t]
    for i,t in hits:
        gap=i-last
        while gap>255: d+= [255,0]; gap-=255
        d+=[gap,t]; last=i
    d+=[0]
    streams.append(bytes(d))
    hdr=b''; off=8
    for s in streams: hdr+=bytes([off&255,off>>8]); off+=len(s)
    return hdr+b''.join(streams)

def simulate(song):
    """Mismo algoritmo que MUSTICK en Z80. Devuelve estados por tick como regs()."""
    p=[song[2*k]|song[2*k+1]<<8 for k in range(4)]
    cnt=[1,1,1]; per=[0,0,0]; act=[0,0,0]; age=[0,0,0]
    dwait=song[p[3]]; dtype=song[p[3]+1] if dwait else 0; p[3]+=2; dk=0; dage=9
    st=[]
    while True:
        end=False; r={}
        for v in range(3):
            cnt[v]-=1
            if cnt[v]==0:
                b=song[p[v]]
                if b==0xFF: end=True; break
                cnt[v]=song[p[v]+1]; p[v]+=2
                if (b&0x7F)==0x7E: act[v]=0
                else: per[v]=TAB[b&0x7F]; act[v]=1
                if b&0x80: age[v]=0
            vol=max(VOX[v][2], VOX[v][1]-(age[v]>>2)) if act[v] else 0
            if act[v] and age[v]<255: age[v]+=1
            r['ABC'[v]]=(per[v],vol)
        if end: break
        if dwait:
            dwait-=1
            if dwait==0:
                if dtype: dk=dtype; dage=0
                dwait=song[p[3]]
                if dwait: dtype=song[p[3]+1]; p[3]+=2
        noise=None
        if dk==1 and dage<4: noise=(28,KICK[dage],KPER+dage*40); dage+=1
        elif dk==2 and dage<3: noise=(4,SNARE[dage],None); dage+=1
        st.append((r,noise))
    return st

if __name__=='__main__':
    import soundfile as sf
    for t in sys.argv[1:]:
        A,_=pickle.load(open(t+'.arr.pkl','rb'))
        s=encode(A); open(t+'.song','wb').write(s)
        st=simulate(s); w=render(st); sf.write(t+'_psg.wav',w,44100)
        print(t,'bytes',len(s),'ticks',len(st),'de',A['N'])
