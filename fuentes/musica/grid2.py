import librosa,numpy as np,pickle,warnings;warnings.filterwarnings('ignore')
def onsets(t):
    out,notes=pickle.load(open(t+'.bp.pkl','rb'))
    return np.array([s for s,e,p,a,*_ in notes if a>0.25]),np.array([a for s,e,p,a,*_ in notes if a>0.25])
def best(t,lo=0.06,hi=0.16):
    ons,w=onsets(t)
    gs=np.arange(lo,hi,0.0002)
    sc=[abs((w*np.exp(2j*np.pi*ons/g)).sum())/w.sum() for g in gs]
    i=int(np.argmax(sc)); g=gs[i]
    z=(w*np.exp(2j*np.pi*ons/g)).sum(); t0=(np.angle(z)/(2*np.pi))%1*g
    return g,t0,sc[i],ons
if __name__=='__main__':
    for t in 'Brazil America France Monaco Germany Spain Mexico Japan'.split():
        g,t0,s,ons=best(t)
        ph=((ons-t0)/g)%1; err=np.minimum(ph,1-ph)*g
        print(t,'g=%.4f (%.2f ticks, %.1f bpm as 16th) t0=%.3f R=%.2f med err %.0fms (random %.0f)'%(g,g*60,60/(4*g),t0,s,1000*np.median(err),g*250))
