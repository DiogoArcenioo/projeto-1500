"""Produz os assets A1/P1 aprovados. Usa a mesma geometria de madeira e folhas da oca."""
from pathlib import Path
import bpy
import math
import random
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[1]
base = RAIZ / 'tools/modelar_oca_nivel_1.py'
exec(compile(base.read_text(encoding='utf-8').rsplit('\nproduzir()', 1)[0], str(base), 'exec'))
ALEATORIO = random.Random(150008)

def iniciar(nome):
    global CENA, RAIZ_OBJ, DADOS
    CENA = bpy.data.scenes.new(nome)
    bpy.context.window.scene = CENA
    RAIZ_OBJ = bpy.data.objects.new(nome, None)
    CENA.collection.objects.link(RAIZ_OBJ)
    DADOS = {}
    for nome_mat, tinta in [
        ('Madeira','955d2f'),('MadeiraClara','b57b3a'),('CorteMadeira','ce9c60'),
        ('Fibras','d7b76c'),('FibraMel','b98b45'),('FibraClara','e1bd7d'),
        ('Forro','304326'),('FolhaJade','3f722f'),('FolhaOliva','728932'),
        ('FolhaVerde','5c8734'),('FolhaLima','8ca03b'),('FolhaMusgo','57712d'),
        ('FolhaSeca','b9a04b'),('Nervuras','8d9c3c'),('Haste','5a7935'),
        ('Terra','9b5631'),('TerraClara','9e5934'),('TerraEscura','97532f'),
        ('Pedra','7a8275'),('PedraClara','949a86'),('MilhoOuro','d8a339'),
        ('MilhoAmarelo','e6b84c'),('MilhoSombra','be8b2e')]:
        material(nome_mat, tinta)
    CENA.unit_settings.system = 'METRIC'
    RAIZ_OBJ['referencia'] = 'art/references/etapa_8/propostas_agricultura_pesca.png'
    RAIZ_OBJ['estado'] = 'Modelo para avaliação no Godot'
    RAIZ_OBJ['autoria'] = 'Geometria e materiais produzidos para 1500'

def fechar(arquivo, fonte=True):
    objetos = montar_malhas(CENA, RAIZ_OBJ)
    for obj in objetos:
        # Materiais compartilhados preservam a paleta dos assets aprovados.
        obj.data.update()
    bpy.ops.object.select_all(action='DESELECT')
    RAIZ_OBJ.select_set(True)
    for obj in objetos:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = RAIZ_OBJ
    if arquivo.startswith(('mandioca_','milho_')):
        # A cor por vértice permite desenhar cada planta com uma única superfície.
        for obj in objetos:
            cor_planta=obj.data.materials[0].diffuse_color
            atributo=obj.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
            atributo.data.foreach_set('color',list(cor_planta)*len(obj.data.vertices))
        RAIZ_OBJ.select_set(False)
        bpy.context.view_layer.objects.active=objetos[0]
        bpy.ops.object.join()
        planta=bpy.context.object
        planta.name=arquivo
        mat=bpy.data.materials.new(arquivo+'_cor')
        mat.use_nodes=True
        bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        bs.inputs['Roughness'].default_value=.85
        vertice=mat.node_tree.nodes.new('ShaderNodeVertexColor')
        vertice.layer_name='Color'
        mat.node_tree.links.new(vertice.outputs['Color'],bs.inputs['Base Color'])
        planta.data.materials.clear()
        planta.data.materials.append(mat)
        objetos=[planta]
        RAIZ_OBJ.select_set(True)
    pasta = RAIZ / 'assets/models'
    pasta.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(pasta / (arquivo+'.glb')),
        use_selection=True, use_active_scene=True, export_cameras=False, export_lights=False)
    if fonte:
        mundo = bpy.data.worlds.new(arquivo+'_ceu')
        mundo.use_nodes = True
        fundo = next(n for n in mundo.node_tree.nodes if n.type=='BACKGROUND')
        fundo.inputs[0].default_value = (.26,.34,.28,1)
        fundo.inputs[1].default_value = .7
        CENA.world = mundo
        dados_sol = bpy.data.lights.new('Sol de inspeção', 'SUN')
        dados_sol.energy = 3
        dados_sol.angle = math.radians(8)
        sol = bpy.data.objects.new('Sol de inspeção', dados_sol)
        CENA.collection.objects.link(sol)
        sol.rotation_euler = (.45,-.35,-.6)
        dados_camera = bpy.data.cameras.new('Câmera de inspeção')
        camera = bpy.data.objects.new('Câmera de inspeção',dados_camera)
        CENA.collection.objects.link(camera)
        camera.location = (8,-10,8)
        camera.rotation_euler = (Vector((0,0,.8))-camera.location).to_track_quat('-Z','Y').to_euler()
        dados_camera.type='ORTHO'
        dados_camera.ortho_scale = 8
        CENA.camera = camera
        CENA.render.resolution_x=1200
        CENA.render.resolution_y=900
        CENA.render.resolution_percentage=100
        bpy.data.libraries.write(str(RAIZ/'art/blender'/(arquivo+'.blend')),
            {CENA},fake_user=True,compress=True)
    print(arquivo, len(objetos), 'malhas', sum(len(o.data.polygons) for o in objetos), 'faces')
    return CENA

def palha_cor(i):
    return ['FolhaVerde','FolhaOliva','FolhaJade','FolhaLima','FolhaMusgo'][i%5]

def abrigo(cx,cy,largura=3.15,profundidade=1.9):
    # Frente em -Y, como a oca. Madeira, fibras e folhagem têm a mesma escala.
    def z(y):
        return 2.25+.31*(y-cy)
    for x in [cx-largura*.43,cx+largura*.43]:
        for y in [cy-profundidade*.39,cy+profundidade*.39]:
            viga((x,y,0),(x+.02,y,z(y)+.03),.085)
            amarracao((x,y,z(y)-.03),(0,0,1),.095,4,.16)
    for y in [cy-profundidade*.40,cy+profundidade*.40]:
        viga((cx-largura*.53,y,z(y)),(cx+largura*.53,y,z(y)),.078)
    for x in [cx-largura*.43,cx,cx+largura*.43]:
        viga((x,cy-profundidade*.57,z(cy-profundidade*.57)),(x,cy+profundidade*.57,z(cy+profundidade*.57)),.055)
    face('Forro',[(cx-largura*.57,cy-profundidade*.59,z(cy-profundidade*.59)),
        (cx+largura*.57,cy-profundidade*.59,z(cy-profundidade*.59)),
        (cx+largura*.57,cy+profundidade*.59,z(cy+profundidade*.59)),
        (cx-largura*.57,cy+profundidade*.59,z(cy+profundidade*.59))],(0,-.31,1))
    direcao = Vector((0,-1,-.31)).normalized()
    lateral = Vector((1,0,0))
    normal = lateral.cross(direcao).normalized()
    if normal.z<0:
        normal=-normal
    for j in range(4):
        y=cy-profundidade*.30+j*profundidade*.26
        for i in range(10):
            x=cx-largura*.52+i*largura*.115+(j%2)*.06+ALEATORIO.uniform(-.025,.025)
            folha((x,y,z(y)+.025+j*.009),direcao,lateral,normal,
                .93+ALEATORIO.uniform(-.09,.09),.48,palha_cor(i+3*j),ponta_dourada=(i+4*j)%19==0)

def cesto(x,y,z,raio=.29,h=.42):
    # Tiras entrelaçadas sobre uma trama fechada, com interior e borda visíveis.
    def p(a,t,offset=0):
        r=raio*(.72+.28*t)+offset
        return Vector((x+r*math.cos(a),y+r*math.sin(a),z+h*t))
    n=32
    for j in range(12):
        for i in range(n):
            a=i*math.tau/n
            b=(i+1)*math.tau/n
            t0=j/12
            t1=(j+1)/12
            mat=['Fibras','FibraMel','FibraClara'][(i+j)%3]
            face(mat,[p(a,t0),p(b,t0),p(b,t1),p(a,t1)])
    for i in range(n):
        a=i*math.tau/n
        for j in range(12):
            t=j/12
            s=(j+1)/12
            offset=.004 if j%2 else .012
            face('FibraClara' if i%3 else 'FibraMel',
                [p(a-.018,t,offset),p(a+.018,t,offset),p(a+.018,s,offset),p(a-.018,s,offset)])
    for j in range(12):
        t=(j+.5)/12
        pts=[p(k*math.tau/64,t,.007+.005*math.sin(k*math.pi)) for k in range(65)]
        tubo('FibraMel' if j%3==0 else 'Fibras',pts,[.008]*len(pts),4)
    pts=[p(i*math.tau/64,1,.005) for i in range(65)]
    tubo('Fibras',pts,[.023]*len(pts),6)
    face('FibraMel',[p(i*math.tau/n,0) for i in range(n)],(0,0,1))

def rede(cx,cy):
    viga((cx-1.08,cy,.05),(cx-1.08,cy,1.78),.055)
    viga((cx+1.08,cy,.05),(cx+1.08,cy,1.78),.055)
    viga((cx-1.20,cy,1.65),(cx+1.20,cy,1.65),.05)
    def p(u,v):
        return Vector((cx+(u-.5)*2.05,cy-.13*math.sin(math.pi*u)*v,
            1.61-v*(.77+.27*math.sin(math.pi*u))))
    # Duas famílias diagonais dão à rede malhas em losango.
    for sentido in [-1,1]:
        for indice in range(-12,25):
            pts=[]
            for j in range(25):
                v=j/24
                u=indice/12+sentido*v*.45
                if 0<=u<=1:
                    pts.append(p(u,v))
            if len(pts)>1:
                tubo('Fibras',pts,[.009]*len(pts),4)
    for u in [0,1]:
        pts=[p(u,i/20) for i in range(21)]
        tubo('FibraMel',pts,[.015]*len(pts),5)
    for v in [0,1]:
        pts=[p(i/40,v) for i in range(41)]
        tubo('Fibras',pts,[.018]*len(pts),5)
    for x in [cx-1.08,cx+1.08]:
        amarracao((x,cy,1.66),(1,0,0),.058,4,.12)

def armadilha(x,y,z):
    # Cilindro horizontal com boca aberta e funil interno em fibras.
    def p(a,t,r=.24):
        return Vector((x+(t-.5)*1.10,y+r*math.cos(a),z+r*math.sin(a)))
    for j in range(9):
        pts=[p(i*math.tau/32,j/8,.24-.025*abs(j/8-.5)) for i in range(33)]
        tubo('FibraMel' if j%3==0 else 'Fibras',pts,[.012]*len(pts),5)
    for i in range(18):
        pts=[p(i*math.tau/18,j/12,.24-.025*abs(j/12-.5)) for j in range(13)]
        tubo('Fibras',pts,[.011]*len(pts),5)
    for i in range(12):
        a=i*math.tau/12
        pts=[p(a,0,.225),p(a,.14,.14),p(a,.29,.065)]
        tubo('FibraMel',pts,[.008]*3,4)
    pts=[p(i*math.tau/32,.29,.065) for i in range(33)]
    tubo('Fibras',pts,[.01]*len(pts),5)

def pedra(x,y,z,escala=(.7,.5,.16)):
    n=7
    vs=[]
    for altura,raio in [(0,.80),(.45,1),(.88,.72),(1,.46)]:
        for i in range(n):
            a=i*math.tau/n
            vs.append((x+escala[0]*raio*math.cos(a),y+escala[1]*raio*math.sin(a),z+altura*escala[2]))
    for j in range(3):
        for i in range(n):
            face('PedraClara' if (i+j)%3==0 else 'Pedra',[vs[j*n+i],vs[j*n+(i+1)%n],vs[(j+1)*n+(i+1)%n],vs[(j+1)*n+i]])
    face('PedraClara',vs[-n:],(0,0,1))

def lamina(base,angulo,comprimento,largura,subida,mat):
    # Limbo dobrado: duas faces iluminam de modo diferente como nas folhas da oca.
    base=Vector(base)
    d=Vector((math.cos(angulo),math.sin(angulo),0))
    s=Vector((-d.y,d.x,0))
    rows=[]
    for t in [0,.18,.43,.70,1]:
        centro=base+d*comprimento*t+Vector((0,0,subida*math.sin(t*math.pi*.75)-.12*t*t))
        w=largura*math.sin(math.pi*t)**.7
        rows.append((centro-s*w,centro+Vector((0,0,.018)),centro+s*w))
    for j in range(4):
        for i in range(2):
            face(mat,[rows[j][i],rows[j+1][i],rows[j+1][i+1],rows[j][i+1]],(0,0,1))
    for j in range(4):
        tubo('Nervuras',[rows[j][1],rows[j+1][1]],[.003,.002],4)

def mandioca(x,y,escala=1):
    h=1.04*escala
    base=Vector((x,y,0))
    tubo('Haste',[base,base+Vector((.018,0,h*.55)),base+Vector((0,.02,h))],[.018*escala,.014*escala,.007*escala],7)
    for j in range(6):
        a=j*2.4+.3
        origem=base+Vector((0,0,h*(.46+.082*j)))
        centro=origem+Vector((.22*escala*math.cos(a),.22*escala*math.sin(a),.12*escala))
        tubo('Haste',[origem,centro],[.007*escala,.003*escala],5)
        for k in range(7):
            b=a+(k-3)*.47
            tamanho=(.32+.12*math.cos((k-3)*.44))*escala
            lamina(centro,b,tamanho,.046*escala,.065*escala,palha_cor(k+j))

def espiga(base):
    base=Vector(base)
    n=9
    rows=[]
    for j in range(8):
        t=j/7
        r=.065*math.sin(math.pi*t)**.6+.008
        rows.append([base+Vector((r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),.30*t)) for i in range(n)])
    for j in range(7):
        for i in range(n):
            face(['MilhoOuro','MilhoAmarelo','MilhoSombra'][(i+j)%3],
                [rows[j][i],rows[j][(i+1)%n],rows[j+1][(i+1)%n],rows[j+1][i]])
    for a in [0,math.pi*.8]:
        lamina(base-Vector((0,0,.02)),a,.15,.045,.23,'FolhaOliva')

def milho(x,y,escala=1,maduro=True):
    h=1.74*escala
    tubo('Haste',[(x,y,0),(x+.02,y,h*.5),(x,y,h)],[.025*escala,.020*escala,.008*escala],7)
    for i in range(7):
        z=h*(.20+i*.09)
        a=i*2.39
        lamina((x,y,z),a,(.76-.035*i)*escala,.075*escala,.20*escala,palha_cor(i+2))
    if maduro:
        for a,z in [(.4,.95),(3.3,1.15)]:
            p=Vector((x+.06*math.cos(a),y+.06*math.sin(a),z*escala))
            espiga(p)
        for i in range(5):
            a=i*math.tau/5
            tubo('MilhoOuro',[(x,y,h-.10),(x+.1*math.cos(a),y+.1*math.sin(a),h+.07),
                (x+.15*math.cos(a),y+.15*math.sin(a),h+.13)],[.008,.006,.002],5)

def solo():
    n=26
    borda=[]
    for i in range(n):
        a=i*math.tau/n
        r=1+ALEATORIO.uniform(-.08,.08)
        borda.append(Vector((2.85*r*math.cos(a),-.6+2.9*r*math.sin(a),.035)))
    for i in range(n):
        face(['Terra','TerraClara','TerraEscura'][i%3],[(0,-.6,.06),borda[i],borda[(i+1)%n]],(0,0,1))
    for i in range(n):
        a,b=borda[i],borda[(i+1)%n]
        face('TerraEscura',[a,b,Vector((b.x,b.y,-.07)),Vector((a.x,a.y,-.07))])
    for x in [-1.40,1.25]:
        for y in [-1.9,-.65,.45]:
            pedra(x+.42,y-.25,.035,(.12,.085,.045))

def produzir():
    iniciar('CentroAgricolaA1')
    solo()
    abrigo(0,1.15,3.15,1.75)
    cesto(1.95,.7,.07,.27,.40)
    for i in range(12):
        x=-.7+(i%4)*.15
        z=.08+(i//4)*.11
        viga((x,.85,z),(x+.09,1.7,z+.06),.042)
    viga((-2.1,-1.85,.04),(-1.86,-1.8,.83),.024)
    agricultura=fechar('centro_agricola_nivel_1')
    raiz_agricultura=RAIZ_OBJ

    iniciar('CentroPescaP1')
    abrigo(0,.40,3.45,2.05)
    rede(0,-.20)
    cesto(-1.70,-1.05,.015,.32,.46)
    cesto(-1.08,-1.17,.015,.23,.34)
    armadilha(1.35,-1.35,.28)
    pedra(.02,-1.45,.015,(.57,.41,.16))
    pesca=fechar('centro_pesca_nivel_1')

    cenas_cultivos={}
    for especie in ['mandioca','milho']:
        for fase,escala in [('broto',.24),('jovem',.58),('maduro',1.0)]:
            iniciar(especie+'_'+fase)
            if especie=='mandioca':
                mandioca(0,0,escala)
            else:
                milho(0,0,escala,fase=='maduro')
            fechar(especie+'_'+fase,fonte=False)
            cenas_cultivos[especie+'_'+fase]=CENA
    # O fonte de cultivos contém as seis cenas de crescimento editáveis.
    bpy.data.libraries.write(str(RAIZ/'art/blender/cultivos_etapa_8.blend'),set(cenas_cultivos.values()),fake_user=True,compress=True)
    bpy.context.window.scene=agricultura
    # O fonte da roça conserva a composição completa. O GLB do abrigo é independente dos cultivos.
    for especie,colunas in [('mandioca',3),('milho',2)]:
        doadora=cenas_cultivos[especie+'_maduro']
        malha=next(o for o in doadora.objects if o.type=='MESH')
        for j in range(3):
            for i in range(colunas):
                copia=malha.copy()
                agricultura.collection.objects.link(copia)
                copia.parent=raiz_agricultura
                copia.location=(-1.65+i*.70 if especie=='mandioca' else .65+i*.90,-2.15+j*.85,0)
                copia.scale=(.84,.84,.84) if especie=='mandioca' else (.94,.94,.94)
    bpy.data.libraries.write(str(RAIZ/'art/blender/centro_agricola_nivel_1.blend'),{agricultura},fake_user=True,compress=True)
    print('ETAPA_8_ASSETS: 2 centros e 6 estágios de cultivo exportados.')

produzir()
