"""Capivara A: anatomia original em malha unificada, produzida no Blender via MCP."""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector
RAIZ=Path(__file__).resolve().parents[1]
scene=bpy.data.scenes.new('Capivara_A_Inspecao')
bpy.context.window.scene=scene
scene.unit_settings.system='METRIC'
root=bpy.data.objects.new('Capivara_A',None)
scene.collection.objects.link(root)
root['referencia']='art/references/etapa_10/capivara_opcoes.png — A aprovada no chat'
root['estado']='Asset em produção para aprovação B; sem mecânica'
def mat(nome,hex,rough=.82):
    c=[int(hex[i:i+2],16)/255 for i in (0,2,4)]
    c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
    m=bpy.data.materials.new('Capivara_'+nome);m.use_nodes=True
    n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    n.inputs['Base Color'].default_value=(*c,1)
    n.inputs['Roughness'].default_value=rough
    m.diffuse_color=(*c,1)
    return m
pelos=[mat('Pelo_'+str(i),c) for i,c in enumerate(['a66c3e','aa7041','a0683b','ae7445','a96d3e','a26a3e','ad7344'])]
focinho=mat('Focinho','785039');unha=mat('Unhas','57422f');escuro=mat('Narinas','32271f');olho=mat('Olhos','281d12',.24);iris=mat('Iris','593a20',.36);brilho=mat('Reflexo','e6d3a2',.18);orelha=mat('Orelha_interna','845539')
def mesh(nome,verts,faces,material=None):
    data=bpy.data.meshes.new(nome);data.from_pydata(verts,[],faces);data.update()
    o=bpy.data.objects.new(nome,data);scene.collection.objects.link(o);o.parent=root
    if material:data.materials.append(material)
    return o
def loft_y(nome,secoes,n=16,expoente=1):
    vs=[]
    for y,rx,baixo,alto in secoes:
        for j in range(n):
            a=2*math.pi*j/n
            sen=math.copysign(abs(math.sin(a))**expoente,math.sin(a))
            cos=math.copysign(abs(math.cos(a))**expoente,math.cos(a))
            vs.append((rx*sen,y,(baixo+alto)/2+(alto-baixo)/2*cos))
    fs=[]
    for k in range(len(secoes)-1):
        for j in range(n):
            a=k*n+j;b=k*n+(j+1)%n
            fs.append((a,b,b+n,a+n))
    fs.extend([tuple(reversed(range(n))),tuple((len(secoes)-1)*n+j for j in range(n))])
    return mesh(nome,vs,fs)
def esfera(nome,centro,escala,material=None,seg=12,rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=centro)
    o=bpy.context.object;o.name=nome;o.scale=escala
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.parent=root
    if material:o.data.materials.append(material)
    return o
partes=[]
partes.append(loft_y('Tronco',[(.49,.06,.37,.52),(.44,.16,.26,.61),(.32,.225,.23,.66),(.14,.235,.22,.665),(-.05,.21,.25,.65),(-.21,.18,.29,.64),(-.31,.12,.35,.61)]))
partes.append(loft_y('Cabeca_pescoco',[(-.18,.105,.39,.64),(-.30,.145,.37,.70),(-.43,.166,.385,.735),(-.56,.176,.385,.73),(-.69,.163,.395,.69),(-.79,.137,.415,.65)],16,.65))
for lado in [-1,1]:
    partes.append(esfera('Ombro',(lado*.145,-.21,.405),(.080,.10,.19)))
    partes.append(esfera('Antebraco',(lado*.155,-.245,.22),(.055,.064,.18)))
    partes.append(esfera('Pe_dianteiro',(lado*.155,-.285,.052),(.057,.092,.052)))
    partes.append(esfera('Coxa',(lado*.155,.305,.39),(.087,.145,.20)))
    partes.append(esfera('Canela_traseira',(lado*.165,.372,.17),(.057,.068,.16)))
    partes.append(esfera('Pe_traseiro',(lado*.165,.322,.05),(.057,.095,.05)))
bpy.ops.object.select_all(action='DESELECT')
for o in partes:o.select_set(True)
bpy.context.view_layer.objects.active=partes[0]
bpy.ops.object.join();corpo=bpy.context.object;corpo.name='Corpo_capivara'
rem=corpo.modifiers.new('Uniao_anatomica','REMESH');rem.mode='VOXEL';rem.voxel_size=.012;rem.use_smooth_shade=False
bpy.ops.object.modifier_apply(modifier=rem.name)
sm=corpo.modifiers.new('Transicoes_musculares','SMOOTH');sm.factor=1.4;sm.iterations=4
bpy.ops.object.modifier_apply(modifier=sm.name)
dec=corpo.modifiers.new('Facetas_controladas','DECIMATE');dec.ratio=min(1,1100/len(corpo.data.polygons));dec.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier=dec.name)
for m in pelos:corpo.data.materials.append(m)
rng=random.Random(150010)
for p in corpo.data.polygons:p.material_index=rng.choices(range(7),[6,1,1,1,1,1,1])[0];p.use_smooth=False
# Muzzle is a shallow fitted surface, not a detached sphere.
corpo.data.materials.append(focinho)
for p in corpo.data.polygons:
    if p.center.y<-.754:p.material_index=7
for lado in [-1,1]:
    # Fitted almond eyelids and an inset, small glossy eye.
    hit,centro,normal,indice=corpo.ray_cast(Vector((lado*.4,-.56,.644)),Vector((-lado,0,0)))
    centro+=normal*.001
    horiz=Vector((.3*lado,.9,0)).normalized();vertical=normal.cross(horiz).normalized()
    if vertical.z<0:vertical=-vertical
    v=[]
    for rx,rz,prof in [(.031,.021,-.001),(.023,.014,.002)]:
        for j in range(12):
            a=2*math.pi*j/12
            v.append(centro+horiz*rx*math.cos(a)+vertical*rz*math.sin(a)+normal*prof)
    mesh('Palpebra',v,[(j,(j+1)%12,(j+1)%12+12,j+12) for j in range(12)],focinho)
    o=esfera('Olho',centro+normal*.001,(.023,.014,.005),olho,16,8)
    o.rotation_euler=normal.to_track_quat('Z','Y').to_euler()
    esfera('Ponto_de_luz',centro+normal*.006+vertical*.003+horiz*-.004,(.0016,.0016,.0016),brilho,8,4)
    nar=esfera('Narina',(lado*.067,-.783,.581),(.020,.009,.012),escuro,10,6)
    # Small low-poly round ears, with recessed warm inner concha.
    x=lado*.125;y=-.397
    esfera('Orelha',(x,y,.719),(.034,.024,.040),pelos[0],10,6)
    esfera('Concha_orelha',(x,y-.019,.729),(.022,.007,.023),orelha,10,5)
    for y,count in [(-.285,4),(.322,3)]:
        for j in range(count):
            dx=(j-(count-1)/2)*.025
            esfera('Unha',(lado*(.155 if y<0 else .165)+dx,y-.078,.025),(.010,.020,.013),unha,8,5)
# A subtle closed mouth line follows the muzzle, without projecting teeth.
mesh('Linha_boca',[(-.105,-.779,.449),(-.047,-.791,.443),(.047,-.791,.443),(.105,-.779,.449),(.047,-.792,.438),(-.047,-.792,.438)],[(0,1,5),(1,2,4,5),(2,3,4)],escuro)
for o in scene.objects:
    if o.type=='MESH':
        inv=o.matrix_world.inverted()
        for v in o.data.vertices:
            p=o.matrix_world@v.co
            if p.y<-.30:p.y=-.30+(p.y+.30)*.72
            v.co=inv@p
        o.data.update()
        for p in o.data.polygons:p.use_smooth=False
scene.world=bpy.data.worlds.new('Ambiente_capivara');scene.world.use_nodes=True
bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.23,.26,.20,1);bg.inputs['Strength'].default_value=.65
for nome,pos,energia,tamanho in [('Principal',(2,-3,4),450,3),('Recorte',(-2,1,3),350,2),('Preenchimento',(-2,-2,1.4),120,3)]:
    data=bpy.data.lights.new(nome,'AREA');data.energy=energia;data.shape='DISK';data.size=tamanho
    o=bpy.data.objects.new(nome,data);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,-.1,.4))-o.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.objects.new('Camera_capivara',bpy.data.cameras.new('Camera_capivara'));scene.collection.objects.link(camera)
camera.location=(1.5,-2.1,1.05);camera.rotation_euler=(Vector((0,-.10,.38))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=1.7;scene.camera=camera
scene.render.resolution_x=1200;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=1.9
        area.spaces.active.region_3d.view_location=(0,-.10,.38)
        area.spaces.active.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
print('Capivara modelada:',len(corpo.data.vertices),'vertices no corpo;',len(corpo.data.polygons),'faces')
