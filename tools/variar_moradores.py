"""Gera a família da dupla aprovada e GLBs com poses para o movimento em jogo."""
import bpy
from math import sin, cos, exp, pi, atan2, hypot
from mathutils import Vector
from pathlib import Path

root = Path(__file__).resolve().parents[1]
scene = bpy.context.scene
donors = sorted([o for o in scene.objects if o.type == 'EMPTY' and any('Anatomia' in c.name for c in o.children)], key=lambda o: o.name)
assert len(donors) == 2
# Altura, ombros, cintura, quadris, volume das pernas, comprimento das pernas.
profiles = [
    [(1,0,0,0,0,0),(.92,.17,.21,.08,.20,-.05),(1.06,-.06,-.10,-.05,-.08,.07),(.98,.07,.38,.19,.18,-.02)],
    [(1,0,0,0,0,0),(.93,.04,.29,.24,.22,-.05),(1.01,.19,.04,.09,.20,.01),(1.075,-.07,-.09,-.05,-.10,.07)]
]
styles = [['original','curto','coque','ombros'],['original','chanfrado','tranca','rabo']]
def bell(z,c,r):
    return exp(-((z-c)/r)**2)
def deform(p):
    x,y,z = p
    height, shoulder, waist, hip, leg, length = profile
    u = z/h
    a = shoulder*bell(u,.76,.094)
    b = waist*bell(u,.579,.108)
    c = hip*bell(u,.49,.075)
    thigh = leg*bell(u,.314,.15)
    torso = max(0,min(1,(.29-abs(x))/.095))
    # A cintura altera o tronco; a mão acompanha a largura dos ombros.
    arm = (1-torso)*(.06*shoulder+.12*max(0,waist))*min(1,max(0,(.88-u)/.15))
    return (x*(1+a+torso*(b+c)+thigh*.6)+arm*(1 if x>0 else -1), y*(1+a*.58+torso*(b*1.26+c*.81)+thigh), height*z+length*h*sin(pi*min(1,max(0,u))))
def restyle(p):
    x,y,z = p
    a = atan2(x,-(y+.025))
    side = (1-cos(a))/2
    top = h-.055
    drop = max(0,top-z)
    if style in ['curto','coque','tranca','rabo','chanfrado']:
        limit = (.065+.085*side) if style != 'chanfrado' else (.075+.20*min(1,side*2)+.036*sin(a))
        if style == 'curto': limit += .026*sin(2*a+.4)
        if drop>limit:
            z=top-limit-(drop-limit)*(.29 if style=='chanfrado' else .12)
            fac=1-(.10 if style=='chanfrado' else .20)*min(1,(drop-limit)/.15)
            x*=fac; y=-.025+(y+.025)*fac
    if style=='ombros':
        z-=.17*min(1,side*1.9)*min(1,drop/.19)**2
        x*=1+.08*min(1,drop/.19)
    return Vector((x,y,z))
def lock(name,centers,radii,materials):
    vs=[]; faces=[]; n=12
    for j,p in enumerate(map(Vector,centers)):
        t=(Vector(centers[min(j+1,len(centers)-1)])-Vector(centers[max(0,j-1)])).normalized()
        b=t.cross(Vector((1,0,0))).normalized(); a=b.cross(t).normalized()
        for i in range(n):
            v=p+radii[j]*(cos(2*pi*i/n)*a+.88*sin(2*pi*i/n)*b)
            vs.append(deform(v))
            if j: faces.append(((j-1)*n+i,(j-1)*n+(i+1)%n,j*n+(i+1)%n,j*n+i))
    faces.extend([tuple(reversed(range(n))),tuple(range(len(vs)-n,len(vs)))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh); group.objects.link(o);o.parent=person
    for m in materials: mesh.materials.append(m)
    for i,f in enumerate(mesh.polygons): f.material_index=(i%n//3)%len(materials)
def extras():
    if style=='coque':
        lock('Coque enrolado',[(0,.084,h-.047),(0,.115,h-.025),(0,.127,h+.015),(0,.124,h+.048),(0,.123,h+.069)],[.025,.054,.066,.050,.012],hair)
    if style=='rabo':
        lock('Rabo alto',[(.048,.082,h-.059),(.098,.125,h-.044),(.134,.158,h-.085),(.166,.160,h-.18),(.179,.118,h-.278),(.185,.086,h-.382),(.159,.090,h-.435)],[.039,.033,.060,.055,.045,.025,.003],hair)
    if style=='tranca':
        for k in range(3):
            pts=[]; radii=[]
            for j in range(38):
                t=j/37; a=2*pi*(k/3+2.4*t)
                pts.append((.075+.093*sin(pi*t*.74)+.015*cos(a)*(1-t),.086-.230*sin(t*pi*.53)+.016*sin(a)*(1-t),h-.141-.435*t))
                radii.append(.022*(1-.69*t))
            lock('Trança lateral',pts,radii,hair)
        lock('Ponta da trança',[pts[-1],(.14,-.148,h-.61),(.132,-.146,h-.646)],[.013,.017,.002],hair)

models=root/'assets/models/habitantes'; models.mkdir(exist_ok=True)
family=[]
for sex, donor in enumerate(donors):
    h = 1.74 if sex else 1.83
    for i,profile in enumerate(profiles[sex]):
        style=styles[sex][i]
        tag=('mulher' if sex else 'homem')+'_%02d'%(i+1)
        group=bpy.data.collections.new(tag);scene.collection.children.link(group)
        person=bpy.data.objects.new(tag,None);group.objects.link(person)
        for old in donor.children:
            if old.type!='MESH': continue
            o=old.copy();o.data=old.data.copy();group.objects.link(o);o.parent=person
            is_hair=old.name.startswith(('Massa do cabelo','Mecha','Fecho da risca'))
            if old.name.startswith('Massa do cabelo'): hair=list(o.data.materials)
            for v in o.data.vertices:
                v.co=deform(restyle(v.co) if is_hair else v.co)
            if style=='ombros' and is_hair:
                for slot in o.material_slots:
                    original=slot.material
                    m=bpy.data.materials.get('Grafite '+original.name)
                    if not m:
                        m=original.copy();m.name='Grafite '+original.name
                        bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
                        c=bs.inputs['Base Color'].default_value
                        bs.inputs['Base Color'].default_value=(c[0]*2.2+.018,c[1]*2.1+.017,c[2]*2+.015,1)
                    slot.material=m
        extras()
        # Unir apenas a cópia de exportação. O fonte mantém roupa e mechas editáveis.
        bpy.ops.object.select_all(action='DESELECT')
        pieces=list(person.children)
        for part in pieces: part.select_set(True)
        bpy.context.view_layer.objects.active=pieces[0]
        bpy.ops.object.duplicate()
        bpy.ops.object.join()
        mesh=bpy.context.object
        mesh.matrix_world.identity(); mesh.parent=None
        mesh.name=tag+'_corpo'
        mesh.shape_key_add(name='Basis')
        for pose in ['Passo_E','Passo_D','Coletar']:
            key=mesh.shape_key_add(name=pose)
            for vert in key.data:
                x,y,z=vert.co; u=z/(h*profile[0]); side=1 if x>=0 else -1
                if pose=='Coletar':
                    lean=max(0,u-.50)
                    vert.co.y-=lean*.48
                    vert.co.z-=lean*.18
                    if abs(x)>.23 and .44<u<.74:
                        vert.co.y-=.14*min(1,(abs(x)-.23)/.09)
                else:
                    s=side*(1 if pose=='Passo_E' else -1)
                    if u<.49:
                        step=(.49-u)/.49
                        vert.co.y+=s*.21*step
                        vert.co.z+=.026*step*(s+1)*.5
                    elif abs(x)>.22 and u<.81:
                        vert.co.y-=s*.12*min(1,(.81-u)/.30)*min(1,(abs(x)-.22)/.08)
        bpy.ops.export_scene.gltf(filepath=str(models/(tag+'.glb')),use_selection=True,export_animations=False,export_morph=True,export_morph_normal=False,export_yup=True)
        bpy.data.objects.remove(mesh,do_unlink=True)
        person.location.x=(i-1.5)*.87
        family.append((sex,group,person))
for donor in donors:
    for obj in list(donor.children)+[donor]: bpy.data.objects.remove(obj,do_unlink=True)
folder=root/'exports/revisao_variacoes';folder.mkdir(parents=True,exist_ok=True)
camera=scene.camera
def aim(center,scale):
    target=Vector(center); camera.location=target+Vector((-.8,-8,1.10))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=scale
for sex,group,p in family: p.location.x+=(sex-.5)*3.55
aim((0,0,.96),7.35)
scene.render.resolution_x=1600;scene.render.resolution_y=520
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art/blender/familia_moradores.blend'),compress=True)
for sex,name in enumerate(['homens','mulheres']):
    for sx,group,p in family:
        group.hide_render=sx!=sex
        p.location.x-=(sx-.5)*3.55 if sex==0 else 0
    aim((0,0,.99),4.05)
    scene.render.resolution_x=1100;scene.render.resolution_y=650;scene.render.resolution_percentage=100
    scene.render.filepath=str(folder/(name+'.png'))
    bpy.ops.render.render(write_still=True)
