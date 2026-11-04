import librosa,numpy as np,pickle,warnings;warnings.filterwarnings('ignore')
def grid(t):
    y,sr=librosa.load(t+'.mp3',sr=22050)
    tempo,beats=librosa.beat.beat_track(y=y,sr=sr,units='time')
    T=np.median(np.diff(beats)); k=np.round((beats-beats[0])/T)
    T,t0=np.polyfit(k,beats,1)
    return T,t0,len(y)/sr
if __name__=='__main__':
    for t in 'Brazil America France Monaco Germany Spain Mexico Japan'.split():
        T,t0,dur=grid(t)
        out,notes=pickle.load(open(t+'.bp.pkl','rb'))
        ons=np.array([s for s,e,p,a,*_ in notes if a>0.25])
        r=[]
        for div in (2,4,3,6,8):
            g=T/div; ph=((ons-t0)/g)%1; err=np.minimum(ph,1-ph)*g
            r.append('%d:%.0fms'%(div,1000*np.median(err)))
        print(t,'T=%.4f t0=%.3f'%(T,t0),' '.join(r), '16th ticks %.2f'%(T/4*60))
