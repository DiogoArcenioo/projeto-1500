"""Oca triangular original, modelada no Blender pelo MCP a partir da referência aprovada."""
import bpy
import math
import random
from pathlib import Path
from mathutils import Vector

RAIZ = Path(r'C:\Users\PC\Documents\ChatGPT\1500')
ALEATORIO = random.Random(150003)
LARGURA = 2.48
ALTURA = 3.82
MEIO_COMPRIMENTO = 2.78
DADOS = {}


def cor(hexadecimal):
    def linear(v):
        return v/12.92 if v < .04045 else ((v+.055)/1.055)**2.4
    return tuple(linear(int(hexadecimal[i:i+2],16)/255) for i in (0,2,4))+(1,)


def material(nome, hexadecimal, rugosidade=.85):
    mat = bpy.data.materials.new('OcaN1_'+nome)
    mat.use_nodes = True
    mat.diffuse_color = cor(hexadecimal)
    no = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    no.inputs['Base Color'].default_value = cor(hexadecimal)
    no.inputs['Roughness'].default_value = rugosidade
    if hasattr(mat,'use_backface_culling'):
        mat.use_backface_culling = nome not in ['Forro'] and not nome.startswith('Folha')
    DADOS[nome] = {'vertices':[],'faces':[],'material':mat}
    return nome


def face(nome,pontos,normal=None):
    pontos = [Vector(p) for p in pontos]
    if len(pontos)<3:
        return
    n = (pontos[1]-pontos[0]).cross(pontos[2]-pontos[0])
    if n.length < 1e-8:
        return
    if normal is not None and n.dot(normal)<0:
        pontos.reverse()
    dados = DADOS[nome]
    inicio = len(dados['vertices'])
    dados['vertices'].extend(tuple(p) for p in pontos)
    dados['faces'].append(tuple(range(inicio,inicio+len(pontos))))


def tubo(nome,pontos,raios,lados=9,tampar=True,variar=False):
    pontos = [Vector(p) for p in pontos]
    aneis=[]
    for j,(p,r) in enumerate(zip(pontos,raios)):
        eixo=(pontos[min(j+1,len(pontos)-1)]-pontos[max(0,j-1)]).normalized()
        lateral=eixo.cross(Vector((0,1,0)))
        if lateral.length<.01:
            lateral=eixo.cross(Vector((1,0,0)))
        lateral.normalize()
        outro=eixo.cross(lateral).normalized()
        aneis.append([p+r*(math.cos(i*math.tau/lados)*lateral+math.sin(i*math.tau/lados)*outro) for i in range(lados)])
    for j in range(len(aneis)-1):
        for i in range(lados):
            mat='MadeiraClara' if variar and i%4==1 else nome
            face(mat,[aneis[j][i],aneis[j][(i+1)%lados],aneis[j+1][(i+1)%lados],aneis[j+1][i]])
    if tampar:
        mat='CorteMadeira' if nome.startswith('Madeira') else nome
        face(mat,list(reversed(aneis[0])))
        face(mat,aneis[-1])


def viga(a,b,raio=.10):
    a,b=Vector(a),Vector(b)
    meio=(a+b)*.5+Vector((.015,-.013,.008))
    tubo('Madeira',[a,meio,b],[raio*.98,raio*1.03,raio*.89],9,variar=True)


def amarracao(centro,eixo,raio,voltas=5,largura=.20):
    centro,eixo=Vector(centro),Vector(eixo).normalized()
    lateral=eixo.cross(Vector((0,1,0)))
    if lateral.length<.01:
        lateral=eixo.cross(Vector((1,0,0)))
    lateral.normalize()
    outro=eixo.cross(lateral).normalized()
    pontos=[]
    passos=voltas*20
    for i in range(passos+1):
        t=i/passos
        ang=t*math.tau*voltas
        pontos.append(centro+eixo*(t-.5)*largura+(lateral*math.cos(ang)+outro*math.sin(ang))*raio)
    tubo('Fibras',pontos,[.018]*len(pontos),5,tampar=True)
    # Uma volta diagonal prende as espiras sem adicionar laços soltos à silhueta.
    a=centro+eixo*(-largura*.5)+lateral*(raio+.014)
    b=centro+eixo*(largura*.5)+outro*(raio+.014)
    tubo('Fibras',[a,(a+b)*.5+lateral*.015,b],[.016,.016,.014],5)


def recortar(poligono,avaliar):
    if not poligono:
        return []
    saida=[]
    anterior=poligono[-1]
    da=avaliar(anterior)
    for atual in poligono:
        db=avaliar(atual)
        if (da>=0)!=(db>=0):
            t=da/(da-db)
            saida.append(anterior+(atual-anterior)*t)
        if db>=0:
            saida.append(atual)
        anterior,da=atual,db
    return saida


def face_fachada(nome,pontos,normal,porta):
    p=[Vector(v) for v in pontos]
    # Recorte exato no contorno triangular, preservando a abertura da entrada.
    for plano in [lambda v:v.x+LARGURA*(1-v.z/ALTURA),
                  lambda v:LARGURA*(1-v.z/ALTURA)-v.x,
                  lambda v:v.z+.10,lambda v:ALTURA-v.z]:
        p=recortar(p,plano)
    if not porta:
        face(nome,p,normal)
        return
    for regiao in [
        [lambda v:-.68-v.x],
        [lambda v:v.x-.68],
        [lambda v:v.x+.68,lambda v:.68-v.x,lambda v:v.z-1.80],
    ]:
        parte=p
        for plano in regiao:
            parte=recortar(parte,plano)
        face(nome,parte,normal)


def folha(base,direcao,lateral,normal,comprimento,largura,nome,ponta_dourada=False,fachada=False,porta=False):
    base,direcao,lateral,normal=map(Vector,(base,direcao,lateral,normal))
    desvio=ALEATORIO.uniform(-.08,.08)
    linhas=[]
    parametros=(0,.17,.40,.65,.83,.94,1.0)
    for t in parametros:
        centro=base+direcao*(comprimento*t)+lateral*(desvio*t*t)
        centro+=normal*(.025+math.sin(math.pi*t)*.055+t*t*.035)
        crescimento=.15+.85*math.sin(min(t/.30,1.0)*math.pi*.5)
        afinamento=1.0-max(0.0,(t-.30)/.70)
        w=largura*.5*crescimento*afinamento
        linhas.append((centro-lateral*w-normal*w*.13,centro+normal*.018,centro+lateral*w-normal*w*.13))
    for j in range(len(linhas)-1):
        mat='FolhaSeca' if ponta_dourada and j>=4 else nome
        for k in range(2):
            pontos=[linhas[j][k],linhas[j+1][k],linhas[j+1][k+1],linhas[j][k+1]]
            if fachada:
                face_fachada(mat,pontos,normal,porta)
            else:
                face(mat,pontos,normal)
    # Nervura central estreita: relevo legível de perto, sem textura fotográfica.
    for j in range(1,5):
        a,b=linhas[j][1]+normal*.002,linhas[j+1][1]+normal*.002
        w=.007*(1-parametros[j])
        pontos=[a-lateral*w,a+lateral*w,b+lateral*w*.6,b-lateral*w*.6]
        if fachada:
            face_fachada('Nervuras',pontos,normal,porta)
        else:
            face('Nervuras',pontos,normal)


def cobertura():
    paleta=['FolhaJade','FolhaOliva','FolhaVerde','FolhaLima','FolhaMusgo']
    for lado in (-1,1):
        cima=Vector((0,0,ALTURA))
        direcao=Vector((lado*LARGURA,0,-ALTURA)).normalized()
        normal=Vector((lado*ALTURA,0,LARGURA)).normalized()
        face('Forro',[(-.01,-2.84,ALTURA),(lado*2.49,-2.84,-.04),(lado*2.49,2.84,-.04),(-.01,2.84,ALTURA)],normal)
        for linha in range(6):
            deslocamento=linha*.75+.015
            for coluna in range(14):
                y=-2.67+coluna*.415+ALEATORIO.uniform(-.045,.045)
                if linha%2:
                    y+=.12
                base=cima+direcao*(deslocamento+ALEATORIO.uniform(-.025,.025))
                base.y=y
                base+=normal*(.035+(5-linha)*.010)
                folha(base,direcao,(0,1,0),normal,ALEATORIO.uniform(1.00,1.16),ALEATORIO.uniform(.59,.72),ALEATORIO.choice(paleta),ALEATORIO.random()<.25)
    for frente in (-1,1):
        normal=Vector((0,frente,0))
        y=frente*2.835
        triangulo=[(-LARGURA,y,-.04),(LARGURA,y,-.04),(0,y,ALTURA)]
        face_fachada('Forro',triangulo,normal,frente==-1)
        for linha in range(9):
            z=3.78-linha*.46
            largura_max=LARGURA*(1-max(0,z)/ALTURA)+.25
            colunas=max(1,math.ceil(largura_max*2/.43))
            for coluna in range(colunas):
                x=(coluna-(colunas-1)/2)*.43+ALEATORIO.uniform(-.035,.035)
                base=Vector((x,y,z))+normal*(.025+(8-linha)*.004)
                folha(base,(0,0,-1),(1,0,0),normal,ALEATORIO.uniform(.78,.96),ALEATORIO.uniform(.58,.68),ALEATORIO.choice(paleta),ALEATORIO.random()<.22,True,frente==-1)


def estrutura():
    for y in (-2.98,2.98):
        for lado in (-1,1):
            a=Vector((lado*2.53,y,-.14))
            b=Vector((-lado*.31,y,4.28))
            viga(a,b,.115)
            eixo=(b-a).normalized()
            t=(1.88-a.z)/(b.z-a.z)
            amarracao(a+(b-a)*t,eixo,.137,5,.21)
        amarracao((0,y,3.88),(0,0,1),.235,6,.27)
    viga((0,-3.15,3.92),(0,3.17,3.92),.14)
    for y in (-2.78,-1.4,0,1.4,2.78):
        amarracao((0,y,3.92),(0,1,0),.163,5,.20)
    # Estrutura interna de apoio e travessas da cobertura.
    for y in (-1.85,-.55,.75,2.0):
        for lado in (-1,1):
            viga((lado*2.33,y,-.07),(0,y,3.70),.052)
    for lado in (-1,1):
        for fracao in (.43,.80):
            x=lado*LARGURA*fracao
            z=ALTURA*(1-fracao)-.06
            viga((x,-2.7,z),(x,2.7,z),.048)
    y=-3.08
    viga((-1.35,y,1.87),(1.35,y,1.87),.095)
    for x in (-.76,.76):
        viga((x,y,-.14),(x,y,1.97),.092)
        for z in (.42,1.47):
            amarracao((x,y,z),(0,0,1),.115,5,.18)
        amarracao((x,y,1.87),(1,0,0),.122,5,.19)


def montar_malhas(cena,raiz):
    objetos=[]
    for nome,dados in DADOS.items():
        if not dados['faces']:
            continue
        malha=bpy.data.meshes.new('OcaN1_'+nome)
        malha.from_pydata(dados['vertices'],[],dados['faces'])
        malha.validate()
        malha.update()
        malha.materials.append(dados['material'])
        uv=malha.uv_layers.new(name='UVMap')
        for pol in malha.polygons:
            n=pol.normal
            eixos=(0,1) if abs(n.z)>.75 else ((0,2) if abs(n.y)>abs(n.x) else (1,2))
            for indice in pol.loop_indices:
                v=malha.vertices[malha.loops[indice].vertex_index].co
                uv.data[indice].uv=(v[eixos[0]]*.5,v[eixos[1]]*.5)
        objeto=bpy.data.objects.new('Oca_'+nome,malha)
        cena.collection.objects.link(objeto)
        objeto.parent=raiz
        objetos.append(objeto)
    return objetos


def produzir():
    for anterior in list(bpy.data.scenes):
        if anterior.name=='1500_OcaTriangularNivel1':
            for objeto in list(anterior.objects):
                dados=objeto.data
                bpy.data.objects.remove(objeto,do_unlink=True)
                if dados and dados.users==0 and isinstance(dados,bpy.types.Mesh):
                    bpy.data.meshes.remove(dados)
            bpy.data.scenes.remove(anterior)
    cena=bpy.data.scenes.new('1500_OcaTriangularNivel1')
    bpy.context.window.scene=cena
    raiz=bpy.data.objects.new('OcaNivel1',None)
    cena.collection.objects.link(raiz)
    raiz['referencia']='art/references/etapa_3/oca_triangular_01.png — escolha aprovada no chat'
    raiz['estado']='Portão B — modelo para aprovação no Godot, sem regras de construção'
    raiz['autoria']='Geometria e materiais originais produzidos no Blender via MCP'
    raiz['direcao_entrada_blender']='-Y; em Godot, +Z'
    material('Madeira','955d2f',.84)
    material('MadeiraClara','b57b3a',.83)
    material('CorteMadeira','ce9c60',.88)
    material('Fibras','d7b76c',.96)
    material('Forro','304326',.98)
    material('FolhaJade','3f722f',.79)
    material('FolhaOliva','728932',.82)
    material('FolhaVerde','5c8734',.80)
    material('FolhaLima','8ca03b',.82)
    material('FolhaMusgo','57712d',.84)
    material('FolhaSeca','b9a04b',.87)
    material('Nervuras','8d9c3c',.85)
    cobertura()
    estrutura()
    objetos=montar_malhas(cena,raiz)
    cena.unit_settings.system='METRIC'
    cena.unit_settings.scale_length=1.0
    with bpy.context.temp_override(scene=cena,view_layer=cena.view_layers[0]):
        for selecionado in list(bpy.context.selected_objects):
            selecionado.select_set(False)
        raiz.select_set(True)
        for objeto in objetos:
            objeto.select_set(True)
        bpy.context.view_layer.objects.active=raiz
        bpy.ops.export_scene.gltf(filepath=str(RAIZ/'assets/models/oca_nivel_1.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_cameras=False,export_lights=False,export_yup=True)
    # Os elementos abaixo pertencem à inspeção no Blender, não ao GLB.
    mundo=bpy.data.worlds.new('Oca_CeuInspecao')
    mundo.use_nodes=True
    fundo=next(n for n in mundo.node_tree.nodes if n.type=='BACKGROUND')
    fundo.inputs[0].default_value=(.20,.26,.24,1)
    fundo.inputs[1].default_value=.6
    cena.world=mundo
    sol_data=bpy.data.lights.new('Oca_SolInspecao','SUN')
    sol_data.energy=3.0
    sol_data.angle=math.radians(8)
    sol=bpy.data.objects.new('Oca_SolInspecao',sol_data)
    cena.collection.objects.link(sol)
    sol.rotation_euler=(math.radians(30),math.radians(-20),math.radians(-30))
    camera_data=bpy.data.cameras.new('Oca_CameraInspecao')
    camera=bpy.data.objects.new('Oca_CameraInspecao',camera_data)
    cena.collection.objects.link(camera)
    camera.location=(7.8,-10,6.2)
    camera.rotation_euler=(Vector((0,0,1.8))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.lens=46
    cena.camera=camera
    cena.render.resolution_x=1280
    cena.render.resolution_y=720
    cena.render.resolution_percentage=100
    # Grava somente esta cena e suas dependências, preservando o .blend do cenário.
    destino=RAIZ/'art/blender/oca_nivel_1.blend'
    bpy.data.libraries.write(str(destino),{cena},fake_user=True,compress=True)
    vertices=sum(len(o.data.vertices) for o in objetos)
    faces=sum(len(o.data.polygons) for o in objetos)
    print('OCA_NIVEL_1:',len(objetos),'malhas;',vertices,'vertices;',faces,'faces')
    print('Fonte independente:',destino)
    print('GLB bytes:',(RAIZ/'assets/models/oca_nivel_1.glb').stat().st_size)


produzir()
