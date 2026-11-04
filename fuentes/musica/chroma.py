import librosa,numpy as np,warnings;warnings.filterwarnings('ignore')
_c={}
def chroma(f,sc=1.0):
    y,sr=librosa.load(f,sr=22050)
    if sc!=1.0: y=librosa.effects.time_stretch(y,rate=1/sc) if False else y
    C=librosa.feature.chroma_cqt(y=y,sr=sr,hop_length=512)
    return C,sr/512
def sim(orig,ren,scale):
    if orig not in _c: _c[orig]=chroma(orig)
    Co,fo=_c[orig]; Cr,fr=chroma(ren)
    # tiempo del render * scale = tiempo original
    n=min(Co.shape[1], int(Cr.shape[1]*scale))
    idx=np.minimum((np.arange(n)/scale).astype(int),Cr.shape[1]-1)
    a=Co[:,:n]; b=Cr[:,idx]
    num=(a*b).sum(0); den=np.linalg.norm(a,axis=0)*np.linalg.norm(b,axis=0)+1e-9
    e=np.linalg.norm(a,axis=0); m=e>np.percentile(e,20)
    return (num/den)[m].mean()
