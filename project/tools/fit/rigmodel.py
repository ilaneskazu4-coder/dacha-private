import numpy as np, cv2, struct
from PIL import Image
d=open('/home/claude/fit/mesh.bin','rb').read()
nv=struct.unpack('<I',d[:4])[0]; o=4
V=np.frombuffer(d,np.float32,nv*3,o).reshape(-1,3).copy(); o+=nv*12
UV=np.frombuffer(d,np.float32,nv*2,o).reshape(-1,2).copy(); o+=nv*8
BI=np.frombuffer(d,np.int32,nv*4,o).reshape(-1,4).copy(); o+=nv*16
BW=np.frombuffer(d,np.float32,nv*4,o).reshape(-1,4).copy(); o+=nv*16
ni=struct.unpack('<I',d[o:o+4])[0]; o+=4
IDX=np.frombuffer(d,np.int32,ni,o).reshape(-1,3).copy()
PAR=[-1,0,1,2,3,2,5,6,2,8,9,0,11,12,0,14,15]
OFF=np.array([[0,.95,0],[0,.13,0],[0,.17,0],[0,.27,0],[0,.12,0],[.19,.25,0],[.22,-.25,0],[.13,-.22,0],[-.19,.25,0],[-.22,-.25,0],[-.13,-.22,0],[.09,-.04,0],[0,-.37,0],[0,-.42,0],[-.09,-.04,0],[0,-.37,0],[0,-.42,0]])
def rx(a):
    c,s=np.cos(a),np.sin(a); return np.array([[1,0,0],[0,c,-s],[0,s,c]])
def rz(a):
    c,s=np.cos(a),np.sin(a); return np.array([[c,-s,0],[s,c,0],[0,0,1]])
GREST=np.zeros((17,3))
for i in range(17):
    GREST[i]=OFF[i]+(GREST[PAR[i]] if PAR[i]>=0 else 0)
# triangle classes from texture
tex=np.array(Image.open('/home/claude/dacha3d/assets/hero2/hero2_tex.png').convert('RGB'))
H,W=tex.shape[:2]
def classify_rgb(rgb):
    hsv=cv2.cvtColor(rgb.reshape(-1,1,3).astype(np.uint8),cv2.COLOR_RGB2HSV).reshape(-1,3).astype(float)
    h,s,v=hsv[:,0],hsv[:,1],hsv[:,2]
    r,g,b=rgb[:,0].astype(float),rgb[:,1].astype(float),rgb[:,2].astype(float)
    cls=np.full(len(rgb),2)           # 2 pants
    cls[(v>150)&(s<50)]=1             # shirt
    cls[(r>g+10)&(r>b+25)&(v>90)&(s>=50)]=3   # skin
    cls[v<70]=4                       # dark: hair/shoes
    return cls
tc=UV[IDX].mean(1)
px=np.clip((tc[:,0]*W).astype(int),0,W-1); py=np.clip((tc[:,1]*H).astype(int),0,H-1)
TCLS=classify_rgb(tex[py,px])
def pose_world(ang, extra=None):
    """ang: dict bone->x angle; arms get fixed Z. returns skin matrices (17,3,3) and translations"""
    R=[None]*17; T=np.zeros((17,3))
    for i in range(17):
        a=ang.get(i,0.0)
        q=rx(a)
        if i in (5,): q=q@rz(-0.43)
        if i in (8,): q=q@rz(0.43)
        if extra and i in extra: q=q@extra[i]
        if PAR[i]<0:
            R[i]=q; T[i]=OFF[i]
        else:
            R[i]=R[PAR[i]]@q; T[i]=T[PAR[i]]+R[PAR[i]]@OFF[i]
    M=np.stack([R[i] for i in range(17)])
    # skin: p' = R_i (p - grest_i) + T_i
    return M,T
def skin(ang,hipoff=(0,0),extra=None):
    M,T=pose_world(ang,extra)
    out=np.zeros_like(V)
    for k in range(4):
        b=BI[:,k]; w=BW[:,k:k+1]
        loc=V-GREST[b]
        out+=w*(np.einsum('nij,nj->ni',M[b],loc)+T[b])
    out[:,1]+=hipoff[1]; out[:,2]+=hipoff[0]
    return out


PAL=np.array([[0,0,0],[235,235,235],[90,110,150],[230,150,120],[40,40,40],[200,60,200]],np.uint8)
domb=BI[np.arange(len(BI)),BW.argmax(1)]
_td=np.array([np.bincount(domb[t],minlength=17).argmax() for t in IDX])
_leg=np.isin(_td,[0,11,12,14,15]); _arm=np.isin(_td,[5,6,7,8,9,10]); _hd=np.isin(_td,[3,4])
TCLS=TCLS.copy()
TCLS[np.isin(_td,[13,16])]=5
TCLS[(TCLS==4)&_leg]=2
TCLS[(TCLS==4)&~_hd&~np.isin(_td,[13,16])]=1
TCLS[(TCLS==3)&(_leg|np.isin(_td,[1,2]))]=1
SIDE=np.zeros(len(IDX),int)   # +1 P-side, -1 N-side, 0 centre (по большинству вершин)
_p=np.isin(domb,[5,6,7,11,12,13]).astype(int); _n=np.isin(domb,[8,9,10,14,15,16]).astype(int)
_sc=(_p-_n)[IDX].sum(1)
SIDE[_sc>=2]=1; SIDE[_sc<=-2]=-1
GROUPS={}
for sd in (-1,0,1):
    for c in range(1,6):
        GROUPS[(sd,c)]=np.where((SIDE==sd)&(TCLS==c))[0]
def render(ang,tx,ty,s,size=(288,180),near=1,hipoff=(0,0),extra=None):
    P=skin(ang,hipoff,extra)
    Wd,Ht=size
    sx=tx+s*P[:,2]; sy=ty-s*P[:,1]
    pts=np.round(np.stack([sx[IDX],sy[IDX]],-1)*16).astype(np.int32)
    img=np.zeros((Ht,Wd),np.uint8)
    for sd in (-near,0,near):
        for c in (2,1,4,3,5):
            g=GROUPS[(sd,c)]
            if len(g): cv2.fillPoly(img,pts[g],c,lineType=cv2.LINE_8,shift=4)
    return img
