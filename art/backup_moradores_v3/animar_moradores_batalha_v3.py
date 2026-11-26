"""Rigs de batalha para cópias dos modelos aprovados; originais são preservados."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
RAIZ=Path(__file__).resolve().parents[1]
def suave(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def distancia_segmento(p,a,b):
    d=b-a;t=max(0,min(1,(p-a).dot(d)/max(d.length_squared,1e-9)))
    return (p-a-d*t).length
def produzir(tag):
    scene=bpy.data.scenes.new('Batalha_'+tag);bpy.context.window.scene=scene
    bpy.ops.import_scene.gltf(filepath=str(RAIZ/'assets/models/habitantes'/(tag+'.glb')))
    mesh=next(o for o in scene.objects if o.type=='MESH')
    if mesh.data.shape_keys:mesh.shape_key_clear()
    bpy.context.view_layer.objects.active=mesh;mesh.select_set(True)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    h=max(v.co.z for v in mesh.data.vertices)
    arm=bpy.data.armatures.new(tag+'_esqueleto');rig=bpy.data.objects.new(tag+'_rig_batalha',arm);scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    def bone(n,a,b,pai=None):
        x=arm.edit_bones.new(n);x.head=Vector(a)*h;x.tail=Vector(b)*h
        if pai:x.parent=arm.edit_bones[pai]
    bone('base',(0,0,0),(0,0,.12))
    bone('quadril',(0,0,.48),(0,0,.58),'base')
    bone('coluna',(0,0,.58),(0,0,.70),'quadril')
    bone('peito',(0,0,.70),(0,0,.78),'coluna')
    bone('cabeca',(0,0,.82),(0,0,.95),'peito')
    for l,s in [('E',1),('D',-1)]:
        bone('braco_'+l,(s*.12,0,.77),(s*.175,-.014,.60),'peito')
        bone('antebraco_'+l,(s*.175,-.014,.60),(s*.198,-.018,.44),'braco_'+l)
        bone('mao_'+l,(s*.198,-.018,.44),(s*.205,-.022,.385),'antebraco_'+l)
        bone('coxa_'+l,(s*.06,0,.49),(s*.065,0,.285),'quadril')
        bone('canela_'+l,(s*.065,0,.285),(s*.065,0,.075),'coxa_'+l)
        bone('pe_'+l,(s*.065,0,.075),(s*.065,-.085,.025),'canela_'+l)
    bpy.ops.object.mode_set(mode='OBJECT')
    for b in arm.bones:mesh.vertex_groups.new(name=b.name)
    mats=[m.name.lower() for m in mesh.data.materials]
    cabelo=set()
    roupa=set()
    for face in mesh.data.polygons:
        nome=mats[face.material_index]
        if 'cabelo' in nome or 'mecha' in nome:cabelo.update(face.vertices)
        if any(t in nome for t in ['barro','fibra','musgo','tecido','saia']):roupa.update(face.vertices)
    def setpeso(v,n,w):
        if w>.0001:mesh.vertex_groups[n].add([v],w,'REPLACE')
    for v in mesh.data.vertices:
        p=v.co;x,y,z=p;u=z/h;l='E' if x>=0 else 'D'
        if v.index in cabelo or u>.84:
            setpeso(v.index,'cabeca',1);continue
        braco=suave(.105*h,.16*h,abs(x)) if .30<u<.81 and v.index not in roupa else 0
        if .30<u<.67 and abs(x)>.14*h and v.index not in roupa:braco=1
        if braco>0:
            pulso=suave(.435,.495,u)
            cotovelo=suave(.575,.645,u)
            setpeso(v.index,'mao_'+l,braco*(1-pulso))
            setpeso(v.index,'antebraco_'+l,braco*pulso*(1-cotovelo))
            setpeso(v.index,'braco_'+l,braco*pulso*cotovelo)
        resto=1-braco
        if u<.51:
            if u>.44:
                f=suave(.51,.44,u)
                setpeso(v.index,'quadril',resto*(1-f));setpeso(v.index,'coxa_'+l,resto*f)
            elif u>.29:setpeso(v.index,'coxa_'+l,resto)
            elif u>.065:
                t=suave(.25,.32,u)
                setpeso(v.index,'coxa_'+l,resto*t);setpeso(v.index,'canela_'+l,resto*(1-t))
            else:setpeso(v.index,'pe_'+l,resto)
        elif u<.62:setpeso(v.index,'quadril',resto)
        elif u<.71:setpeso(v.index,'coluna',resto)
        elif u<.82:setpeso(v.index,'peito',resto)
        else:
            t=suave(.82,.84,u);setpeso(v.index,'peito',resto*(1-t));setpeso(v.index,'cabeca',resto*t)
    mesh.parent=rig
    mod=mesh.modifiers.new('Rig de batalha','ARMATURE');mod.object=rig
    rig.animation_data_create()
    def apontar(n,cabeca,cauda):
        b=arm.bones[n];q=(b.tail_local-b.head_local).rotation_difference(cauda-cabeca)@b.matrix_local.to_quaternion()
        rig.pose.bones[n].matrix=Matrix.Translation(cabeca)@q.to_matrix().to_4x4()
    def mao(l,alvo,giro=0):
        n='braco_'+l;b=arm.bones[n];pai=rig.pose.bones['peito']
        s=pai.matrix@arm.bones['peito'].matrix_local.inverted()@b.head_local
        alvo=Vector(alvo)*h+rig.pose.bones['base'].location
        direcao=alvo-s;d=max(.001,min(direcao.length,(b.tail_local-b.head_local).length+(arm.bones['antebraco_'+l].tail_local-arm.bones['antebraco_'+l].head_local).length-.001))
        direcao.normalize();alvo=s+direcao*d
        a=(b.tail_local-b.head_local).length;c=(arm.bones['antebraco_'+l].tail_local-arm.bones['antebraco_'+l].head_local).length
        proj=(a*a-c*c+d*d)/(2*d)
        pole=Vector((.6 if l=='E' else -.6,.2,-.8));pole=(pole-direcao*pole.dot(direcao)).normalized()
        e=s+direcao*proj+pole*math.sqrt(max(0,a*a-proj*proj))
        apontar(n,s,e);bpy.context.view_layer.update()
        apontar('antebraco_'+l,e,alvo);bpy.context.view_layer.update()
        q=Quaternion(Vector((1,0,0)),giro)@arm.bones['mao_'+l].matrix_local.to_quaternion()
        rig.pose.bones['mao_'+l].matrix=Matrix.Translation(alvo)@q.to_matrix().to_4x4()
    nomes=['pronto','andar','atacar_lanca','errar_lanca','atacar_arco','errar_arco','receber_golpe','esquivar','defender']
    for nome in nomes:
        rig.animation_data.action=None
        fim=48 if nome=='pronto' else 32
        for frame in range(1,fim+1):
            t=(frame-1)/(fim-1)
            for b in rig.pose.bones:b.rotation_mode='QUATERNION';b.matrix_basis=Matrix.Identity(4)
            e=Vector((.198,-.018,.44));d=Vector((-.198,-.018,.44));ge=gd=0
            onda=math.sin(math.pi*t)
            golpe=suave(.12,.45,t)*(1-suave(.58,.98,t))
            if nome in ['atacar_lanca','errar_lanca']:
                d=d.lerp(Vector((-.10,-.34,.66)),golpe);gd=1.35*golpe
                e=e.lerp(Vector((.12,-.17,.63)),golpe)
                rig.pose.bones['base'].location.y=-.07*golpe
                rig.pose.bones['peito'].rotation_quaternion=Quaternion(Vector((0,0,1)),(.22 if nome=='errar_lanca' else .08)*golpe)
            elif nome in ['atacar_arco','errar_arco']:
                armar=suave(0,.28,t)*(1-suave(.78,1,t))
                puxar=suave(.25,.53,t)*(1-suave(.57,.68,t))
                e=e.lerp(Vector((.13,-.34,.77)),armar)
                d=d.lerp(Vector((-.10,-.28,.75)).lerp(Vector((-.025,-.045,.84)),puxar),armar)
                gd=1.1*armar
            elif nome=='andar':
                ciclo=math.sin(t*math.tau*2)
                rig.pose.bones['base'].location.z=.012*(1-math.cos(t*math.tau*4))
                for lado,sinal in [('E',1),('D',-1)]:
                    rig.pose.bones['coxa_'+lado].rotation_quaternion=Quaternion(Vector((1,0,0)),.24*ciclo*sinal)
                    rig.pose.bones['canela_'+lado].rotation_quaternion=Quaternion(Vector((1,0,0)),max(0,-ciclo*sinal)*.25)
                e.y-=.025*ciclo;d.y+=.025*ciclo
            elif nome=='receber_golpe':
                rig.pose.bones['base'].location.y=.055*onda
                rig.pose.bones['coluna'].rotation_quaternion=Quaternion(Vector((1,0,0)),-.18*onda)
                rig.pose.bones['cabeca'].rotation_quaternion=Quaternion(Vector((1,0,0)),-.22*onda)
                e=e.lerp(Vector((.20,-.10,.62)),onda);d=d.lerp(Vector((-.20,-.10,.62)),onda)
            elif nome=='esquivar':
                rig.pose.bones['base'].location.x=.17*onda
                rig.pose.bones['coluna'].rotation_quaternion=Quaternion(Vector((0,1,0)),.20*onda)
                e=e.lerp(Vector((.18,-.06,.65)),onda);d=d.lerp(Vector((-.18,-.06,.65)),onda)
            elif nome=='defender':
                e=e.lerp(Vector((.04,-.14,.77)),onda);d=d.lerp(Vector((-.04,-.22,.75)),onda)
            else:rig.pose.bones['peito'].rotation_quaternion=Quaternion(Vector((1,0,0)),.008*math.sin(t*math.tau))
            bpy.context.view_layer.update();mao('E',e,ge);mao('D',d,gd)
            for b in rig.pose.bones:
                b.keyframe_insert('location',frame=frame);b.keyframe_insert('rotation_quaternion',frame=frame);b.keyframe_insert('scale',frame=frame)
        action=rig.animation_data.action;action.name=tag+'_'+nome;action.use_fake_user=True
        track=rig.animation_data.nla_tracks.new();track.name=nome
        strip=track.strips.new(nome,1,action);strip.action_slot=action.slots[0];track.mute=True
    rig.animation_data.action=None
    for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
    scene.frame_set(1);scene.render.fps=24;scene.frame_end=48
    bpy.ops.object.select_all(action='DESELECT');mesh.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
    pasta=RAIZ/'assets/models/habitantes/batalha';pasta.mkdir(parents=True,exist_ok=True)
    for tr in rig.animation_data.nla_tracks:tr.mute=False
    bpy.ops.export_scene.gltf(filepath=str(pasta/(tag+'.glb')),use_selection=True,use_active_scene=True,export_cameras=False,export_lights=False,export_animation_mode='NLA_TRACKS')
    for tr in rig.animation_data.nla_tracks:tr.mute=True
    print(tag,'h',h,'vertices',len(mesh.data.vertices),'ossos',len(arm.bones))
    return scene
cenas={produzir(t) for t in [f'{sexo}_{i:02d}' for sexo in ['homem','mulher'] for i in range(1,5)]}
bpy.data.libraries.write(str(RAIZ/'art/blender/moradores_batalha.blend'),cenas,fake_user=True,compress=True)
