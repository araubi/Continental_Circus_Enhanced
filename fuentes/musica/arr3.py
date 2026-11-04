"""Arreglo a 3 voces cuadrado a la rejilla de la recreativa (ver arr2.py) con
voz principal por intensidad y percusión como patrón regular de compás."""
import sys, pickle, numpy as np, librosa, warnings; warnings.filterwarnings('ignore')
from song import encode, simulate
from arr import render
from arr2 import G0, U, phase
BEAT=dict(France=2)                       # unidades por pulso (4 en las demás)
def arrange(t, AMIN=0.2, pat=True, lead_by='amp'):
    u=U[t]; g=u*G0; bu=BEAT.get(t,4); BAR=4*bu
    out,notes=pickle.load(open(t+'.bp.pkl','rb'))
    y,sr=librosa.load(t+'.mp3',sr=22050,mono=True)
    t0=phase(y,sr,g); t0-=g*np.floor(t0/g)
    dur=len(y)/sr; M=int(round((dur-t0)/g))+1
    q=lambda x:int(round((x-t0)/g))
    ns=[]
    for s,e,p,a,*_ in notes:
        if a<AMIN: continue
        js=max(0,q(s)); je=max(js+1,q(e))
        ns.append([js,je,p,a])
    # quitar notas iguales solapadas (basic-pitch parte a veces una nota)
    V={'l':[None]*M,'b':[None]*M,'m':[None]*M}; own={k:[None]*M for k in V}; amp={k:[0]*M for k in V}
    for k,(js,je,p,a) in enumerate(ns):
        for j in range(js,min(je,M)):
            if p<52:
                if V['b'][j] is None or p<V['b'][j]: V['b'][j]=p; own['b'][j]=k
    # principal: la más intensa (o la más aguda); media: la siguiente, 3+ semitonos por debajo
    for j in range(M):
        c=[(a,p,k) for k,(js,je,p,a) in enumerate(ns) if js<=j<je and p>=52]
        if not c: continue
        if lead_by=='amp': c.sort(key=lambda x:(-x[0],-x[1]))
        else: c.sort(key=lambda x:(-x[1],-x[0]))
        # continuidad: si la nota anterior de la principal sigue sonando, se queda
        prev=own['l'][j-1] if j else None
        if prev is not None and any(k==prev for _,_,k in c):
            c.sort(key=lambda x:x[2]!=prev)
        a,p,k=c[0]; V['l'][j]=p; own['l'][j]=k
        for a2,p2,k2 in c[1:]:
            if p-p2>=3: V['m'][j]=p2; own['m'][j]=k2; break
    on={}
    for key in V:
        on[key]=[V[key][j] is not None and (j==0 or own[key][j]!=own[key][j-1]) for j in range(M)]
    # percusión
    yh,yp=librosa.effects.hpss(y)
    hop=128; S=np.abs(librosa.stft(yp,n_fft=1024,hop_length=hop)); fps=sr/hop
    fq=librosa.fft_frequencies(sr=sr,n_fft=1024)
    def strength(env):
        oe=librosa.onset.onset_strength(S=librosa.amplitude_to_db(env[None,:]),sr=sr,hop_length=hop)
        r=np.zeros(M)
        for j in range(M):
            c=(t0+j*g)*fps; a=int(c-0.3*g*fps); b=int(c+0.3*g*fps)+1
            if a<len(oe): r[j]=oe[max(0,a):b].max()
        return r/ (r.max() or 1)
    ks=strength(S[fq<200].sum(0)); ss=strength(S[fq>2000].sum(0))
    dr=[0]*M
    if pat:
        nb=M//BAR
        act=[j for j in range(M) if V['l'][j] or V['b'][j]]
        last=max(act) if act else M
        bars=[b for b in range(nb) if (b+1)*BAR<=last+1]
        kp=np.array([ks[b*BAR:(b+1)*BAR] for b in bars]).mean(0)
        sp=np.array([ss[b*BAR:(b+1)*BAR] for b in bars]).mean(0)
        # compás de rock: bombo en 1 y 3, caja en 2 y 4, y los bombos extra
        # que la grabación marca con fuerza
        Sn={bu,3*bu}; K={0,2*bu}|{x for x in range(0,BAR,max(1,bu//2)) if kp[x]>=0.85*kp.max()}-Sn
        for b in bars:
            for x in range(BAR):
                j=b*BAR+x
                if x in Sn: dr[j]=2
                elif x in K: dr[j]=1
        # golpe final: el primer tiempo tras el último compás
        j=(bars[-1]+1)*BAR if bars else 0
        if j<M and j<=last: dr[j]=1
        pstr=''.join('S' if x in Sn else 'K' if x in K else '.' for x in range(BAR))
    else:
        for j in range(M):
            if ss[j]>0.35: dr[j]=2
            elif ks[j]>0.35: dr[j]=1
        pstr='-'
    N=M*u
    ex=lambda a:[a[i//u] for i in range(N)]
    exo=lambda a:[a[i//u] and i%u==0 for i in range(N)]
    drum=[dr[i//u] if i%u==0 else 0 for i in range(N)]
    return dict(N=N,lead=ex(V['l']),bass=ex(V['b']),mid=ex(V['m']),on_l=exo(on['l']),on_b=exo(on['b']),on_m=exo(on['m']),drum=drum,dur=N/60,u=u,t0=t0,pat=pstr)

if __name__=='__main__':
    import soundfile as sf
    tot=0
    for t in (sys.argv[1:] or list(U)):
        A=arrange(t); s=encode(A); tot+=len(s)
        open(t+'.song','wb').write(s)
        st=simulate(s); sf.write(t+'_psg.wav',render(st),44100)
        pickle.dump((A,None),open(t+'.arr3.pkl','wb'))
        print(t,'u',A['u'],A['pat'],'bytes',len(s),'%.2f s'%(len(st)/60))
    print('total',tot)
