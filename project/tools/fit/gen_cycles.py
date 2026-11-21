"""Генерация таблиц цикла: python3 gen_cycles.py run fourier_31.json | walk fourier_41.json (из каталога с rigmodel/fitlib/fourier)"""
import sys; sys.path.insert(0,'.')
import numpy as np,json,fourier as F,fitlib as _f,rigmodel as _r
kind=sys.argv[1]; v=np.array(json.load(open(sys.argv[2])))
P=[F.pose(v,i) for i in range(36)]
X=np.array([p[0] for p in P]); u=np.arange(36)
def h1(y,amp_max):
    c=2*np.mean(y*np.cos(2*np.pi*u/36)); s=2*np.mean(y*np.sin(2*np.pi*u/36)); m=y.mean()
    amp=np.hypot(c,s); k=min(1.0,amp_max/max(amp,1e-6)); return m,c*k,s*k
cs=lambda k,c,s:c*np.cos(2*np.pi*k/36)+s*np.sin(2*np.pi*k/36)
if kind=='run':
    am,ac,as_=h1(X[:,5],0.85); fm,fc,fs=h1(X[:,6],0.3)
    ARM=lambda k:0.15+cs(k,ac,as_); FORE=lambda k:-1.5+0.5*cs(k,fc,fs)
    th_scale=0.88; lock=0.85; ARM_IN,LEG_IN,TW_H,TW_S=0.3,0.1,0.2,0.24; name,cls,title='run_cycle','RunCycle','бега'
else:
    am,ac,as_=h1(X[:,5],0.5); fm,fc,fs=h1(X[:,6],0.25)
    ARM=lambda k:0.05+2.0*cs(k,ac,as_); FORE=lambda k:-0.7+1.5*cs(k,fc,fs)
    th_scale=1.0; lock=1.0; ARM_IN,LEG_IN,TW_H,TW_S=0.12,0.05,0.17,0.2; name,cls,title='walk_cycle','WalkCycle','ходьбы'
thm={k:X[:,k].mean() for k in (9,12)}
for i in range(36):
    for k in (9,12): X[i,k]=thm[k]+th_scale*(X[i,k]-thm[k])
    X[i,5]=ARM(i); X[i,6]=FORE(i); X[i,7]=ARM((i+18)%36); X[i,8]=FORE((i+18)%36)
miny=np.array([_r.skin(_f.ang_dict(X[i]))[:,1].min() for i in range(36)])
bob=-miny*0.95*lock; kk=np.array([.25,.5,.25]); bob=kk[0]*np.roll(bob,1)+kk[1]*bob+kk[2]*np.roll(bob,-1); bob=np.clip(bob,-0.3,0.3)
txt=f"class_name {cls}\n## Цикл {title} Тревора: подгонка по референсу (36 кадров). Генерирует tools/fit/gen_cycles.py\nconst N := 36\nconst PHASE_OFF := 0.0\nconst ARM_IN := {ARM_IN}\nconst LEG_IN := {LEG_IN}\nconst TW_H := {TW_H}\nconst TW_S := {TW_S}\nconst BONES := [0, 1, 2, 3, 4, 5, 6, 8, 9, 11, 12, 13, 14, 15, 16]\nconst DATA: Array = [\n"
for i in range(36):
    txt+="\t"+", ".join("%.4f"%a for a in list(X[i])+[bob[i]])+(",\n" if i<35 else "]\n")
open(f'/home/claude/dacha3d/scripts/{name}.gd','w').write(txt)
print(kind,'bob',bob.min(),bob.max(),'arm',X[:,5].min(),X[:,5].max(),'fore',X[:,6].min(),X[:,6].max())
