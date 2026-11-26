"""Estudo de forma no Blender. Executar com o projeto 1500 como raiz."""
import bpy, math, random
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from pathlib import Path
from math import sin, cos, pi, exp
root=Path(r'C:\Users\PC\Documents\ChatGPT\1500')
with bpy.data.libraries.load(str(root/'art/blender/moradores_1500_v3.blend')) as (src,dst):
    dst.scenes=[src.scenes[0]]
scene=dst.scenes[0]
scene.name='1500 • Estudo de personagens'
bpy.context.window.scene=scene
def mat(name,h,rough=.78):
    m=bpy.data.materials.new(name)
    m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    rgb=[int(h[k:k+2],16)/255 for k in (0,2,4)]
    c=tuple(((x+.055)/1.055)**2.4 if x>.04045 else x/12.92 for x in rgb)+(1,)
    bs.inputs['Base Color'].default_value=c
    bs.inputs['Roughness'].default_value=rough
    m.diffuse_color=c
    return m
hair=[mat('Cabelo • '+str(i),h,.56) for i,h in enumerate(['262221','302924','352d26','292524','3b3028'])]
rust=[mat('Barro • '+str(i),h) for i,h in enumerate(['a44928','ae512b','b35730','9e4226'])]
leaf=[mat('Folha • '+str(i),h) for i,h in enumerate(['697031','727738','626b30'])]
cord=mat('Fibra crua','c49b57')
def make(name,verts,faces,materials,indices=None):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    o=bpy.data.objects.new(name,mesh)
    scene.collection.objects.link(o)
    for m in materials: mesh.materials.append(m)
    if indices:
        for f,k in zip(mesh.polygons,indices): f.material_index=k
    o.parent=group
    return o
def grid(name,rows,mats,shade=None,wrap=False):
    n=len(rows[0]);fs=[];idx=[]
    for j in range(len(rows)-1):
        for i in range(n if wrap else n-1):
            k=(i+1)%n
            fs.append((j*n+i,j*n+k,(j+1)*n+k,(j+1)*n+i))
            idx.append(shade(i,j) if shade else 0)
    return make(name,[v for row in rows for v in row],fs,mats,idx)
def tube(name,pts,radii,mats,n=7):
    rows=[]
    for k,p in enumerate(map(Vector,pts)):
        t=(Vector(pts[min(k+1,len(pts)-1)])-Vector(pts[max(0,k-1)])).normalized()
        u=t.cross(Vector((0,1,0)))
        if u.length<.01: u=t.cross(Vector((1,0,0)))
        u.normalize();w=t.cross(u)
        rows.append([p+radii[k]*(u*cos(i*2*pi/n)+w*sin(i*2*pi/n)) for i in range(n)])
    return grid(name,rows,mats,wrap=True)
for rig in sorted([o for o in scene.objects if o.type=='ARMATURE'],key=lambda o:o.name):
    f='Moradora' in rig.name
    group=bpy.data.objects.new('Moradora' if f else 'Morador',None)
    scene.collection.objects.link(group)
    group.location.x=.39 if f else -.39
    h=1.74 if f else 1.83
    ez=1.579 if f else 1.663
    ex=.051 if f else .041
    skin=mat('Pele • castanha' if f else 'Pele • dourada','a65e33' if f else 'aa6031')
    for obj in list(rig.children):
        if 'CabeloRostoRoupa' in obj.name:
            bpy.data.objects.remove(obj,do_unlink=True)
            continue
        obj.parent=group
        obj.modifiers.clear()
        body='Anatomia' in obj.name
        if body:
            obj.data.materials.clear();obj.data.materials.append(skin)
        for v in obj.data.vertices:
            x,y,z=v.co
            # Reduz a abertura das pálpebras e acompanha globos e íris.
            w=exp(-((abs(x)-ex)/.045)**4-((z-ez)/.055)**4)*max(0,min(1,(-y-.041)/.035))
            v.co.z-=.30*(z-ez)*w
            if body and z<1.48:
                v.co.x*=1+(.05 if f else .14)*exp(-((z-1.30)/.19)**2)*max(0,1-abs(x)/.44)
                v.co.y*=1+(.02 if f else .16)*exp(-((z-1.28)/.15)**2)
            # Relaxa a abertura dos braços na pose de apreciação.
            if abs(x)>.25 and z<1.42 and z>.65:
                v.co.x-=math.copysign(.074*min(1,(abs(x)-.25)/.07)*min(1,(1.42-z)/.47),x)
        if body: corpo=obj
    bpy.data.objects.remove(rig,do_unlink=True)
    ps=[v.co.copy() for v in corpo.data.vertices]
    bvh=BVHTree.FromPolygons(ps,[list(poly.vertices) for poly in corpo.data.polygons])
    def xy(a,r):return Vector((sin(a)*r,-cos(a)*r,0))
    def surface(a,z,yc,default):
        o=Vector((0,yc,z));di=xy(a,1)
        hit=bvh.ray_cast(o,di,.36)[0]
        return (hit-o).length if hit is not None else default
    # Tecido de cintura: volume com folga, sobreposição longa e borda irregular.
    waist=.999 if f else 1.012
    yc=-.019
    def shape(a,t,offset=0):
        z=waist-t*(.244+.018*cos(3*a))
        rw=surface(a,waist,yc,.133)+.004
        hip=max(surface(a,waist-.12,yc,.15)+.015, rw+.009)
        r=rw+(hip-rw)*sin(min(1,t*1.7)*pi/2)+t*.015
        r+=offset+.003*t*sin(7*a+.5)+.020*max(0,-cos(a))*sin(min(t,1)*pi/2)
        v=xy(a,r);return (v.x,yc+v.y,z)
    def cloth(name,a0,a1,n,mats,extra,lengths):
        rows=[]
        for t in [0,.17,.47,.74,1]:
            row=[]
            for i in range(n+1):
                u=i/n;a=a0+(a1-a0)*u
                L=lengths(u)
                form=shape(a,t*L,extra+.004*sin(5*pi*u)*t)
                row.append(form)
            rows.append(row)
        return grid(name,rows,mats,lambda i,j: [0,0,1,0,0,2,0,0,0,1,0,0,0][i%13])
    cloth('Envoltório',-pi,pi,48,rust,0,lambda u:.90+.065*cos(u*2*pi*3))
    cloth('Painel oliva',-1.92,.15,17,leaf,.007,lambda u:1.01+.12*cos(u*pi)-.17*u)
    cloth('Transpasse terracota',-.36,1.68,22,rust,.013,lambda u:1.55-.77*u+.045*cos(3*pi*u))
    rows=[]
    for vfrac in [0,.30,.78,1]:
        row=[]
        for i in range(47):
            u=i/46
            a=-1.57+3.35*u
            t=.018+.52*u+.16*vfrac+.03*sin(pi*u)
            x,y,z=shape(a,t,.019+.002*sin(pi*vfrac))
            row.append((x,y,z))
        rows.append(row)
    grid('Dobra diagonal do transpasse',rows,rust,lambda i,j:1 if j==0 else 0)
    for j in range(2):
        pts=[]
        for i in range(129):
            a=i*2*pi/128
            x,y,z=shape(a,.025,.014+.0016*cos(28*a+j*pi))
            pts.append((x,y,z+.006*sin(a-.4)+.007*j+.0017*sin(a*28+j*pi)))
        tube('Cinto trançado',pts,[.0055]*len(pts),[cord])
    x,y,z=shape(.13,0,.021)
    tube('Nó',[(x-.015,y,z),(x-.007,y-.008,z+.006),(x+.004,y-.01,z-.004),(x+.014,y,z+.003)],[.005,.008,.007,.004],[cord])
    for s in [-1,1]:
        pts=[]
        for i in range(9):
            t=i/8
            a=.13+s*(.03+.10*t)
            px,py,pz=shape(a,t*(.61 if s==1 else .46),.023)
            pts.append((px,py-.003,pz))
        tube('Ponta da amarração',pts,[.005-.002*i/8 for i in range(9)],[cord])
    if f:
        rows=[]
        # Envoltória convexa horizontal: liga os volumes do busto com tecido tensionado.
        from mathutils.geometry import convex_hull_2d
        for t in [0,.10,.36,.68,.90,1]:
            row=[]
            for i in range(64):
                a=i*2*pi/64; z=1.173+.133*t+.009*cos(a+.12)-.017*sin(a)**2
                ring=[]
                for k in range(48):
                    b=k*2*pi/48
                    r=surface(b,z,-.030,.139)
                    lateral=.133+.023*t
                    if abs(sin(b))>.01:r=min(r,lateral/abs(sin(b)))
                    ring.append(Vector((sin(b)*r,-cos(b)*r)))
                hull=[ring[k] for k in convex_hull_2d(ring)]
                d=Vector((sin(a),-cos(a)))
                radius=.13
                for e,p in enumerate(hull):
                    edge=hull[(e+1)%len(hull)]-p
                    cross=d.cross(edge)
                    if abs(cross)<1e-7: continue
                    tedge=p.cross(d)/cross
                    dist=p.cross(edge)/cross
                    if -.001<=tedge<=1.001 and dist>0:
                        radius=dist; break
                P=xy(a,radius+.008+.0025*sin(pi*t))
                row.append((P.x,P.y-.030,z))
            rows.append(row)
        grid('Faixa tecida',rows,leaf,lambda i,j:1 if j==4 else 0,True)
    # Casco contínuo de cabelo com risca deslocada e pontas em volta da nuca.
    hy=-.026
    def cap(a,t):
        front=cos(a)
        ztop=h+.012
        u=(1-front)/2
        edge=ez+.081-.236*min(1,u*2.05)**1.22
        if f: edge-=.30*min(1,max(0,(u-.09)/.74))**1.2
        edge+=.010*cos(5*a+.6)
        shoulder=max(0,(ez-.09-edge)/.40)
        endr=.145+.012*u+.007*f
        bend=.30+.31*u
        turn=a+sin(a-.2)*.40*sin(pi*t)**1.1
        z=ztop-(ztop-edge)*(1-cos(t*pi*.5))
        q=(z-(h-.124))/.137
        r=endr*math.sqrt(max(.001,1-max(0,min(1,q))**2))
        x=r*sin(turn)+.018*(1-t)**3
        y=hy-1.10*r*cos(turn)+.048*shoulder*t**4
        if z>ez-.05:
            a2=math.atan2(x,-(y-hy))
            rr=surface(a2,z,hy,0)+.012
            rcur=math.hypot(x,y-hy)
            if rcur>.002 and rr>rcur:
                x*=rr/rcur;y=hy+(y-hy)*rr/rcur
        return Vector((x,y,z))
    n=64; ts=[i/18 for i in range(19)]
    rows=[[cap(i*2*pi/n,t) for i in range(n)] for t in ts]
    grid('Massa do cabelo',rows,hair,wrap=True)
    make('Fecho da risca',rows[0],[tuple(range(n))],[hair[0]])
    # Largas mechas sobrepostas seguem arcos oblíquos desde a risca frontal.
    for k in range(15):
        a=(k+.25)*2*pi/15
        rows=[]
        for t in [.07,.21,.35,.48,.60,.75,.88,1]:
            w=.235*(.45+.55*min(t*3,1))*(1-.78*max(0,(t-.80)/.2))
            row=[]
            for side in [-1,0,1]:
                an=a+w*side+.31*sin(a+.6)*sin(pi*t)
                p=cap(an,t)
                p+=Vector((sin(an),-cos(an),.30*(1-t)))*(.004 if side else .010)
                p.z-=max(0,(t-.8)/.2)*(.012+.019*(1+sin(k*5.1)))
                row.append(p)
            rows.append(row)
        grid('Mecha',rows,hair,lambda col,j:[0,3,1,0,2,3,1][(k+col)%7])
    # Acabamento localizado nos lábios. A superfície da boca pertence à malha anatômica.
    for matname,hexcolor in [('Lábio superior','955436'),('Lábio inferior','ac6343')]:
        corpo.data.materials.append(mat(matname,hexcolor))
    # Localiza o lábio inferior e o superior a partir do perfil frontal.
    face_mid=[]
    for i in range(42):
        z=ez-.115+i*.0018
        hit=bvh.ray_cast(Vector((0,-1,z)),Vector((0,1,0)),2)[0]
        if hit: face_mid.append((hit.y,z))
    if face_mid:
        # Dois máximos do perfil correspondem ao volume superior e inferior.
        peaks=[(y,z) for i,(y,z) in enumerate(face_mid[1:-1],1)
               if y<=face_mid[i-1][0] and y<=face_mid[i+1][0] and z<ez-.062]
        if peaks:
            lipz=min(peaks)[1]
            for face in corpo.data.polygons:
                c=face.center
                if c.y<-.102 and (c.x/.034)**2+((c.z-lipz)/.010)**2<1:
                    face.material_index=1 if c.z>lipz else 2
    # Leve elevação do olhar e rotação do pescoço como no estudo de três quartos.
    for part in group.children:
        if part.type!='MESH':continue
        for v in part.data.vertices:
            p=v.co
            flex=max(0,min(1,(p.z-(ez-.176))/.10))
            if 'Mecha' in part.name or 'cabelo' in part.name.lower():flex=max(flex,.15)
            angle=math.radians(-5 if f else -7)*flex
            oy=p.y+.012;oz=p.z-(ez-.14)
            p.y=-.012+cos(angle)*oy-sin(angle)*oz
            p.z=ez-.14+sin(angle)*oy+cos(angle)*oz
    group.rotation_euler.z=.035 if f else -.018
scene.camera.location=(-2.35,-8.1,2.23)
target=Vector((0,0,.94))
scene.camera.rotation_euler=(target-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.ortho_scale=2.02
scene.render.resolution_x=1024;scene.render.resolution_y=1050
scene.render.resolution_percentage=100
# Um preenchimento quente mantém os traços legíveis sem achatar todas as faces.
for lamp in scene.objects:
    if lamp.type=='LIGHT' and 'Recorte' in lamp.name:lamp.data.energy=120

for o in scene.objects:
    if o.type=='LIGHT' and 'Principal' in o.name:
        o.location=(-3,-4,5);o.data.energy=610;o.data.size=3.2
floor=next(o for o in scene.objects if o.type=='MESH' and 'Piso' in o.name)
floor.data.materials.clear()
areia=mat('Areia clara','edd3ab')
bs=next(n for n in areia.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
bs.inputs['Emission Color'].default_value=(.94,.72,.48,1)
bs.inputs['Emission Strength'].default_value=.56
floor.data.materials.append(areia)
for m in hair:
    bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bs.inputs['Specular IOR Level'].default_value=.19
scene.world.color=(.5,.46,.38)
folder=root/'exports/revisao_moradores_astra'
folder.mkdir(parents=True,exist_ok=True)
scene.render.filepath=str(folder/'dupla.png')
source=root/'art/blender/moradores_1500_astra.blend'
bpy.data.libraries.write(str(source),{scene},compress=True,fake_user=True)
