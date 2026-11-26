"""Onça B — corpo contínuo, pintura de rosetas e rig. Frente Blender −Y."""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

RAIZ = Path(__file__).resolve().parents[1]
TAU = math.tau


def suavizar(inicio, fim, valor):
    t = min(1.0, max(0.0, (valor - inicio) / (fim - inicio)))
    return t*t*(3 - 2*t)


def material(nome, cor, rugosidade):
    mat = bpy.data.materials.new(nome)
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    shader.inputs['Base Color'].default_value = (*cor, 1.0)
    shader.inputs['Roughness'].default_value = rugosidade
    return mat, shader


def loft(centros, largura, altura, secoes=28, interpolar=False):
    if interpolar:
        def curva(valores):
            resultado = []
            for i in range(len(valores)-1):
                a,b,c,d = (valores[max(0,i-1)], valores[i], valores[i+1], valores[min(len(valores)-1,i+2)])
                for j in range(4):
                    t = j/4
                    resultado.append((2*b + (c-a)*t + (2*a-5*b+4*c-d)*t*t + (3*b-a-3*c+d)*t*t*t)*.5)
            return resultado+[valores[-1]]
        centros, largura, altura = curva(centros), curva(largura), curva(altura)
    vertices, faces = [], []
    for i, centro in enumerate(centros):
        tangente = (centros[min(i + 1, len(centros) - 1)] - centros[max(0, i - 1)]).normalized()
        eixo_x = (Vector((1, 0, 0)) - tangente*tangente.x).normalized()
        eixo_z = eixo_x.cross(tangente).normalized()
        for k in range(secoes):
            angulo = TAU*k/secoes
            vertices.append(centro + eixo_x*math.cos(angulo)*largura[i] + eixo_z*math.sin(angulo)*altura[i])
    for i in range(len(centros)-1):
        for k in range(secoes):
            j = (k + 1) % secoes
            faces.append((i*secoes+k, i*secoes+j, (i+1)*secoes+j, (i+1)*secoes+k))
    faces.append(tuple(reversed(range(secoes))))
    base = (len(centros)-1)*secoes
    faces.append(tuple(base+i for i in range(secoes)))
    return vertices, faces


def perfil(dados):
    return loft([Vector((0, y, z)) for y, z, _, _ in dados], [a for _, _, a, _ in dados], [b for _, _, _, b in dados], 40, True)


def elipsoide(centro, raios, giro=None, lados=24, aneis=12):
    c, giro = Vector(centro), giro or Matrix.Identity(3)
    vs = [c + giro @ Vector((0, 0, raios[2]))]
    for j in range(1, aneis):
        t = math.pi*j/aneis
        for k in range(lados):
            a = TAU*k/lados
            vs.append(c + giro @ Vector((raios[0]*math.sin(t)*math.cos(a), raios[1]*math.sin(t)*math.sin(a), raios[2]*math.cos(t))))
    vs.append(c + giro @ Vector((0, 0, -raios[2])))
    fs = []
    for k in range(lados):
        l = (k+1) % lados
        fs.append((0, 1+k, 1+l))
        for j in range(aneis-2):
            i = 1+j*lados
            fs.append((i+k, i+k+lados, i+l+lados, i+l))
        i = 1+(aneis-2)*lados
        fs.append((len(vs)-1, i+l, i+k))
    return vs, fs


def malha(cena, nome, partes):
    vertices, faces = [], []
    for vs, fs in partes:
        base = len(vertices)
        vertices.extend(vs)
        faces.extend(tuple(v+base for v in f) for f in fs)
    dados = bpy.data.meshes.new(nome)
    dados.from_pydata(vertices, [], faces)
    bm = bmesh.new()
    bm.from_mesh(dados)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(dados)
    bm.free()
    for face in dados.polygons:
        face.use_smooth = True
    obj = bpy.data.objects.new(nome, dados)
    cena.collection.objects.link(obj)
    return obj


# Corpo sólido: garupa → cintura → caixa torácica → pescoço → cabeça.
CORPO = [(.68, .49, .024, .055), (.62, .50, .129, .167), (.52, .505, .207, .220),
         (.38, .515, .220, .218), (.25, .512, .201, .195), (.12, .515, .195, .187),
         (0, .518, .211, .218), (-.14, .524, .231, .242), (-.29, .535, .223, .254),
         (-.42, .555, .192, .221), (-.51, .593, .156, .177), (-.60, .638, .144, .139),
         (-.68, .659, .151, .134), (-.75, .657, .144, .126), (-.81, .642, .120, .103),
         (-.855, .620, .089, .073), (-.889, .608, .052, .048)]
FRENTE = [(.143, -.287, .622, .111, .143), (.149, -.281, .508, .108, .127),
          (.155, -.251, .394, .083, .087), (.153, -.217, .298, .058, .060),
          (.151, -.245, .193, .051, .052), (.155, -.271, .101, .052, .060),
          (.156, -.281, .047, .058, .065)]
TRAS = [(.145, .449, .606, .099, .124), (.156, .414, .514, .108, .142),
        (.156, .339, .402, .091, .106), (.157, .338, .328, .069, .072),
        (.159, .454, .210, .044, .058), (.159, .433, .112, .038, .044),
        (.159, .389, .049, .054, .063)]
CAUDA = [(0, .50, .614), (0, .62, .599), (.014, .748, .529), (.069, .868, .414),
         (.126, .983, .306), (.186, 1.118, .258), (.250, 1.232, .270),
         (.280, 1.300, .324), (.275, 1.323, .376), (.269, 1.325, .395)]


def escultura(cena):
    partes = [perfil(CORPO)]
    raios = [.075, .066, .059, .051, .047, .042, .037, .031, .020, .005]
    partes.append(loft([Vector(p) for p in CAUDA], raios, raios, 24, True))
    for lado in (-1, 1):
        for dados in (FRENTE, TRAS):
            centros = [Vector((lado*x, y, z)) for x,y,z,_,_ in dados]
            partes.append(loft(centros, [a for *_,a,b in dados], [b for *_,b in dados], 24, True))
            x, y, _, _, _ = dados[-1]
            partes.append(elipsoide((lado*x, y-.029, .049), (.070, .092, .048)))
            for dedo, recuo in ((-.042, .013), (-.014, 0), (.014, 0), (.042, .012)):
                partes.append(elipsoide((lado*x+dedo, y-.089+recuo, .029), (.020, .038, .027)))
        partes.append(elipsoide((lado*.057, -.856, .586), (.068, .088, .057)))
        partes.append(elipsoide((lado*.092, -.738, .589), (.067, .118, .067)))
        partes.append(elipsoide((lado*.110, -.675, .755), (.047, .033, .057), Matrix.Rotation(lado*-.45, 3, 'Y')))
    partes.append(elipsoide((0, -.829, .543), (.082, .089, .045)))
    obj = malha(cena, 'Onca_Corpo', partes)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for nome, tipo, ajustes in [
        ('Unir volumes', 'REMESH', {'mode':'VOXEL', 'voxel_size':.007}),
        ('Suavizar transições', 'SMOOTH', {'factor':.62, 'iterations':8}),
        ('Reduzir para o jogo', 'DECIMATE', {'ratio':.33}),
    ]:
        mod = obj.modifiers.new(nome, tipo)
        for chave, valor in ajustes.items():
            setattr(mod, chave, valor)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.dissolve_degenerate(bm, dist=.00003, edges=list(bm.edges))
    restantes = set(bm.verts)
    componentes = []
    while restantes:
        fila = [restantes.pop()]
        componente = fila.copy()
        for v in fila:
            for e in v.link_edges:
                vizinho = e.other_vert(v)
                if vizinho in restantes:
                    restantes.remove(vizinho)
                    fila.append(vizinho)
                    componente.append(vizinho)
        componentes.append(componente)
    corpo_principal = max(componentes, key=len)
    soltos = [v for c in componentes if c is not corpo_principal for v in c]
    if soltos:
        bmesh.ops.delete(bm, geom=soltos, context='VERTS')
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.validate(clean_customdata=False)
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def pelagem(cena, obj):
    """Padrão tridimensional pintado em UV para o GLB manter as rosetas."""
    mat, bsdf = material('Pelagem pintada', (.50,.24,.060), .84)
    obj.data.materials.append(mat)
    arv = mat.node_tree
    ns = arv.nodes
    liga = arv.links.new

    def entra(valor, entrada):
        if isinstance(valor, bpy.types.NodeSocket):
            liga(valor, entrada)
        else:
            entrada.default_value = valor

    def mathn(op, a, b):
        n = ns.new('ShaderNodeMath'); n.operation = op
        entra(a,n.inputs[0]); entra(b,n.inputs[1])
        return n.outputs[0]

    def rampa(x, a, b):
        n = ns.new('ShaderNodeMapRange'); n.interpolation_type = 'SMOOTHERSTEP'; n.clamp = True
        entra(x,n.inputs[0]); n.inputs[1].default_value = a; n.inputs[2].default_value = b
        return n.outputs[0]

    def mistura(f, a, b):
        n = ns.new('ShaderNodeMixRGB')
        entra(f,n.inputs[0]); entra(a,n.inputs[1]); entra(b,n.inputs[2])
        return n.outputs[0]

    coord = ns.new('ShaderNodeTexCoord').outputs['Object']
    eixos = ns.new('ShaderNodeSeparateXYZ'); liga(coord,eixos.inputs[0])
    x, y, z = eixos.outputs[:]

    def voronoi(escala):
        n = ns.new('ShaderNodeTexVoronoi')
        liga(coord,n.inputs['Vector']); n.inputs['Scale'].default_value = escala
        return n.outputs['Distance']

    def ruido(escala):
        n = ns.new('ShaderNodeTexNoise')
        liga(coord,n.inputs['Vector']); n.inputs['Scale'].default_value = escala
        n.inputs['Detail'].default_value = 2.0
        return n.outputs['Fac']

    irregular = ruido(38)
    dist = mathn('ADD',voronoi(11.2),mathn('MULTIPLY',mathn('SUBTRACT',irregular,.5),.24))
    contorno = rampa(dist,.492,.409)
    anel = mathn('MULTIPLY',contorno,rampa(dist,.232,.303))
    quebra = rampa(irregular,.255,.377)
    anel = mathn('MULTIPLY',anel,quebra)
    centro = rampa(dist,.122,.086)
    rosetas = mathn('MAXIMUM',anel,centro)
    manchas = rampa(mathn('ADD',voronoi(21.2),mathn('MULTIPLY',irregular,.085)),.306,.246)
    cabeca = rampa(y,-.54,-.674)
    perna = rampa(z,.47,.30)
    zonas_pequenas = mathn('MAXIMUM',cabeca,perna)
    pintas = mathn('ADD', mathn('MULTIPLY',rosetas,mathn('SUBTRACT',1,zonas_pequenas)), mathn('MULTIPLY',manchas,zonas_pequenas))

    base = mistura(rampa(z,.36,.81),(.57,.278,.083,1),(.436,.161,.035,1))
    base = mistura(mathn('MULTIPLY',contorno,.49),base,(.42,.136,.032,1))
    barriga = mathn('MULTIPLY', rampa(z,.468,.342),rampa(mathn('ABSOLUTE',x,0),.177,.058))
    queixo = mathn('MULTIPLY',rampa(y,-.67,-.80),rampa(z,.635,.524))
    claro = mathn('MAXIMUM', barriga, queixo)
    base = mistura(claro,base,(.83,.699,.493,1))
    base = mistura(mathn('MULTIPLY',ruido(4),.16),base,(.71,.408,.148,1))
    base = mistura(pintas,base,(.018,.009,.007,1))
    ponta_cauda = rampa(y,1.258,1.314)
    base = mistura(ponta_cauda,base,(.035,.022,.016,1))

    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(73), island_margin=.012)
    bpy.ops.object.mode_set(mode='OBJECT')
    imagem = bpy.data.images.new('Onca_Pelagem_UV', 2048, 2048, alpha=False)
    imagem.colorspace_settings.name = 'sRGB'
    alvo = ns.new('ShaderNodeTexImage'); alvo.image = imagem
    ns.active = alvo
    emissao = ns.new('ShaderNodeEmission'); liga(base,emissao.inputs['Color'])
    saida = next(n for n in ns if n.type == 'OUTPUT_MATERIAL')
    liga(emissao.outputs[0],saida.inputs['Surface'])
    cena.render.engine = 'CYCLES'
    cena.cycles.device = 'CPU'
    cena.cycles.samples = 1
    bpy.ops.object.bake(type='EMIT', margin=12)
    textura = RAIZ/'art/blender/onca_pintada_pelagem.png'
    imagem.filepath_raw = str(textura)
    imagem.file_format = 'PNG'
    imagem.save()
    imagem.pack()
    textura.unlink()
    for no in list(ns):
        if no not in (bsdf, alvo, saida):
            ns.remove(no)
    liga(alvo.outputs['Color'],bsdf.inputs['Base Color'])
    liga(bsdf.outputs[0],saida.inputs['Surface'])


def rosto(cena, corpo):
    arvore = BVHTree.FromObject(corpo, bpy.context.evaluated_depsgraph_get())
    pecas = []
    nariz, _ = material('Nariz de couro', (.115,.051,.040), .55)
    escuro, _ = material('Lábios e pupilas', (.026,.018,.014), .47)
    orelha, _ = material('Interior da orelha', (.158,.092,.057), .88)
    olho, _ = material('Íris âmbar', (.39,.191,.036), .42)

    def detalhe(nome, partes, mat):
        obj = malha(cena,nome,partes)
        obj.data.materials.append(mat)
        pecas.append(obj)

    def projetar(px, alt, relevo):
        hit = arvore.ray_cast(Vector((px,-1.15,alt)),Vector((0,1,0)),.49)[0]
        return hit+Vector((0,-relevo,0)) if hit is not None else Vector((px,-.81-relevo,alt))

    def disco_olho(lado, rx, rz, relevo, contorno=False):
        """Pálpebra amendoada rente à superfície, com o canto externo mais alto."""
        cx, cz = lado*.082, .694
        n = 32
        vs = [projetar(cx,cz,relevo)]
        for anel in (0.5,1.0):
            for i in range(n):
                a = TAU*i/n
                dx = rx*math.cos(a)*anel
                dz = rz*math.sin(a)*anel
                if contorno:
                    dz *= 1-.37*abs(math.cos(a))
                    dz += dx*lado*.17
                vs.append(projetar(cx+dx,cz+dz,relevo))
        fs = [(0,1+i,1+(i+1)%n) for i in range(n)]
        fs += [(1+i,1+n+i,1+n+(i+1)%n,1+(i+1)%n) for i in range(n)]
        return vs,fs

    vs, fs = elipsoide((0,-.941,.622), (.060,.019,.028), lados=36,aneis=16)
    for v in vs:
        largura = .66+.34*suavizar(.597,.637,v.z)
        v.x *= largura
    detalhe('Nariz',[(vs,fs)],nariz)
    for lado in (-1,1):
        detalhe('Pálpebra', [disco_olho(lado,.034,.015,.002,True)], escuro)
        detalhe('Olho', [disco_olho(lado,.026,.0105,.0036,True)], olho)
        detalhe('Pupila', [disco_olho(lado,.0077,.0085,.005)], escuro)
        detalhe('Orelha interior', [elipsoide((lado*.116,-.705,.767),(.030,.008,.036),Matrix.Rotation(lado*-.45,3,'Y'))],orelha)
        detalhe('Narina', [elipsoide((lado*.031,-.956,.621),(.010,.004,.006))],escuro)
        centros = []
        for px, alt in [(0,.597),(.018,.565),(.041,.555),(.071,.553),(.095,.555),(.119,.558)]:
            centros.append(projetar(lado*px,alt,.0014))
        if len(centros)>1:
            tamanhos = [.0026]*(len(centros)-1)+[.001]
            detalhe('Linha do lábio', [loft(centros,tamanhos,tamanhos,8)], escuro)
    return pecas


def segmento(p,a,b):
    d = b-a
    t = max(0,min(1,(p-a).dot(d)/d.length_squared))
    return (p-a-d*t).length


def esqueleto(cena, corpo, detalhes):
    arm = bpy.data.armatures.new('Esqueleto_Onca')
    rig = bpy.data.objects.new('Rig_Onca',arm)
    cena.collection.objects.link(rig)
    corpo.select_set(False)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')

    def osso(nome,a,b,pai=None):
        n=arm.edit_bones.new(nome); n.head=a; n.tail=b
        if pai: n.parent=arm.edit_bones[pai]

    osso('raiz',(0,0,0),(0,0,.17))
    osso('tronco',(0,.44,.53),(0,-.32,.57),'raiz')
    osso('pescoco',(0,-.32,.57),(0,-.61,.65),'tronco')
    osso('cabeca',(0,-.61,.65),(0,-.925,.615),'pescoco')
    cauda = [Vector(CAUDA[i]) for i in (0,2,4,6,8,9)]
    for i in range(5):
        osso(f'cauda_{i}',cauda[i],cauda[i+1],'tronco' if i==0 else f'cauda_{i-1}')
    pernas = {}
    for lado,sinal in [('E',1),('D',-1)]:
        for membro, linha in [('frente',[(.146,-.289,.596),(.152,-.211,.309),(.155,-.270,.097),(.155,-.355,.024)]),
                              ('tras',[(.155,.429,.547),(.157,.329,.329),(.159,.431,.107),(.159,.320,.025)])]:
            pontos = [Vector((sinal*x,y,z)) for x,y,z in linha]
            nomes = [f'{membro}_{lado}',f'{membro}_canela_{lado}',f'{membro}_pe_{lado}']
            pernas[(membro,lado)] = (pontos,nomes)
            for i,nome in enumerate(nomes):
                osso(nome,pontos[i],pontos[i+1],'tronco' if i==0 else nomes[i-1])
    bpy.ops.object.mode_set(mode='OBJECT')
    grupos = {n.name:corpo.vertex_groups.new(name=n.name) for n in arm.bones}
    for vert in corpo.data.vertices:
        p=vert.co
        pesos={}
        influencia_cauda=suavizar(.605,.750,p.y)*suavizar(.27,.34,p.z+.3*max(0,p.y-.65))
        if p.y>.73: influencia_cauda=1
        dist = [segmento(p,cauda[i],cauda[i+1]) for i in range(5)]
        if influencia_cauda>.001:
            fatores=[1/(d+.012)**6 for d in dist]
            for i,f in enumerate(fatores): pesos[f'cauda_{i}']=influencia_cauda*f/sum(fatores)
        restante=1-influencia_cauda
        lado='E' if p.x>=0 else 'D'
        membro='frente' if p.y<0 else 'tras'
        pontos, nomes = pernas[(membro,lado)]
        dist = [segmento(p,pontos[i],pontos[i+1]) for i in range(3)]
        perna=suavizar(.572,.350,p.z)*suavizar(.035,.089,abs(p.x))*suavizar(.187,.086,min(dist))
        if p.z<.19 and p.y<.65: perna=1
        fatores=[1/(d+.015)**6 for d in dist]
        for nome,f in zip(nomes,fatores): pesos[nome]=restante*perna*f/sum(fatores)
        restante*=1-perna
        pesco=suavizar(-.38,-.56,p.y)
        cabe=suavizar(-.53,-.665,p.y)
        pesos.update(tronco=restante*(1-pesco)*(1-cabe), pescoco=restante*pesco*(1-cabe), cabeca=restante*cabe)
        principais=sorted(pesos.items(),key=lambda x:-x[1])[:4]
        soma=sum(peso for _,peso in principais)
        for nome,peso in principais:
            if peso>0: grupos[nome].add([vert.index],peso/soma,'REPLACE')
    for obj in [corpo]+detalhes:
        obj.parent=rig
        if obj != corpo:
            obj.vertex_groups.new(name='cabeca').add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
        obj.modifiers.new('Deformar com rig','ARMATURE').object=rig
    rig.animation_data_create()
    return rig


def produzir():
    cena = bpy.data.scenes.new('Onca_Pintada_Natural')
    bpy.context.window.scene = cena
    cena.render.fps = 24
    corpo = escultura(cena)
    # Guardar o material bakeado e a malha no mesmo fonte editável.
    pelagem(cena,corpo)
    detalhes=rosto(cena,corpo)
    rig=esqueleto(cena,corpo,detalhes)
    print('ONÇA — geometria:', len(corpo.data.vertices), 'vértices no corpo,', len(rig.data.bones), 'ossos')
    return cena, corpo, rig


if __name__ == '__main__':
    anterior = bpy.context.window.scene
    try:
        cena, corpo, rig = produzir()
        bpy.data.libraries.write(str(RAIZ/'art/blender/onca_pintada.blend'), {cena}, fake_user=True, compress=True)
    finally:
        bpy.context.window.scene = anterior
