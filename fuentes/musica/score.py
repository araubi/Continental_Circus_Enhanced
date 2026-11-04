import sys, numpy as np, librosa, warnings; warnings.filterwarnings('ignore')
def chroma(f, sr=22050):
    y,_=librosa.load(f,sr=sr); yh,_=librosa.effects.hpss(y)
    return librosa.feature.chroma_cqt(y=yh,sr=sr,hop_length=512)
for t in sys.argv[1:]:
    a=chroma(t+'.mp3'); b=chroma(t+'_psg.wav'); n=min(a.shape[1],b.shape[1]); a=a[:,:n]; b=b[:,:n]
    cs=(a*b).sum(0)/(np.linalg.norm(a,axis=0)*np.linalg.norm(b,axis=0)+1e-9)
    # referencia: desplazando 1 s (no alineado)
    sh=(a[:,43:]*b[:,:-43]).sum(0)/(np.linalg.norm(a[:,43:],axis=0)*np.linalg.norm(b[:,:-43],axis=0)+1e-9)
    print(t, 'similitud croma %.2f (desalineado %.2f)'%(cs.mean(), sh.mean()))
