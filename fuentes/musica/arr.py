"""Arreglo a 3 voces del PSG a partir de la transcripción de basic-pitch + percusión."""
import sys, pickle, numpy as np, librosa, warnings; warnings.filterwarnings('ignore')
HZ=60
def arrange(t, plot=False):
    out, notes = pickle.load(open(t+'.bp.pkl','rb'))
    y, sr = librosa.load(t+'.mp3', sr=22050, mono=True)
    dur=len(y)/sr; N=int(dur*HZ)+1
    notes=[(s,e,p,a) for s,e,p,a,*_ in notes if a>0.25]
    # voces: cada nota a una voz, por registro y prioridad
    lead=[None]*N; bass=[None]*N; mid=[None]*N
    la=np.zeros(N); ba=np.zeros(N); ma=np.zeros(N)
    on_l=np.zeros(N,bool); on_b=np.zeros(N,bool); on_m=np.zeros(N,bool)
    for s,e,p,a in sorted(notes,key=lambda n:(-n[2])):
        i0=int(s*HZ); i1=max(i0+3,int(e*HZ))
        for i in range(i0,min(i1,N)):
            if p<52:
                if bass[i] is None or p<bass[i] : bass[i]=p; ba[i]=a; on_b[i]=(i==i0) or on_b[i]
            elif lead[i] is None:
                lead[i]=p; la[i]=a; on_l[i]=(i==i0)
            elif mid[i] is None and lead[i]-p>=3:
                mid[i]=p; ma[i]=a; on_m[i]=(i==i0)
    # percusión: HPSS -> golpes; graves = bombo, agudos = caja/platillo
    yh,yp=librosa.effects.hpss(y)
    S=np.abs(librosa.stft(yp,n_fft=1024,hop_length=256))
    fq=librosa.fft_frequencies(sr=sr,n_fft=1024)
    lo=S[fq<200].sum(0); hi=S[fq>2000].sum(0)
    def onsets(env):
        o=librosa.onset.onset_detect(onset_envelope=librosa.onset.onset_strength(S=librosa.amplitude_to_db(env[None,:]),sr=sr,hop_length=256),sr=sr,hop_length=256,units='time',delta=0.2)
        return o
    kick=onsets(lo); snare=onsets(hi)
    drum=[0]*N
    for tt in snare:
        i=int(tt*HZ)
        if i<N: drum[i]=2
    for tt in kick:
        i=int(tt*HZ)
        if i<N and not drum[i]: drum[i]=1
    return dict(N=N,lead=lead,bass=bass,mid=mid,on_l=on_l,on_b=on_b,on_m=on_m,drum=drum,dur=dur)

CLK=1789772.5
def period(p): return max(1,min(4095,round(CLK/16/(440*2**((p-69)/12)))))

def regs(A):
    """Estados del PSG por cuadro: (perA,volA,perB,volB,perC,volC,noise,mixer)"""
    N=A['N']; st=[]; env={'l':0,'b':0,'m':0}; dcnt=0; dk=0
    for i in range(N):
        r={}
        for ch,key,on,v0,vmin in (('A','lead','on_l',13,9),('B','bass','on_b',13,10),('C','mid','on_m',10,6)):
            p=A[key][i]
            if p is None: r[ch]=(0,0); env[ch]=0; continue
            if A[on][i] or env[ch]==0: env[ch]=1
            else: env[ch]+=1
            v=max(vmin, v0-(env[ch]-1)//4)
            r[ch]=(period(p),v)
        noise=None
        d=A['drum'][i]
        if d: dk=d; dcnt=0
        if dk:
            dcnt+=1
            if dk==1 and dcnt<=4: noise=(28, [14,12,9,6][dcnt-1], max(1,period(36)+dcnt*40))
            elif dk==2 and dcnt<=3: noise=(4, [13,10,7][dcnt-1], None)
            else: dk=0
        st.append((r,noise))
    return st

def render(st, sr=44100, hz=HZ):
    vol=[0]+[10**((v-15)*1.5/10)*1.0 for v in range(1,16)]
    out=np.zeros(int(len(st)*sr/hz)+1); spf=sr/hz
    ph={'A':0.0,'B':0.0,'C':0.0}; lfsr=1; nph=0.0; nout=1
    pos=0
    for i,(r,noise) in enumerate(st):
        n=int((i+1)*spf)-int(i*spf)
        t=np.arange(n)
        acc=np.zeros(n)
        for ch in 'ABC':
            per,v=r[ch]
            if ch=='C' and noise: 
                np_,nv,tp=noise
                # ruido (con tono opcional para el bombo)
                f=CLK/16/np_; step=f/sr
                bits=[]
                for k in range(n):
                    nph+=step
                    while nph>=1:
                        nph-=1; b=((lfsr^(lfsr>>3))&1); lfsr=(lfsr>>1)|(b<<16); nout=lfsr&1
                    bits.append(nout)
                sig=np.array(bits,float)
                if tp:
                    f2=CLK/16/tp; ph2=ph['C']+np.arange(n)*f2/sr; sq=(np.floor(ph2*2)%2); ph['C']=ph2[-1]+f2/sr if n else ph['C']; sig=sig*sq
                acc+=vol[nv]*(sig-0.5)
                continue
            if not v: continue
            f=CLK/16/per
            p=ph[ch]+np.arange(n)*f/sr; ph[ch]=(p[-1]+f/sr)%1 if n else ph[ch]
            acc+=vol[v]*((np.floor(p*2)%2)-0.5)
        out[pos:pos+n]=acc; pos+=n
    return out[:pos]*0.5

if __name__=='__main__':
    import soundfile as sf
    for t in sys.argv[1:]:
        A=arrange(t); st=regs(A)
        w=render(st); sf.write(t+'_psg.wav', w, 44100)
        pickle.dump((A,st),open(t+'.arr.pkl','wb'))
        print(t, A['N'], 'golpes', sum(1 for d in A['drum'] if d))
