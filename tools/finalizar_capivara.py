"""Rig, materiais compartilhados, movimentos de inspeção e exportação da capivara A."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector
RAIZ=Path(__file__).resolve().parents[1]
scene=bpy.context.scene
root=next(o for o in scene.objects if o.type=='EMPTY')
objetos=[o for o in scene.objects if o.type=='MESH']
pele=bpy.data.materials.new('Capivara_Cores');pele.use_nodes=True
bs=next(n for n in pele.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
bs.inputs['Roughness'].default_value=.83
vc=pele.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Cor'
pele.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
olho=next(o for o in objetos if o.name.startswith('Olho')).data.materials[0]
for o in objetos:
    cores=o.data.color_attributes.new(name='Cor',type='FLOAT_COLOR',domain='CORNER')
    originais=list(o.data.materials)
    indices=[]
    for p in o.data.polygons:
        m=originais[p.material_index]
        n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        cor=n.inputs['Base Color'].default_value
        for i in p.loop_indices:cores.data[i].color=cor
        indices.append(1 if m==olho else 0)
    o.data.materials.clear();o.data.materials.append(pele);o.data.materials.append(olho)
    for p,idx in zip(o.data.polygons,indices):p.material_index=idx
no_olho=next(n for n in olho.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
cor_olho=olho.node_tree.nodes.new('ShaderNodeVertexColor');cor_olho.layer_name='Cor'
olho.node_tree.links.new(cor_olho.outputs['Color'],no_olho.inputs['Base Color'])
bpy.ops.object.select_all(action='DESELECT')
for o in objetos:o.select_set(True)
bpy.context.view_layer.objects.active=next(o for o in objetos if o.name.startswith('Corpo'))
bpy.ops.object.join();corpo=bpy.context.object;corpo.name='Capivara_Malha'
data=bpy.data.armatures.new('Esqueleto_capivara');rig=bpy.data.objects.new('Rig_capivara',data);scene.collection.objects.link(rig);rig.parent=root
bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
def osso(nome,a,b,pai=None):
    o=data.edit_bones.new(nome);o.head=a;o.tail=b
    if pai:o.parent=data.edit_bones[pai]
    return o
osso('raiz',(0,0,0),(0,0,.15))
osso('tronco',(0,.23,.40),(0,-.18,.48),'raiz')
osso('pescoco',(0,-.18,.48),(0,-.35,.54),'tronco')
osso('cabeca',(0,-.35,.54),(0,-.61,.57),'pescoco')
for lado,sinal in [('E',1),('D',-1)]:
    for membro,y in [('frente',-.22),('tras',.32)]:
        x=sinal*.155
        osso(membro+'_'+lado,(x,y,.44),(x,y,.23),'raiz')
        osso(membro+'_canela_'+lado,(x,y,.23),(x,y,.075),membro+'_'+lado)
        osso(membro+'_pe_'+lado,(x,y,.075),(x,y-.08,.035),membro+'_canela_'+lado)
bpy.ops.object.mode_set(mode='OBJECT')
for b in data.bones:corpo.vertex_groups.new(name=b.name)
def atribuir(i,n,w):
    if w>.0001:corpo.vertex_groups[n].add([i],w,'REPLACE')
for v in corpo.data.vertices:
    x,y,z=v.co
    cab=max(0,min(1,(-y-.20)/.16))
    if cab>0 and z>.33:
        atribuir(v.index,'cabeca',cab);atribuir(v.index,'tronco',1-cab)
        continue
    membro='frente' if y<.04 else 'tras'
    lado='E' if x>0 else 'D'
    peso=max(0,min(1,(.41-z)/.16))*max(0,min(1,(abs(x)-.07)/.06))
    if z<.115 and abs(x)>.08:peso=1
    superior=membro+'_'+lado;inferior=membro+'_canela_'+lado;pe=membro+'_pe_'+lado
    if z>.23:
        atribuir(v.index,superior,peso)
    elif z>.09:
        blend=max(0,min(1,(z-.12)/.12));atribuir(v.index,superior,peso*blend);atribuir(v.index,inferior,peso*(1-blend))
    else:atribuir(v.index,pe,peso)
    atribuir(v.index,'tronco',1-peso)
corpo.parent=rig
mod=corpo.modifiers.new('Deformacao','ARMATURE');mod.object=rig
rig.animation_data_create()
for nome,fim,amp in [('parada',64,.0),('andar',32,.30),('correr',20,.52)]:
    rig.animation_data.action=None
    for b in rig.pose.bones:
        b.rotation_mode='XYZ';b.rotation_euler=(0,0,0);b.location=(0,0,0);b.scale=(1,1,1)
    for frame in range(1,fim+1):
        fase=(frame-1)/(fim-1)*2*math.pi
        rig.pose.bones['cabeca'].rotation_euler.x=.018*math.sin(fase)
        rig.pose.bones['cabeca'].keyframe_insert('rotation_euler',frame=frame)
        for lado in ['E','D']:
            for membro in ['frente','tras']:
                offset=(0 if (lado=='E')==(membro=='frente') else math.pi)
                onda=math.sin(fase+offset)
                b=rig.pose.bones[membro+'_'+lado];b.rotation_euler.x=amp*onda;b.keyframe_insert('rotation_euler',frame=frame)
                b=rig.pose.bones[membro+'_canela_'+lado];b.rotation_euler.x=-amp*.65*max(0,-onda);b.keyframe_insert('rotation_euler',frame=frame)
        b=rig.pose.bones['tronco'];b.scale.z=1+.007*math.sin(fase*2);b.keyframe_insert('scale',frame=frame)
    acao=rig.animation_data.action;acao.name=nome;acao.use_fake_user=True
    track=rig.animation_data.nla_tracks.new();track.name=nome
    strip=track.strips.new(nome,1,acao)
    if acao.slots:strip.action_slot=acao.slots[0]
    track.mute=True
rig.animation_data.action=None
for b in rig.pose.bones:b.rotation_euler=(0,0,0);b.scale=(1,1,1)
scene.frame_set(1);scene.render.fps=24;scene.frame_start=1;scene.frame_end=64
bpy.ops.object.select_all(action='DESELECT')
for o in [root,rig,corpo]:o.select_set(True)
bpy.context.view_layer.objects.active=rig
pasta=RAIZ/'assets/models/animais';pasta.mkdir(parents=True,exist_ok=True)
for track in rig.animation_data.nla_tracks:track.mute=False
bpy.ops.export_scene.gltf(filepath=str(pasta/'capivara.glb'),use_selection=True,use_active_scene=True,export_cameras=False,export_lights=False,export_animations=True,export_animation_mode='NLA_TRACKS')
for track in rig.animation_data.nla_tracks:track.mute=True
bpy.data.libraries.write(str(RAIZ/'art/blender/capivara.blend'),{scene},fake_user=True,compress=True)
vs=[corpo.matrix_world@v.co for v in corpo.data.vertices]
medidas={'bounds_blender':[[min(v[i] for v in vs),max(v[i] for v in vs)] for i in range(3)],'triangulos':sum(len(p.vertices)-2 for p in corpo.data.polygons),'vertices':len(vs),'malhas':1,'materiais':len(corpo.data.materials),'ossos':len(data.bones),'animacoes':['parada','andar','correr'],'frente':'Blender -Y / Godot +Z','estado':'A aprovada, B pendente'}
(RAIZ/'art/references/etapa_10/medidas_capivara.json').write_text(json.dumps(medidas,indent=2),encoding='utf-8')
print(json.dumps(medidas))
