"""Moradores originais, proposta A aprovada. Executar no Blender via MCP.
As roupas são uma convenção artística, não uma reconstrução histórica.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

RAIZ = Path(r'C:\Users\PC\Documents\ChatGPT\1500')
NOME_CENA = '1500_Moradores'


def cor(h):
    def linear(v):
        return v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4
    return tuple(linear(int(h[i:i+2], 16)/255) for i in (0, 2, 4)) + (1,)


def material(nome, h):
    m = bpy.data.materials.new('Habitante_' + nome)
    m.use_nodes = True
    m.diffuse_color = cor(h)
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = cor(h)
    bsdf.inputs['Roughness'].default_value = .88
    return m


class Malha:
    def __init__(self, materiais, escala=1):
        self.v, self.f, self.m, self.pesos = [], [], [], []
        self.materiais, self.escala = materiais, escala

    def vertice(self, p, pesos):
        self.v.append(tuple(Vector(p) * self.escala))
        self.pesos.append(pesos if isinstance(pesos, dict) else {pesos: 1.0})
        return len(self.v)-1

    def face(self, pontos, mat, pesos):
        self.f.append(tuple(self.vertice(p, pesos) for p in pontos))
        self.m.append(mat)

    def aneis(self, aneis, mat, pesos, tampar=True):
        ids = []
        for j, anel in enumerate(aneis):
            peso = pesos[j] if isinstance(pesos, list) else pesos
            ids.append([self.vertice(p, peso) for p in anel])
        n = len(ids[0])
        for j in range(len(ids)-1):
            for i in range(n):
                # Alterna diagonais; facetas intencionais sem modificador de subdivisão.
                a,b,c,d = ids[j][i],ids[j][(i+1)%n],ids[j+1][(i+1)%n],ids[j+1][i]
                self.f.extend([(a,b,c),(a,c,d)])
                self.m.extend([mat,mat])
        if tampar:
            self.f.extend([tuple(reversed(ids[0])),tuple(ids[-1])])
            self.m.extend([mat,mat])

    def horizontal(self, linhas, mat, pesos, lados=12):
        self.aneis([[(cx+rx*math.cos(i*math.tau/lados), cy+ry*math.sin(i*math.tau/lados), z)
                     for i in range(lados)] for z,cx,cy,rx,ry in linhas],mat,pesos)

    def tubo(self, pontos, raios, mat, pesos, lados=8):
        pts = [Vector(p) for p in pontos]
        aneis = []
        for j,(p,r) in enumerate(zip(pts,raios)):
            eixo=(pts[min(j+1,len(pts)-1)]-pts[max(0,j-1)]).normalized()
            lateral=eixo.cross(Vector((0,1,0)))
            if lateral.length<.01:
                lateral=eixo.cross(Vector((1,0,0)))
            lateral.normalize()
            outro=eixo.cross(lateral).normalized()
            rx,ry = r if isinstance(r,tuple) else (r,r)
            aneis.append([p+lateral*rx*math.cos(i*math.tau/lados)+outro*ry*math.sin(i*math.tau/lados) for i in range(lados)])
        self.aneis(aneis,mat,pesos)

    def elipsoide(self, centro, raio, mat, peso, lados=10):
        x,y,z=centro
        rx,ry,rz=raio
        self.horizontal([(z+rz*t,x,y,rx*math.sqrt(max(.01,1-t*t)),ry*math.sqrt(max(.01,1-t*t)))
                         for t in [-.98,-.7,-.25,.25,.7,.98]],mat,peso,lados)

    def objeto(self, nome, cena, rig):
        dados=bpy.data.meshes.new(nome+'_Malha')
        dados.from_pydata(self.v,[],self.f)
        dados.update()
        for m in self.materiais:
            dados.materials.append(m)
        for face,m in zip(dados.polygons,self.m):
            face.material_index=m
        bm=bmesh.new()
        bm.from_mesh(dados)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(dados)
        bm.free()
        uv=dados.uv_layers.new(name='UVMap')
        for face in dados.polygons:
            for loop in face.loop_indices:
                p=dados.vertices[dados.loops[loop].vertex_index].co
                uv.data[loop].uv=(p.x+.5,p.z/2)
        obj=bpy.data.objects.new(nome,dados)
        cena.collection.objects.link(obj)
        obj.parent=rig
        for bone in rig.data.bones:
            grupo=obj.vertex_groups.new(name=bone.name)
            for i,pesos in enumerate(self.pesos):
                if bone.name in pesos:
                    grupo.add([i],pesos[bone.name],'REPLACE')
        modificador=obj.modifiers.new('Deformacao','ARMATURE')
        modificador.object=rig
        return obj


def criar_rig(cena,nome,escala):
    arm=bpy.data.armatures.new(nome+'_Esqueleto')
    rig=bpy.data.objects.new(nome,arm)
    cena.collection.objects.link(rig)
    with bpy.context.temp_override(scene=cena,view_layer=cena.view_layers[0]):
        for o in bpy.context.selected_objects:
            o.select_set(False)
        rig.select_set(True)
        bpy.context.view_layer.objects.active=rig
        bpy.ops.object.mode_set(mode='EDIT')
        def osso(n,a,b,pai=None):
            bone=arm.edit_bones.new(n)
            bone.head=Vector(a)*escala
            bone.tail=Vector(b)*escala
            referencia=Vector((0,1,0))
            if (bone.tail-bone.head).normalized().cross(referencia).length<.1:
                referencia=Vector((0,0,1))
            bone.align_roll(referencia)
            if pai:
                bone.parent=arm.edit_bones[pai]
        osso('Raiz',(0,0,0),(0,0,.15))
        osso('Quadril',(0,0,.88),(0,0,1.05),'Raiz')
        osso('Coluna',(0,0,1.05),(0,0,1.28),'Quadril')
        osso('Peito',(0,0,1.28),(0,0,1.43),'Coluna')
        osso('Pescoco',(0,0,1.43),(0,0,1.51),'Peito')
        osso('Cabeca',(0,0,1.51),(0,0,1.84),'Pescoco')
        for s,l in [(1,'E'),(-1,'D')]:
            osso('Braco.'+l,(s*.23,0,1.39),(s*.35,0,1.10),'Peito')
            osso('Antebraco.'+l,(s*.35,0,1.10),(s*.405,-.01,.88),'Braco.'+l)
            osso('Mao.'+l,(s*.405,-.01,.88),(s*.44,-.015,.72),'Antebraco.'+l)
            osso('Coxa.'+l,(s*.10,0,.91),(s*.105,-.015,.51),'Quadril')
            osso('Canela.'+l,(s*.105,-.015,.51),(s*.11,0,.13),'Coxa.'+l)
            osso('Pe.'+l,(s*.11,0,.13),(s*.11,-.18,.06),'Canela.'+l)
        bpy.ops.object.mode_set(mode='OBJECT')
    return rig


def criar_corpo(cena,nome,feminino=False):
    escala=.95 if feminino else 1.0
    mats=[material(nome+'_Pele','9e613c' if feminino else 'ad7046'),
          material(nome+'_Cabelo','20221d'),material(nome+'_Terracota','a84e2f'),
          material(nome+'_Folha','68743b'),material(nome+'_Fibra','bb9b61'),
          material(nome+'_Olhos','27251f'),material(nome+'_BrancoOlho','d7c39a'),
          material(nome+'_Labios','774b35')]
    rig=criar_rig(cena,nome,escala)
    m=Malha(mats,escala)
    # Silhueta adulta: cerca de seis cabeças, cintura e ombros definidos.
    ombro=.215 if feminino else .245
    cintura=.137 if feminino else .151
    quadril=.19 if feminino else .175
    m.horizontal([(.86,0,0,quadril,.105),(.96,0,0,quadril,.115),
                  (1.06,0,0,cintura,.097),(1.17,0,-.007,.16 if feminino else .19,.105),
                  (1.29,0,-.007,.198 if feminino else .23,.122),
                  (1.38,0,0,ombro,.103),(1.43,0,0,.175 if feminino else .195,.081)],0,
                 ['Quadril','Quadril','Coluna','Coluna','Peito','Peito','Peito'])
    m.horizontal([(1.41,0,0,.059,.052),(1.49,0,-.003,.059,.055),(1.53,0,-.004,.067,.06)],0,'Pescoco',8)
    for s,l in [(1,'E'),(-1,'D')]:
        m.tubo([(s*.10,0,.94),(s*.10,-.005,.82),(s*.105,-.018,.64),(s*.105,-.015,.51),
                (s*.11,.012,.39),(s*.11,.009,.25),(s*.11,0,.115)],
               [(.085,.095),(.098,.099),(.078,.083),(.061,.065),(.073,.073),(.056,.057),(.04,.045)],0,
               ['Coxa.'+l,'Coxa.'+l,'Coxa.'+l,{'Coxa.'+l:.45,'Canela.'+l:.55},'Canela.'+l,'Canela.'+l,'Canela.'+l])
        # Pé humano com calcanhar e frente achatada; dedos discretos.
        m.horizontal([(.018,s*.11,-.06,.053,.114),(.061,s*.11,-.065,.055,.118),
                      (.12,s*.11,-.018,.042,.06)],0,'Pe.'+l,8)
        for i in range(4):
            x=s*.11+(i-1.5)*.023
            m.elipsoide((x,-.167,.042),(.012,.021 if i<2 else .017,.021),0,'Pe.'+l,6)
        fino=.82 if feminino else 1.0
        m.tubo([(s*.20,0,1.39),(s*.26,0,1.36),(s*.31,0,1.24),(s*.35,0,1.10),
                (s*.38,-.006,1.01),(s*.405,-.01,.88)],
               [r*fino for r in [.070,.079,.068,.048,.060,.034]],0,
               ['Braco.'+l,'Braco.'+l,'Braco.'+l,{'Braco.'+l:.5,'Antebraco.'+l:.5},'Antebraco.'+l,'Antebraco.'+l])
        m.tubo([(s*.405,-.01,.885),(s*.425,-.014,.818),(s*.44,-.016,.784)],
               [(.034,.029),(.043,.025),(.038,.022)],0,'Mao.'+l,8)
        for i in range(4):
            x=s*(.418+i*.015)
            z=.735+abs(i-1)*.012
            m.tubo([(x,-.017,.80),(x+s*.012,-.021,z)],[.010,.008],0,'Mao.'+l,5)
        m.tubo([(s*.40,-.018,.835),(s*.389,-.042,.801),(s*.396,-.043,.774)],
               [.014,.012,.009],0,'Mao.'+l,6)
    # Cabeça em anéis com mandíbula, maçãs e testa; detalhes integram o mesmo rig.
    m.horizontal([(1.495,0,-.010,.062,.066),(1.535,0,-.017,.091,.080),
                  (1.59,0,-.006,.121,.100),(1.65,0,.004,.128,.111),
                  (1.73,0,.010,.124,.108),(1.79,0,.012,.101,.091),
                  (1.825,0,.014,.055,.054)],0,'Cabeca',12)
    for s in [-1,1]:
        m.elipsoide((s*.126,.006,1.637),(.023,.024,.044),0,'Cabeca',8)
        # Olhos pequenos com branco quente, íris escura e sobrancelhas planas.
        x=s*.052
        z=1.675
        m.face([(x-.026,-.103,z),(x-.018,-.115,z+.011),(x+.018,-.115,z+.011),
                (x+.026,-.103,z),(x+.017,-.115,z-.010),(x-.017,-.115,z-.010)],6,'Cabeca')
        m.face([(x-.009,-.120,z-.010),(x-.010,-.120,z+.010),(x+.009,-.120,z+.010),
                (x+.010,-.120,z-.010)],5,'Cabeca')
        m.face([(x-.030,-.112,1.706),(x-.025,-.112,1.717),
                (x+.025,-.112,1.713),(x+.030,-.112,1.701)],1,'Cabeca')
    m.face([(-.019,-.102,1.67),(.019,-.102,1.67),(.025,-.133,1.613),
            (0,-.162,1.619),(-.025,-.133,1.613)],0,'Cabeca')
    m.face([(-.026,-.105,1.579),(0,-.117,1.576),(.026,-.105,1.579),
            (.020,-.108,1.572),(0,-.118,1.570),(-.020,-.108,1.572)],7,'Cabeca')
    # Cabelo facetado com franja e mechas amplas; nenhuma fibra individual.
    lados=12
    aneis=[]
    for j in range(3):
        anel=[]
        for i in range(lados):
            a=i*math.tau/lados
            frente=max(0,-math.sin(a))
            z=([1.59+frente*.14,1.77,1.855][j])
            r=[1.0,.99,.45][j]
            anel.append((.140*r*math.cos(a),.018+.121*r*math.sin(a),z))
        aneis.append(anel)
    m.aneis(aneis,1,'Cabeca')
    comprimento=1.07 if feminino else 1.50
    for i in range(7):
        a=.05+i*math.pi/6.5
        x=.138*math.cos(a)
        y=.018+.122*math.sin(a)
        largura=.05
        m.face([(x-largura/2,y,1.78),(x+largura/2,y,1.78),
                (x*1.2+largura/2,y+.026,comprimento+.05),
                (x*1.18-largura/3,y+.04,comprimento+(.04 if i%2 else 0))],1,'Cabeca')
    for s in [-1,1]:
        m.face([(s*.12,-.02,1.81),(s*.01,-.11,1.82),(s*.036,-.124,1.73),
                (s*.105,-.082,1.69)],1,'Cabeca')
    # Roupa simples: convenção artística para o jogo, identificada no manifesto.
    m.horizontal([(.94,0,0,quadril+.013,.125),(.86,0,0,quadril+.026,.134),
                  (.70,0,0,quadril+.025,.143)],2,'Quadril',12)
    m.face([(-quadril-.018,-.112,.94),(.17,-.112,.94),(.10,-.153,.69),(-.20,-.127,.72)],3,'Quadril')
    m.face([(-.09,-.147,.90),(.20,-.119,.94),(.21,-.15,.72),(.025,-.159,.65)],2,'Quadril')
    if feminino:
        m.horizontal([(1.235,0,-.008,.187,.124),(1.29,0,-.008,.204,.136),
                      (1.355,0,-.005,.216,.122)],3,'Peito',12)
    for z in [.937,.953]:
        pts=[((quadril+.016)*math.cos(i*math.tau/36),.133*math.sin(i*math.tau/36),z) for i in range(37)]
        m.tubo(pts,[.006]*len(pts),4,'Quadril',5)
    m.elipsoide((-.025,-.144,.942),(.025,.014,.019),4,'Quadril',8)
    for s in [-1,1]:
        m.tubo([(-.025,-.149,.94),(-.025+s*.034,-.158,.88),(-.028+s*.026,-.159,.82)],
               [.006,.005,.004],4,'Quadril',5)
    obj=m.objeto(nome+'_Visual',cena,rig)
    rig['referencia']='art/references/etapa_4/propostas_moradores.png — opção A'
    rig['limite_cultural']='Adaptação artística; roupas não autenticadas como traje histórico. Sem adornos rituais.'
    rig['estado_visual']='Portão B — modelo e animações para aprovação, sem gameplay.'
    return rig,obj


def animar(cena,rig):
    rig.animation_data_create()
    for nome,inicio,fim in [('Parado',1,49),('Andar',61,85),('Trabalhar',101,137)]:
        acao=bpy.data.actions.new(rig.name+'_'+nome)
        rig.animation_data.action=acao
        for frame in range(inicio,fim+1,3):
            t=(frame-inicio)/(fim-inicio)*math.tau
            for b in rig.pose.bones:
                b.rotation_mode='XYZ'
                b.rotation_euler=(0,0,0)
                b.location=(0,0,0)
            if nome=='Parado':
                rig.pose.bones['Peito'].rotation_euler.x=.012*math.sin(t)
                rig.pose.bones['Cabeca'].rotation_euler.z=.026*math.sin(t)
            elif nome=='Andar':
                rig.pose.bones['Raiz'].location.z=.014*(1-math.cos(2*t))
                for s,l in [(1,'E'),(-1,'D')]:
                    fase=math.sin(t)*s
                    rig.pose.bones['Coxa.'+l].rotation_euler.x=.30*fase
                    rig.pose.bones['Canela.'+l].rotation_euler.x=max(0,-fase)*.42
                    rig.pose.bones['Pe.'+l].rotation_euler.x=-.10*fase
                    rig.pose.bones['Braco.'+l].rotation_euler.x=-.23*fase
                    rig.pose.bones['Antebraco.'+l].rotation_euler.x=.08
            else:
                rig.pose.bones['Coluna'].rotation_euler.x=.10+.05*math.sin(t)
                for l in ['E','D']:
                    rig.pose.bones['Braco.'+l].rotation_euler.x=.65+.18*math.sin(t)
                    rig.pose.bones['Antebraco.'+l].rotation_euler.x=.35-.18*math.sin(t)
            for b in rig.pose.bones:
                b.keyframe_insert(data_path='rotation_euler',frame=frame,group=b.name)
                if b.name=='Raiz':
                    b.keyframe_insert(data_path='location',frame=frame,group=b.name)
        rig.animation_data.action=None
        track=rig.animation_data.nla_tracks.new()
        track.name=nome
        strip=track.strips.new(nome,inicio,acao)
        strip.extrapolation='NOTHING'


def produzir():
    anterior=bpy.data.scenes.get(NOME_CENA)
    if anterior:
        for obj in list(anterior.objects):
            bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.scenes.remove(anterior)
    cena=bpy.data.scenes.new(NOME_CENA)
    bpy.context.window.scene=cena
    cena.unit_settings.system='METRIC'
    cena.render.fps=24
    cena.frame_end=137
    pares=[]
    for nome,feminino in [('morador_01',False),('moradora_01',True)]:
        rig,obj=criar_corpo(cena,nome,feminino)
        animar(cena,rig)
        pares.append((rig,obj))
    cena.frame_set(1)
    for rig,obj in pares:
        with bpy.context.temp_override(scene=cena,view_layer=cena.view_layers[0]):
            for o in list(bpy.context.selected_objects):
                o.select_set(False)
            rig.select_set(True)
            obj.select_set(True)
            bpy.context.view_layer.objects.active=rig
            bpy.ops.export_scene.gltf(filepath=str(RAIZ/'assets/models'/f'{rig.name}.glb'),
                export_format='GLB',use_selection=True,use_active_scene=True,
                export_cameras=False,export_lights=False,export_animation_mode='NLA_TRACKS',
                export_frame_range=False,export_force_sampling=True)
        print(rig.name,len(obj.data.vertices),'vertices;',len(obj.data.polygons),'faces;',len(rig.data.bones),'ossos')
    # Fonte independente, com os dois modelos afastados para inspeção no Blender.
    pares[0][0].location.x=-.55
    pares[1][0].location.x=.55
    mundo=bpy.data.worlds.new('Moradores_CeuInspecao')
    mundo.use_nodes=True
    fundo=next(n for n in mundo.node_tree.nodes if n.type=='BACKGROUND')
    fundo.inputs[0].default_value=(.3,.32,.27,1)
    fundo.inputs[1].default_value=.7
    cena.world=mundo
    luz=bpy.data.lights.new('Moradores_Sol','SUN')
    luz.energy=3
    sol=bpy.data.objects.new('Moradores_Sol',luz)
    cena.collection.objects.link(sol)
    sol.rotation_euler=(math.radians(22),math.radians(-30),math.radians(-25))
    cd=bpy.data.cameras.new('Moradores_Camera')
    camera=bpy.data.objects.new('Moradores_Camera',cd)
    cena.collection.objects.link(camera)
    camera.location=(2.9,-5.8,2.6)
    camera.rotation_euler=(Vector((0,0,.95))-camera.location).to_track_quat('-Z','Y').to_euler()
    cd.lens=54
    cena.camera=camera
    cena.render.resolution_x=1280
    cena.render.resolution_y=720
    cena.render.resolution_percentage=100
    bpy.data.libraries.write(str(RAIZ/'art/blender/moradores_1500.blend'),{cena},fake_user=True,compress=True)
    print('Fonte e dois GLBs gravados; demais cenas preservadas.')


produzir()
