"""Arreglo a 3 voces cuadrado a la rejilla de la recreativa.
Las músicas de Taito avanzan a ticks de 1/60.8 s (medido: 0.016435 s en las
grabaciones) y cada canción tiene su unidad (semicorchea) en ticks. Se ajusta
la fase con la fuerza de ataques y todas las notas y golpes se cuadran a esa
rejilla; en el MSX cada unidad dura exactamente U ticks de 1/60 s."""
import sys, pickle, numpy as np, librosa, warnings; warnings.filterwarnings('ignore')
from song import encode, simulate
from arr import render
G0=0.016435
U=dict(Brazil=7,America=5,France=11,Monaco=8,Germany=8,Spain=6,Mexico=5,Japan=5)
AMIN=0.3
def phase(y,sr,g):
    hop=32; fps=sr/hop
    oe=librosa.onset.onset_strength(y=y,sr=sr,hop_length=hop)
    n=int(len(oe)/fps/g); best=(0,0)
    for t0 in np.arange(0,g,1/fps):
        idx=np.round((t0+np.arange(n)*g)*fps).astype(int); idx=idx[idx<len(oe)]
        best=max(best,(oe[idx].mean(),t0))
    return best[1]
def arrange(t):
    u=U[t]; g=u*G0
    out,notes=pickle.load(open(t+'.bp.pkl','rb'))
    y,sr=librosa.load(t+'.mp3',sr=22050,mono=True)
    t0=phase(y,sr,g); t0-= g*np.floor(t0/g)
    dur=len(y)/sr; M=int(round((dur-t0)/g))+1          # unidades
    q=lambda x:int(round((x-t0)/g))
    ns=[]
    for s,e,p,a,*_ in notes:
        if a<AMIN: continue
        js=max(0,q(s)); je=max(js+1,q(e))
        ns.append((js,je,p,a))
    lead=[None]*M; bass=[None]*M; mid=[None]*M
    on={'l':[False]*M,'b':[False]*M,'m':[False]*M}
    own={'l':[None]*M,'b':[None]*M,'m':[None]*M}
    for k,(js,je,p,a) in enumerate(sorted(ns,key=lambda n:(-n[2],-n[3]))):
        for j in range(js,min(je,M)):
            if p<52:
                if bass[j] is None or p<bass[j]: bass[j]=p; own['b'][j]=k; on['b'][j]=(j==js)
            elif lead[j] is None: lead[j]=p; own['l'][j]=k; on['l'][j]=(j==js)
            elif mid[j] is None and lead[j]-p>=3: mid[j]=p; own['m'][j]=k; on['m'][j]=(j==js)
    # nota que pierde su ataque a mitad (otra le quitó el sitio): ataque nuevo
    for key,arr in (('l',lead),('b',bass),('m',mid)):
        for j in range(1,M):
            if arr[j] is not None and own[key][j]!=own[key][j-1]: on[key][j]=True
        if arr[0] is not None: on[key][0]=True
    # percusión: golpes cuadrados a la rejilla
    yh,yp=librosa.effects.hpss(y)
    S=np.abs(librosa.stft(yp,n_fft=1024,hop_length=256))
    fq=librosa.fft_frequencies(sr=sr,n_fft=1024)
    def onsets(env):
        return librosa.onset.onset_detect(onset_envelope=librosa.onset.onset_strength(S=librosa.amplitude_to_db(env[None,:]),sr=sr,hop_length=256),sr=sr,hop_length=256,units='time',delta=0.25)
    kick=onsets(S[fq<200].sum(0)); snare=onsets(S[fq>2000].sum(0))
    dr=[0]*M
    for tt in snare:
        j=q(tt)
        if 0<=j<M: dr[j]=2
    for tt in kick:
        j=q(tt)
        if 0<=j<M and not dr[j]: dr[j]=1
    # a ticks del MSX
    N=M*u
    ex=lambda a:[a[i//u] for i in range(N)]
    exo=lambda a:[a[i//u] and i%u==0 for i in range(N)]
    drum=[dr[i//u] if i%u==0 else 0 for i in range(N)]
    return dict(N=N,lead=ex(lead),bass=ex(bass),mid=ex(mid),on_l=exo(on['l']),on_b=exo(on['b']),on_m=exo(on['m']),drum=drum,dur=N/60,u=u,t0=t0)
if __name__=='__main__':
    import soundfile as sf
    tot=0
    for t in (sys.argv[1:] or list(U)):
        A=arrange(t); s=encode(A); tot+=len(s)
        open(t+'.song','wb').write(s)
        st=simulate(s); sf.write(t+'_psg.wav',render(st),44100)
        pickle.dump((A,None),open(t+'.arr2.pkl','wb'))
        print(t,'u',A['u'],'t0 %.3f'%A['t0'],'bytes',len(s),'ticks',len(st),'%.2f s'%(len(st)/60),'golpes',sum(1 for d in A['drum'] if d))
    print('total',tot)
