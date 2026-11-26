"""Adiciona ações de batalha a uma cópia do asset aprovado da capivara."""
import bpy,math
from pathlib import Path
from mathutils import Matrix,Quaternion,Vector
RAIZ=Path(__file__).resolve().parents[1]
with bpy.data.libraries.load(str(RAIZ/'art/blender/capivara.blend'),link=False) as (origem,destino):destino.scenes=[origem.scenes[0]]
s=destino.scenes[0];s.name='Capivara_Batalha';bpy.context.window.scene=s
r=next(o for o in s.objects if o.type=='ARMATURE')
r.animation_data.action=None
for nome in ['investida','errar_ataque','receber_golpe','esquivar']:
    r.animation_data.action=None
    for frame in range(1,29):
        t=(frame-1)/27
        pulso=math.sin(math.pi*t)**2
        for b in r.pose.bones:b.rotation_mode='XYZ';b.matrix_basis=Matrix.Identity(4)
        if nome in ['investida','errar_ataque']:
            r.pose.bones['raiz'].location.y=-.16*pulso
            r.pose.bones['tronco'].rotation_euler.x=.08*pulso
            r.pose.bones['cabeca'].rotation_euler.x=-.24*math.sin(math.tau*t)
            r.pose.bones['pescoco'].rotation_euler.x=.12*pulso
            if nome=='errar_ataque':r.pose.bones['raiz'].rotation_euler.z=.17*pulso
            for lado in ['E','D']:r.pose.bones['frente_'+lado].rotation_euler.x=-.16*pulso
        elif nome=='receber_golpe':
            r.pose.bones['raiz'].location.y=.08*pulso
            r.pose.bones['tronco'].rotation_euler.x=-.10*pulso
            r.pose.bones['cabeca'].rotation_euler.z=.12*math.sin(t*math.tau)*pulso
            r.pose.bones['pescoco'].rotation_euler.x=-.16*pulso
        else:
            r.pose.bones['raiz'].location.x=.14*pulso
            r.pose.bones['tronco'].rotation_euler.z=.07*pulso
            r.pose.bones['cabeca'].rotation_euler.z=-.14*pulso
        for b in r.pose.bones:
            b.keyframe_insert('location',frame=frame);b.keyframe_insert('rotation_euler',frame=frame)
    a=r.animation_data.action;a.name='capivara_'+nome;a.use_fake_user=True
    track=r.animation_data.nla_tracks.new();track.name=nome
    strip=track.strips.new(nome,1,a);strip.action_slot=a.slots[0];track.mute=True
r.animation_data.action=None
for b in r.pose.bones:b.matrix_basis=Matrix.Identity(4)
s.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for o in s.objects:
    if o.type in ['ARMATURE','MESH','EMPTY']:o.select_set(True)
bpy.context.view_layer.objects.active=r
folder=RAIZ/'assets/models/animais/batalha';folder.mkdir(parents=True,exist_ok=True)
for t in r.animation_data.nla_tracks:t.mute=False
bpy.ops.export_scene.gltf(filepath=str(folder/'capivara.glb'),use_selection=True,use_active_scene=True,export_cameras=False,export_lights=False,export_animation_mode='NLA_TRACKS')
for t in r.animation_data.nla_tracks:t.mute=True
bpy.data.libraries.write(str(RAIZ/'art/blender/capivara_batalha.blend'),{s},fake_user=True,compress=True)
print('Capivara: animações', [t.name for t in r.animation_data.nla_tracks])
