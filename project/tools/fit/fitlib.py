import numpy as np, cv2, json, sys
import rigmodel as r
BONES=[0,1,2,3,4,5,6,8,9,11,12,13,14,15,16]
LO=np.array([-0.5,-0.3,-0.3,-0.5,-0.7, -3.0,-3.0, -3.0,-3.0, -2.2,0.0,-1.0, -2.2,0.0,-1.0])
HI=np.array([ 1.0, 1.0, 1.0, 0.6, 0.7,  2.5, 0.2,  2.5, 0.2,  1.2,2.8, 1.0,  1.2,2.8, 1.0])
# arms: fore bones (6,9) flex negative
def ref_classes(path):
    im=cv2.imread(path)
    b,g,rr=[im[...,i].astype(int) for i in range(3)]
    green=(g>rr+25)&(g>b+60)
    green=cv2.morphologyEx(green.astype(np.uint8),cv2.MORPH_OPEN,np.ones((3,3),np.uint8)).astype(bool)
    rgb=im[...,::-1].reshape(-1,3)
    cls=r.classify_rgb(rgb).reshape(im.shape[:2])
    cls[green]=0
    cls=cv2.resize(cls.astype(np.uint8),(288,180),interpolation=cv2.INTER_NEAREST)
    return cls
def ang_dict(x): return {b:x[i] for i,b in enumerate(BONES)}
def iou(a,b):
    u=(a|b).sum()
    return 1.0 if u==0 else (a&b).sum()/u
_cache={}
def dt_of(mask):
    return cv2.distanceTransform((~mask).astype(np.uint8),cv2.DIST_L2,3)
def cham(refm,dref,modm):
    if modm.sum()==0 or refm.sum()==0: return 30.0
    dm=dt_of(modm)
    return dref[modm].mean()+dm[refm].mean()
def loss(RC,x,tx,ty,s,near,prev=None):
    key=id(RC)
    if key not in _cache or _cache[key][0] is not RC:
        _ys,_xs=np.where(RC>0)
        _rows=np.arange(RC.shape[0])[:,None]
        _sh=(RC==4)&(_rows>_ys.min()+0.6*(_ys.max()-_ys.min()))
        _cache[key]=(RC,dt_of(RC>0),dt_of(RC==3),(_xs.min(),_xs.max(),_ys.min(),_ys.max()),_sh,dt_of(_sh))
    _,dsil,dskin,_e,_sh,_dsh=_cache[key]
    MC=r.render(ang_dict(x),tx,ty,s,(288,180),near)
    ms=MC>0
    L=0.15*cham(RC>0,dsil,ms)+0.08*cham(RC==3,dskin,MC==3)+(1-iou(RC>0,ms))+0.6*(1-iou(RC==3,MC==3))
    mf=MC==5
    if mf.sum()>0 and _sh.sum()>0:
        L+=0.2*(_dsh[mf].mean()+dt_of(mf)[_sh].mean())*0.15
    elif _sh.sum()>0:
        L+=1.0
    ys,xs=np.where(ms)
    if len(xs):
        ex=_cache[key][3]; me=(xs.min(),xs.max(),ys.min(),ys.max())
        L+=0.012*(abs(me[0]-ex[0])+abs(me[1]-ex[1])+abs(me[2]-ex[2])+1.5*abs(me[3]-ex[3]))
    if prev is not None: L+=0.01*np.sum((x-prev)**2)
    return L
def optimize(RC,x0,t0,s,near,iters=2500,free_s=False,prev=None,seed=0,s0=0.2):
    rng=np.random.default_rng(seed)
    x=np.clip(x0.copy(),LO,HI); tx,ty=t0
    cur=loss(RC,x,tx,ty,s,near,prev)
    for it in range(iters):
        f=it/iters
        sig=s0*(1-f)+0.012
        k=rng.integers(1,5)
        idx=rng.choice(len(x),k,replace=False)
        nx=x.copy(); nx[idx]+=rng.normal(0,sig,k)
        nx=np.clip(nx,LO,HI)
        ntx=tx+rng.normal(0,2.5*(1-f)+0.3) if rng.random()<0.3 else tx
        nty=ty+rng.normal(0,2.5*(1-f)+0.3) if rng.random()<0.3 else ty
        ns=s
        if free_s and rng.random()<0.15: ns=s*(1+rng.normal(0,0.02))
        l=loss(RC,nx,ntx,nty,ns,near,prev)
        if l<cur: cur,x,tx,ty,s=l,nx,ntx,nty,ns
    return x,tx,ty,s,cur
