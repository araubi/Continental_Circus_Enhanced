import librosa,numpy as np,warnings;warnings.filterwarnings('ignore')
BASE=0.01645
U=dict(Brazil=7,America=5,France=4,Monaco=8,Germany=8,Spain=6,Mexico=5,Japan=5)
def fit(t,u=None):
    u=u or U[t]
    y,sr=librosa.load(t+'.mp3',sr=22050); hop=32; fps=sr/hop
    oe=librosa.onset.onset_strength(y=y,sr=sr,hop_length=hop)
    best=(-1,)
    for g in np.linspace(0.97,1.03,121)*u*BASE:
        n=int(len(oe)/fps/g)
        for t0 in np.arange(0,g,1/fps):
            idx=np.round((t0+np.arange(n)*g)*fps).astype(int); idx=idx[idx<len(oe)]
            s=oe[idx].mean()
            if s>best[0]: best=(s,g,t0)
    s,g,t0=best
    return g,t0,s/oe.mean()
if __name__=='__main__':
    import sys
    for t in (sys.argv[1:] or U):
        for u in (U[t],):
            g,t0,r=fit(t,u); print(t,u,'g=%.5f tick=%.5f t0=%.3f ratio %.2f'%(g,g/u,t0,r))
