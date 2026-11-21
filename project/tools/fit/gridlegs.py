import sys; sys.path.insert(0,'/home/claude/fit')
import numpy as np,json,fourier as F,fitlib as f,itertools
from multiprocessing import Pool
v=np.array(json.load(open('/home/claude/fit/fourier_12.json'))); S=float(np.exp(v[-1]))
ix=F.ix
TH=np.arange(-1.4,1.01,0.2); SH=np.arange(0.0,2.81,0.4); FT=[0.3,0.6,0.9]
def work(i):
    RC=f.ref_classes('/home/claude/fit/ref_%03d.png'%(i+1))
    x,tx,ty=F.pose(v,i)
    # P-leg and N-leg alternating
    best=f.loss(RC,x,tx,ty,S,1)
    for rnd in range(2):
        for side in ('P','N'):
            a,b,c=[ix[k+side] for k in ('th','sh','ft')]
            cand=None
            for th,sh,ft in itertools.product(TH,SH,FT):
                y=x.copy(); y[a]=th;y[b]=sh;y[c]=ft
                l=f.loss(RC,y,tx,ty,S,1)
                if cand is None or l<cand[0]: cand=(l,th,sh,ft)
            if cand[0]<best:
                best=cand[0]; x[a],x[b],x[c]=cand[1:]
    print(i,best,flush=True)
    return x.tolist(),best
if __name__=='__main__':
    with Pool(2) as p: res=p.map(work,range(36))
    json.dump(res,open('/home/claude/fit/grid.json','w'))
