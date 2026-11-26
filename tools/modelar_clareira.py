"""Arte original da ETAPA 1. Executar no Blender pelo MCP; não baixa assets."""
import bpy
import math
import random
from pathlib import Path
from mathutils import Vector

RAIZ = Path(r'C:\Users\PC\Documents\ChatGPT\1500')
RNG = random.Random(1500)
BUFFER = {}


def linear(v):
    return v / 12.92 if v < 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def cor(hexadecimal):
    h = hexadecimal.lstrip('#')
    return tuple(linear(int(h[i:i+2], 16) / 255) for i in (0, 2, 4)) + (1,)


def material(nome, hexa, rugosidade=0.9, vertices=False):
    mat = bpy.data.materials.new(nome)
    mat.use_nodes = True
    mat.diffuse_color = cor(hexa)
    node = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value = cor(hexa)
    node.inputs['Roughness'].default_value = rugosidade
    if vertices:
        attr = mat.node_tree.nodes.new('ShaderNodeVertexColor')
        attr.layer_name = 'Color'
        mat.node_tree.links.new(attr.outputs['Color'], node.inputs['Base Color'])
    BUFFER[nome] = {'v': [], 'f': [], 'c': [], 'mat': mat}
    return nome


def poligono(nome, pontos, tint=None):
    b = BUFFER[nome]
    inicio = len(b['v'])
    b['v'].extend(tuple(p) for p in pontos)
    b['f'].append(tuple(range(inicio, inicio + len(pontos))))
    b['c'].extend([tint or (1, 1, 1, 1)] * len(pontos))


def tubo(nome, pontos, raios, lados=7):
    pontos = [Vector(p) for p in pontos]
    aneis = []
    for j, (p, raio) in enumerate(zip(pontos, raios)):
        eixo = (pontos[min(j+1, len(pontos)-1)] - pontos[max(0, j-1)]).normalized()
        lateral = eixo.cross(Vector((0, 1, 0)))
        if lateral.length < .01:
            lateral = eixo.cross(Vector((1, 0, 0)))
        lateral.normalize()
        outro = eixo.cross(lateral).normalized()
        aneis.append([p + raio * (math.cos(i*math.tau/lados)*lateral + math.sin(i*math.tau/lados)*outro) for i in range(lados)])
    for j in range(len(aneis)-1):
        for i in range(lados):
            poligono(nome, [aneis[j][i], aneis[j][(i+1)%lados], aneis[j+1][(i+1)%lados], aneis[j+1][i]])
    poligono(nome, list(reversed(aneis[0])))
    poligono(nome, aneis[-1])


def centro_rio(y):
    return 17 + 3.2 * math.sin(y*.075) + 1.3*math.sin(y*.17)


def largura_rio(y):
    return 3.0 + .45*math.sin(y*.12)


def altura(x, y):
    r = math.hypot(x, y)
    ondulacao = .30*math.sin(x*.16)*math.cos(y*.13) + .14*math.sin(y*.39+x*.17)
    h = .06 + ondulacao * min(1, r/14) + max(0, r-20)*.035
    h += 1.8*math.exp(-((x+22)**2+(y-22)**2)/300)
    d = abs(x-centro_rio(y))
    canal = max(0, min(1, (largura_rio(y)+2.4-d)/2.4))
    canal = canal*canal*(3-2*canal)
    return h*(1-canal) - 1.25*canal


def terreno():
    b = BUFFER['Solo_TerraViva']
    n, passo = 200, 1.0
    cores = [cor(c) for c in ('905840', 'a86d48', 'b98150', '778849', '537649', '416b47')]
    for j in range(n+1):
        y = (j-n/2)*passo
        for i in range(n+1):
            x = (i-n/2)*passo
            z = altura(x, y)
            b['v'].append((x, y, z))
            r = math.hypot(x*.98, y)
            d = abs(x-centro_rio(y))
            t = max(0, min(1, (r-8 + math.sin(x*.42)*.8 + math.cos(y*.32)*.9)/7))
            if d < largura_rio(y)+2.6:
                t *= max(0, min(1, (d-largura_rio(y)-.1)/2))
            solo = cores[1 if RNG.random() < .65 else 2]
            verde = cores[3 if RNG.random() < .45 else 4]
            v = RNG.uniform(.91, 1.07)
            b['c'].append(tuple((solo[k]*(1-t)+verde[k]*t)*v for k in range(3))+(1,))
    for j in range(n):
        for i in range(n):
            a = j*(n+1)+i
            if (i+j)%2:
                b['f'].extend([(a,a+1,a+n+1),(a+1,a+n+2,a+n+1)])
            else:
                b['f'].extend([(a,a+1,a+n+2),(a,a+n+2,a+n+1)])


def copa(centro, escala, mat):
    cx,cy,cz = centro
    rx,ry,rz = escala
    lados = 9
    aneis = []
    fase = RNG.uniform(0, math.tau)
    irregular = [RNG.uniform(.8, 1.12) for _ in range(lados)]
    for j,(z,r) in enumerate(((-.65,.30),(-.40,.90),(.10,1.0),(.53,.76),(.85,.20))):
        aneis.append([(cx+rx*r*irregular[i]*math.cos(i*math.tau/lados+fase+j*.08), cy+ry*r*irregular[i]*math.sin(i*math.tau/lados+fase+j*.08), cz+rz*(z+RNG.uniform(-.06,.06))) for i in range(lados)])
    for j in range(4):
        for i in range(lados):
            a,b,c,d = aneis[j][i], aneis[j][(i+1)%lados], aneis[j+1][(i+1)%lados], aneis[j+1][i]
            if RNG.random() < .45:
                poligono(mat,[a,b,c])
                poligono(mat,[a,c,d])
            else:
                poligono(mat,[a,b,c,d])
    poligono(mat,list(reversed(aneis[0])))
    poligono(mat,aneis[-1])


def folha(base, ang, comprimento, largura, mat, subida=.2):
    base = Vector(base)
    frente = Vector((math.cos(ang), math.sin(ang), 0))
    lado = Vector((-math.sin(ang), math.cos(ang), 0))
    linhas=[]
    for t in (0,.24,.50,.77,1):
        centro = base + frente*comprimento*t + Vector((0,0,comprimento*(subida*t + .2*math.sin(math.pi*t))))
        w = largura * math.sin(math.pi*t)**.72
        linhas.append((centro-lado*w-Vector((0,0,w*.22)), centro, centro+lado*w-Vector((0,0,w*.22))))
    for i in range(4):
        for j in range(2):
            poligono(mat,[linhas[i][j],linhas[i+1][j],linhas[i+1][j+1],linhas[i][j+1]])


def samambaia(x,y,tamanho=1):
    z=altura(x,y)+.035
    for i in range(8):
        ang=i*math.tau/8+RNG.uniform(-.2,.2)
        frente=Vector((math.cos(ang),math.sin(ang),0))
        base=Vector((x,y,z))
        for j in range(1,9):
            t=j/9
            p=base+frente*(t*tamanho)+Vector((0,0,tamanho*(.28*math.sin(t*math.pi)+.1)))
            for sinal in (-1,1):
                folha(p,ang+sinal*1.04,tamanho*.32*(1-t)+.05,tamanho*.055,'Samambaias',subida=-.10)


def folhagem_larga(x,y,s=1):
    z=altura(x,y)
    for i in range(6):
        a=i*math.tau/6+RNG.uniform(-.22,.22)
        folha((x,y,z+.13*s),a,RNG.uniform(1.2,2.1)*s,.28*s,'Folhas_Largas',subida=RNG.uniform(.08,.3))


def bromelia(x,y,s=1):
    z=altura(x,y)+.03
    for i in range(8):
        folha((x,y,z),i*math.tau/8+.2,RNG.uniform(.55,.8)*s,.095*s,'Bromelias',subida=.48)
    for i in range(5):
        folha((x,y,z+.06),i*math.tau/5,.35*s,.1*s,'Flores_Coral',subida=1.1)
    tubo('Flores_Ouro',[(x,y,z+.1),(x,y,z+.65*s)],[.035*s,.018*s],5)


def arvore(x,y,h,raio,tinta=None):
    z=altura(x,y)
    torcao=RNG.uniform(-.7,.7)
    tubo('Troncos',[(x,y,z),(x+.15,y,z+h*.28),(x+torcao,y+.2,z+h*.57),(x+.3,y+.35,z+h*.92)],[raio*1.45,raio,raio*.73,raio*.35],8)
    for i in range(6):
        a=i*math.tau/6+RNG.uniform(-.2,.2)
        dx,dy=math.cos(a),math.sin(a)
        poligono('Raizes',[(x-dy*.16,y+dx*.16,z+.05),(x+dx*raio*3.5,y+dy*raio*3.5,altura(x+dx*raio*3.5,y+dy*raio*3.5)+.04),(x+dx*raio*.45,y+dy*raio*.45,z+raio*2.4)])
        poligono('Raizes',[(x+dy*.16,y-dx*.16,z+.05),(x+dx*raio*.45,y+dy*raio*.45,z+raio*2.4),(x+dx*raio*3.5,y+dy*raio*3.5,altura(x+dx*raio*3.5,y+dy*raio*3.5)+.04)])
    cor_copa=tinta or RNG.choice(['Copas_Jade','Copas_Esmeralda','Copas_Lima'])
    for i in range(4):
        ang=i*math.tau/4+RNG.random()
        d=RNG.uniform(1.6,2.7)
        cx=x+math.cos(ang)*d
        cy=y+math.sin(ang)*d
        cz=z+h*RNG.uniform(.77,.97)
        tubo('Troncos',[(x+torcao,y+.2,z+h*.56),(cx*.5+x*.5,cy*.5+y*.5,cz-1),(cx,cy,cz)],[raio*.48,raio*.24,.1],6)
        copa((cx,cy,cz),(RNG.uniform(2.8,4.2),RNG.uniform(2.6,3.6),RNG.uniform(1.4,2.2)),cor_copa)
    copa((x+.3,y+.35,z+h+.5),(3.7,3.2,1.8),cor_copa)
    if RNG.random()<.22:
        for _ in range(4):
            cx=x+RNG.uniform(-3,3)
            cy=y+RNG.uniform(-3,3)
            copa((cx,cy,z+h+RNG.uniform(-.7,.4)),(.55,.6,.3),'Flores_Ouro')


def palmeira(x,y,h):
    z=altura(x,y)
    topo=Vector((x+.5,y+.2,z+h))
    tubo('Palmeiras_Tronco',[(x,y,z),(x+.1,y+.2,z+h*.4),topo],[.22,.17,.10],8)
    for i in range(10):
        ang=i*math.tau/10+.15
        frente=Vector((math.cos(ang),math.sin(ang),0))
        lateral=Vector((-math.sin(ang),math.cos(ang),0))
        comp=RNG.uniform(2.9,4.0)
        pontos=[]
        for j in range(12):
            t=j/11
            p=topo+frente*comp*t+Vector((0,0,comp*(.4*math.sin(math.pi*t)-.2*t)))
            pontos.append(p)
            if j in (0,11):
                continue
            for s in (-1,1):
                q=p+frente*.25+lateral*s*(math.sin(math.pi*t)**.55)*.88+Vector((0,0,-.3))
                poligono('Palmeiras_Folhas',[p-frente*.13,q,p+frente*.17])
        tubo('Palmeiras_Folhas',pontos,[.025*(1-j/14) for j in range(12)],4)


def pedra(x,y,s,mat='Pedras_Azuladas',z=None):
    z=altura(x,y) if z is None else z
    copa((x,y,z+s*.25),(s,s*RNG.uniform(.65,1.1),s*.85),mat)


def capim(x,y,s):
    z=altura(x,y)+.02
    for i in range(5):
        a=RNG.uniform(0,math.tau)
        b=Vector((x+RNG.uniform(-.16,.16),y+RNG.uniform(-.16,.16),z))
        lado=Vector((-math.sin(a),math.cos(a),0))*.04*s
        ponta=b+Vector((math.cos(a)*.24*s,math.sin(a)*.24*s,RNG.uniform(.4,.85)*s))
        poligono('Capim',[b-lado,ponta,b+lado])


def fogueira():
    z=altura(0,0)
    for i in range(13):
        a=i*math.tau/13
        pedra(math.cos(a)*1.18,math.sin(a)*1.18,.32,'Pedras_Fogueira',z-.02)
    for i in range(7):
        a=i*2.399
        d=Vector((math.cos(a),math.sin(a),0))
        inicio=d*.88+Vector((0,0,z+.20+i*.028))
        fim=-d*.66+Vector((0,0,z+.34+i*.042))
        tubo('Lenha',[inicio,fim],[.16,.11],9)
        tubo('Lenha_Miolo',[inicio-d*.008,inicio+d*.025],[.119,.116],9)
    for i in range(20):
        a=RNG.uniform(0,math.tau)
        r=RNG.uniform(.1,.7)
        pedra(math.cos(a)*r,math.sin(a)*r,.10,'Brasas',z+.12)
    for i in range(7):
        a=i*math.tau/7
        poligono('Solo_Cinzas',[(0,0,z+.014),(math.cos(a)*1.05,math.sin(a)*1.05,z+.016),(math.cos(a+math.tau/7)*1.05,math.sin(a+math.tau/7)*1.05,z+.016)])


def finalizar():
    objetos=[]
    for nome,b in BUFFER.items():
        if not b['v']:
            continue
        malha=bpy.data.meshes.new(nome)
        malha.from_pydata(b['v'],[],b['f'])
        malha.materials.append(b['mat'])
        if nome=='Solo_TerraViva':
            attr=malha.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
            attr.data.foreach_set('color',[v for rgba in b['c'] for v in rgba])
            for poly in malha.polygons:
                poly.use_smooth=True
        obj=bpy.data.objects.new(nome,malha)
        CENA.collection.objects.link(obj)
        objetos.append(obj)
    CENA.unit_settings.system='METRIC'
    CENA.unit_settings.scale_length=1.0
    CENA['etapa']='1 — Portão B: arte aguardando avaliação no Godot'
    CENA['autoria']='Geometria e materiais originais produzidos para 1500; sem assets externos.'
    CENA['semente']=1500
    CENA.world=bpy.data.worlds.new('Ceu_Inspecao')
    CENA.world.use_nodes=True
    CENA.world.node_tree.nodes.get('Background').inputs[0].default_value=(.16,.24,.24,1)
    CENA.world.node_tree.nodes.get('Background').inputs[1].default_value=.45
    luz=bpy.data.lights.new('Sol_Inspecao','SUN')
    luz.energy=3.0
    luz.angle=math.radians(12)
    sol=bpy.data.objects.new('Sol_Inspecao',luz)
    CENA.collection.objects.link(sol)
    sol.rotation_euler=(math.radians(28),math.radians(-22),math.radians(-35))
    cam_data=bpy.data.cameras.new('Camera_Inspecao')
    cam=bpy.data.objects.new('Camera_Inspecao',cam_data)
    CENA.collection.objects.link(cam)
    cam.location=(31,-39,34)
    cam.rotation_euler=(Vector((0,3,1))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam_data.lens=43
    CENA.camera=cam
    CENA.render.resolution_x=1280
    CENA.render.resolution_y=720
    CENA.render.resolution_percentage=100
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    for obj in objetos:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=objetos[0]
    bpy.ops.export_scene.gltf(filepath=str(RAIZ/'assets/models/clareira_1500.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_yup=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(RAIZ/'art/blender/clareira_1500.blend'))
    print('ARTE_1500:',len(objetos),'malhas;',sum(len(o.data.polygons) for o in objetos),'faces')
    print('GLB:', (RAIZ/'assets/models/clareira_1500.glb').stat().st_size)


for anterior in list(bpy.data.scenes):
    if anterior.name.startswith('1500_Clareira'):
        for objeto in list(anterior.objects):
            dados=objeto.data
            bpy.data.objects.remove(objeto,do_unlink=True)
            if dados and dados.users==0 and isinstance(dados,bpy.types.Mesh):
                bpy.data.meshes.remove(dados)
        bpy.data.scenes.remove(anterior)
CENA=bpy.data.scenes.new('1500_Clareira')
bpy.context.window.scene=CENA
material('Solo_TerraViva','ffffff',vertices=True)
material('Troncos','644238')
material('Raizes','785142')
material('Copas_Jade','286e58')
material('Copas_Esmeralda','3d8c53')
material('Copas_Lima','749b4c')
material('Copas_Floridas','daa62f')
material('Folhas_Largas','279469',.68)
material('Samambaias','68a94d')
material('Bromelias','568548',.72)
material('Flores_Coral','e35b53',.65)
material('Flores_Ouro','efb333',.62)
material('Palmeiras_Tronco','8c7155')
material('Palmeiras_Folhas','4b985a')
material('Capim','86aa50')
material('Pedras_Azuladas','697e87',.94)
material('Pedras_Fogueira','72767f')
material('Lenha','483535')
material('Lenha_Miolo','b17c50')
material('Brasas','ed692c',.86)
material('Solo_Cinzas','55443c')
terreno()

# Mata em camadas, com corredor de leitura para a câmera de gerenciamento.
posicoes=[]
tentativas=0
while len(posicoes)<100 and tentativas<5000:
    tentativas+=1
    x,y=RNG.uniform(-48,48),RNG.uniform(-48,48)
    r=math.hypot(x,y)
    if r<18 or r>58 or abs(x-centro_rio(y))<largura_rio(y)+3.7:
        continue
    ang=math.atan2(y,x)
    frente=abs(math.atan2(math.sin(ang+.92),math.cos(ang+.92)))<.86
    if frente and r<39:
        continue
    if any(math.hypot(x-a,y-b)<5 for a,b in posicoes):
        continue
    posicoes.append((x,y))
for x,y in posicoes:
    arvore(x,y,RNG.uniform(10,17),RNG.uniform(.35,.65))
for _ in range(52):
    x,y=RNG.uniform(-78,78),RNG.uniform(44,88)
    if abs(x-centro_rio(y))>largura_rio(y)+4:
        arvore(x,y,RNG.uniform(12,19),RNG.uniform(.35,.65))
arvore(-12,17,11,.45,'Copas_Floridas')
for x,y,h in [(-12,11,9),(-17,-2,10),(-23,-14,11),(12,22,10),(26,5,12),(30,-13,9),(-31,22,13)]:
    palmeira(x,y,h)
for _ in range(3100):
    x,y=RNG.uniform(-43,43),RNG.uniform(-43,43)
    r=math.hypot(x,y)
    d=abs(x-centro_rio(y))
    if r<8 or d<largura_rio(y)+1.7:
        continue
    capim(x,y,RNG.uniform(.8,1.7))
for _ in range(270):
    x,y=RNG.uniform(-34,34),RNG.uniform(-34,34)
    if math.hypot(x,y)<10 or abs(x-centro_rio(y))<largura_rio(y)+2:
        continue
    if RNG.random()<.52:
        samambaia(x,y,RNG.uniform(.8,1.5))
    else:
        folhagem_larga(x,y,RNG.uniform(.6,1.15))
for x,y,s in [(-8,-6,1.3),(-11,-9,1),(-9,7,1.2),(8,5,.9),(10,-7,1.1),(-14,3,1),(24,-13,1.3),(8,-12,1.1)]:
    bromelia(x,y,s)
# Maciços de folhas, em vez de distribuir toda a vegetação uniformemente.
for centro_x,centro_y in [(-11,-9),(-13,5),(-7,14),(7,13),(9,-10),(24,-5),(25,13),(-19,-16),(-16,18)]:
    for _ in range(9):
        x,y=centro_x+RNG.uniform(-2,2),centro_y+RNG.uniform(-2,2)
        folhagem_larga(x,y,RNG.uniform(.75,1.4))
        if RNG.random()<.4:
            bromelia(x,y,RNG.uniform(1.1,1.5))
for _ in range(45):
    y=RNG.uniform(-45,45)
    x=centro_rio(y)+RNG.choice([-1,1])*RNG.uniform(2.3,4.5)
    pedra(x,y,RNG.uniform(.3,1.15))
for x,y,s in [(-13,8,1.7),(-17,4,.8),(-9,12,.9),(11,9,1.3),(24,-10,1.5),(-12,-10,1)]:
    pedra(x,y,s)
fogueira()
finalizar()
