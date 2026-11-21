import sys; sys.path.insert(0,'/home/claude/fit')
import fitlib as f, numpy as np, json, rigmodel as r
N=36
names='hips spine chest neck head armP foreP armN foreN thP shP ftP thN shN ftN'.split()
ix={n:i for i,n in enumerate(names)}
# независимые каналы: P-конечности + торс; N = P со сдвигом на полцикла
CH=['hips','spine','chest','neck','head','armP','foreP','thP','shP','ftP']
KH={'hips':2,'spine':2,'chest':2,'neck':2,'head':2,'armP':3,'foreP':3,'thP':4,'shP':4,'ftP':4}
def nco(k): return 1+2*k
OFFS={};o=0
for c in CH: OFFS[c]=o;o+=nco(KH[c])
OFFS['tx']=o;o+=nco(2);OFFS['ty']=o;o+=nco(2);NP=o+1
def series(c,v,u,K):
    o=OFFS[c]; y=np.full_like(u,v[o])
    for k in range(1,K+1):
        y=y+v[o+2*k-1]*np.cos(2*np.pi*k*u/N)+v[o+2*k]*np.sin(2*np.pi*k*u/N)
    return y
def pose(v,i):
    u=np.array([float(i)])
    def g(c,sh=0): return series(c,v,u+sh,KH[c])[0]
    x=np.zeros(15)
    for c in ['hips','spine','chest','neck','head']: x[ix[c]]=g(c)
    x[ix['armP']]=g('armP'); x[ix['foreP']]=g('foreP'); x[ix['armN']]=g('armP',18); x[ix['foreN']]=g('foreP',18)
    x[ix['thP']]=g('thP'); x[ix['shP']]=g('shP'); x[ix['ftP']]=g('ftP')
    x[ix['thN']]=g('thP',18); x[ix['shN']]=g('shP',18); x[ix['ftN']]=g('ftP',18)
    tx=series('tx',v,u,2)[0]; ty=series('ty',v,u,2)[0]
    return np.clip(x,f.LO,f.HI),tx,ty
def lsq_init(X,T):
    v=np.zeros(NP); v[-1]=np.log(78.0); u=np.arange(N,dtype=float)
    def fitc(name,y,K):
        A=[np.ones(N)]
        for k in range(1,K+1): A+= [np.cos(2*np.pi*k*u/N),np.sin(2*np.pi*k*u/N)]
        co=np.linalg.lstsq(np.stack(A,1),y,rcond=None)[0]
        v[OFFS[name]:OFFS[name]+len(co)]=co
    for c in ['hips','spine','chest','neck','head','armP','foreP','thP','shP','ftP']:
        y=X[:,ix[c]]
        if c in ('armP','foreP','thP','shP','ftP'):
            # усредняем P и сдвинутый N, чтобы использовать оба измерения
            n={'armP':'armN','foreP':'foreN','thP':'thN','shP':'shN','ftP':'ftN'}[c]
            y=(X[:,ix[c]]+np.roll(X[:,ix[n]],18))/2
        fitc(c,y,KH[c])
    fitc('tx',T[:,0],2); fitc('ty',T[:,1],2)
    return v
if __name__=='__main__':
    X=np.load('Xp.npy');T=np.load('Tp.npy'); S=json.load(open('f0.json'))['s']
    v=lsq_init(X,T)
    if len(sys.argv)>3:
        v0=np.array(json.load(open(sys.argv[3])))
        v=np.concatenate([v0,[np.log(78.0)]]) if len(v0)<NP else v0
    frames=list(range(0,36,2))
    RCs={i:f.ref_classes('ref_%03d.png'%(i+1)) for i in range(36)}
    def total(v,fr):
        L=0
        for i in fr:
            x,tx,ty=pose(v,i); L+=f.loss(RCs[i],x,tx,ty,float(np.exp(v[-1])),1)
        return L/len(fr)
    print('init loss all',total(v,list(range(36))),flush=True)
    seed=int(sys.argv[1]); rng=np.random.default_rng(seed)
    cur=total(v,frames); iters=int(sys.argv[2])
    for it in range(iters):
        fr=it/iters; sig=float(sys.argv[4] if len(sys.argv)>4 else 0.06)*(1-fr)+0.006
        k=rng.integers(1,4); idx=rng.choice(NP,k,replace=False)
        nv=v.copy(); nv[idx]+=rng.normal(0,sig,k)*np.where(idx==NP-1,0.3,1)*np.where(np.isin(idx,[OFFS['tx'],OFFS['ty']]+[OFFS['tx']+j for j in range(5)]+[OFFS['ty']+j for j in range(5)]),20,1)
        l=total(nv,frames)
        if l<cur: cur,v=l,nv
        if it%100==0: print(it,cur,flush=True)
    print('final all',total(v,list(range(36))))
    json.dump(v.tolist(),open('fourier_%d.json'%seed,'w'))
