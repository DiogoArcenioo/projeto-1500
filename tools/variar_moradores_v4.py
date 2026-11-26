"""Revisão 4 — oito moradores sobre a anatomia lisa da revisão 4.
Executado por tools/modelar_moradores_v4.py (modo 'tudo'), que fornece CENA e RAIZ.
Cabelo e roupa são gerados aqui, ajustados ao corpo de cada pessoa:
 - braços relaxados junto ao corpo (~9° em vez da pose em A);
 - cabelo moldado sobre o crânio, com linha da testa e mechas caindo;
 - saia em duas camadas (folha + terracota com barra diagonal), cinto de corda com nó;
 - top faixa nas mulheres.
Exporta assets/models/habitantes/<tag>.glb com Passo_E, Passo_D e Coletar.
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

PI = math.pi
# Operadores (join/export) agem na cena da janela: trabalha nela.
bpy.context.window.scene = CENA
SAIDA = RAIZ/'assets/models/habitantes'
REVISAO = RAIZ/'exports/revisao_moradores_v4'
REVISAO.mkdir(parents=True, exist_ok=True)

# Altura relativa, largura do corpo (exceto cabeça), cabelo, tom de pele.
PERFIS = {
    False: [(1.00, .00, 'longo', 'b5703e'), (.96, .06, 'curto', 'a9663a'),
            (1.04, -.04, 'coque', 'bb7744'), (.985, .03, 'ombros', 'a86a3e')],
    True:  [(1.00, .00, 'longo', 'b46f40'), (.97, .05, 'franja', 'aa683c'),
            (1.02, -.03, 'tranca', 'bc7846'), (1.04, .00, 'rabo', 'b06c3e')],
}


def suave(a, b, x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3-2*t)


def linear(hexa):
    c = [int(hexa[i:i+2], 16)/255 for i in (0, 2, 4)]
    return tuple(((v+.055)/1.055)**2.4 if v > .04045 else v/12.92 for v in c)+(1.0,)


def material(nome, cor, aspereza=.75, brilho=.0):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value = linear(cor)
    bs.inputs['Roughness'].default_value = aspereza
    if 'Coat Weight' in bs.inputs:
        bs.inputs['Coat Weight'].default_value = brilho
    return m


def objeto(nome, verts, faces, mats, indices=None, pai=None, liso=True):
    malha = bpy.data.meshes.new(nome)
    malha.from_pydata([tuple(v) for v in verts], [], faces)
    malha.update()
    for m in mats:
        malha.materials.append(m)
    for i, f in enumerate(malha.polygons):
        f.use_smooth = liso
        if indices:
            f.material_index = indices[i]
    o = bpy.data.objects.new(nome, malha)
    CENA.collection.objects.link(o)
    if pai:
        o.parent = pai
    return o


def aplicar(o, *mods):
    """mods: tuplas (tipo, {props})."""
    for tipo, props in mods:
        m = o.modifiers.new(tipo, tipo)
        for k, v in props.items():
            setattr(m, k, v)
        with bpy.context.temp_override(scene=CENA, object=o, active_object=o):
            bpy.ops.object.modifier_apply(modifier=m.name)


def tubo(pontos, raios, lados=10, fechado=False):
    verts, faces = [], []
    n = len(pontos)
    for j, p in enumerate(pontos):
        a = pontos[(j-1) % n] if fechado else pontos[max(0, j-1)]
        b = pontos[(j+1) % n] if fechado else pontos[min(n-1, j+1)]
        t = (b-a).normalized()
        ref = Vector((0, 0, 1)) if abs(t.z) < .9 else Vector((1, 0, 0))
        u = t.cross(ref).normalized()
        v = t.cross(u).normalized()
        for i in range(lados):
            ang = 2*PI*i/lados
            verts.append(p+raios[j]*(math.cos(ang)*u+math.sin(ang)*v))
    for j in range(n if fechado else n-1):
        k = (j+1) % n
        for i in range(lados):
            faces.append((j*lados+i, j*lados+(i+1) % lados, k*lados+(i+1) % lados, k*lados+i))
    if not fechado:
        faces.append(tuple(reversed(range(lados))))
        faces.append(tuple(range((n-1)*lados, n*lados)))
    return verts, faces


def esfera(c, r, seg=14, aneis=9):
    verts, faces = [], []
    for j in range(aneis+1):
        th = PI*j/aneis
        for i in range(seg):
            ph = 2*PI*i/seg
            verts.append(Vector(c)+Vector((r[0]*math.sin(th)*math.cos(ph), r[1]*math.sin(th)*math.sin(ph), r[2]*math.cos(th))))
    for j in range(aneis):
        for i in range(seg):
            faces.append((j*seg+i, j*seg+(i+1) % seg, (j+1)*seg+(i+1) % seg, (j+1)*seg+i))
    return verts, faces


def juntar(listas):
    verts, faces, idx = [], [], []
    for vs, fs, m in listas:
        base = len(verts)
        verts += vs
        faces += [tuple(i+base for i in f) for f in fs]
        idx += [m]*len(fs)
    return verts, faces, idx


# ---------------------------------------------------------------- corpo

def baixar_bracos(corpo, h, alvo=9.0):
    """Gira cada braço em torno do ombro até ~alvo graus da vertical.
    O braço é achado pela malha: da ponta da mão, segue as arestas abaixo da
    axila (ali braço e tronco são pedaços separados). Acima da axila, o ombro
    recebe peso gradual. Guarda o peso no grupo 'braco'."""
    grupo = corpo.vertex_groups.new(name='braco')
    malha = corpo.data
    vs = malha.vertices
    vizinhos = [[] for _ in vs]
    for e in malha.edges:
        a, b = e.vertices
        vizinhos[a].append(b)
        vizinhos[b].append(a)

    def inundar(inicio, teto):
        vistos = {inicio}
        fila = [inicio]
        while fila:
            i = fila.pop()
            for j in vizinhos[i]:
                if j not in vistos and vs[j].co.z < teto:
                    vistos.add(j)
                    fila.append(j)
        return vistos

    for lado in (1, -1):
        ponta = max((v for v in vs if v.co.x*lado > 0), key=lambda v: v.co.x*lado).index
        baixo, cima = vs[ponta].co.z+.05, .86*h
        for _ in range(18):
            meio = (baixo+cima)/2
            if any(abs(vs[i].co.x) < .05*h for i in inundar(ponta, meio)):
                cima = meio
            else:
                baixo = meio
        axila = baixo-.004
        braco = inundar(ponta, axila)
        borda = [vs[i].co for i in braco if vs[i].co.z > axila-.03]
        dentro = min(abs(c.x) for c in borda)
        fora = max(abs(c.x) for c in borda)
        ombro = Vector((lado*(dentro+fora)/2, sum(c.y for c in borda)/len(borda), axila+.055))
        mao = vs[ponta].co.copy()
        atual = math.degrees(math.atan2(abs(mao.x-ombro.x), ombro.z-mao.z))
        delta = math.radians(atual-alvo)*lado
        for v in vs:
            if v.co.x*lado <= 0:
                continue
            if v.index in braco:
                w = 1.0
            elif v.co.z >= axila:
                w = suave(dentro-.01, dentro+.035, abs(v.co.x))*(1-suave(axila+.02, axila+.11, v.co.z))
            else:
                w = 0.0
            if w <= 0:
                continue
            v.co = ombro+Matrix.Rotation(delta*w, 3, 'Y')@(v.co-ombro)
            grupo.add([v.index], w, 'REPLACE')
        print('BRACO', corpo.name, lado, 'axila', round(axila, 3), 'angulo', round(atual, 1), 'vertices', len(braco))
    malha.update()


def bvh_sem_bracos(corpo):
    bm = bmesh.new()
    bm.from_mesh(corpo.data)
    deform = bm.verts.layers.deform.active
    g = corpo.vertex_groups['braco'].index
    apagar = [v for v in bm.verts if deform and v[deform].get(g, 0) > .25]
    bmesh.ops.delete(bm, geom=apagar, context='VERTS')
    arvore = BVHTree.FromBMesh(bm)
    bm.free()
    return arvore


def raio(arvore, z, a, centro):
    d = Vector((math.sin(a), -math.cos(a), 0))
    origem = Vector((centro.x, centro.y, z))+d*1.2
    hit = arvore.ray_cast(origem, -d, 1.2)[0]
    return (Vector((hit.x-centro.x, hit.y-centro.y))).length if hit else None


# ---------------------------------------------------------------- roupa

def faixa(arvore, centro, z_topo, base_fn, folga, alargar, a_ini=-PI, a_fim=PI, colunas=72, linhas=12,
          maximo_corrido=True, fechado=True):
    """Superfície de tecido em volta do corpo, de z_topo até base_fn(a)."""
    verts, faces = [], []
    cols = colunas if fechado else colunas+1
    for i in range(cols):
        a = a_ini+(a_fim-a_ini)*i/colunas
        r = 0.0
        base = base_fn(a)
        for k in range(linhas+1):
            z = z_topo+(base-z_topo)*k/linhas
            rb = raio(arvore, z, a, centro) or r
            r = max(r, rb) if maximo_corrido else rb
            rr = r+folga+alargar*(z_topo-z)
            verts.append(Vector((centro.x+math.sin(a)*rr, centro.y-math.cos(a)*rr, z)))
    for i in range(colunas if fechado else colunas):
        j = (i+1) % cols
        for k in range(linhas):
            faces.append((i*(linhas+1)+k, j*(linhas+1)+k, j*(linhas+1)+k+1, i*(linhas+1)+k+1))
    return verts, faces


def roupa(pessoa, corpo, h, fem, mats):
    arvore = bvh_sem_bracos(corpo)
    vs = [v.co for v in corpo.data.vertices]
    cintura = .556*h
    faixa_q = [p for p in vs if abs(p.z-cintura) < .02 and abs(p.x) < .2*h/1.83]
    centro = Vector((0, sum(p.y for p in faixa_q)/len(faixa_q), 0))
    pecas = []
    # Camada de folha: anel inteiro até meia coxa, barra levemente ondulada.
    base_folha = lambda a: .425*h+.012*math.sin(3*a)
    v, f = faixa(arvore, centro, cintura, base_folha, .010, .07)
    pecas.append((v, f, 1))
    # Terracota: envolve quase toda a volta e cruza na frente com ponta diagonal.
    ponta = .32
    def base_terracota(a):
        curta = .445*h
        longa = .372*h
        return curta-(curta-longa)*max(0.0, 1-abs(a-ponta)/1.05)**1.6
    v, f = faixa(arvore, centro, cintura+.004, base_terracota, .018, .085, a_ini=-2.25, a_fim=2.55, fechado=False)
    pecas.append((v, f, 0))
    o = objeto(pessoa.name+'_Saia', *juntar(pecas)[:2], [mats['terracota'], mats['folha']], juntar(pecas)[2], pessoa)
    aplicar(o, ('SOLIDIFY', {'thickness': .006, 'offset': -1}), ('SUBSURF', {'levels': 1, 'render_levels': 1}))
    # Cinto de corda com nó e duas pontas.
    pts = []
    for i in range(48):
        a = 2*PI*i/48
        r = (raio(arvore, cintura+.006, a, centro) or .15)+.026
        pts.append(Vector((math.sin(a)*r, centro.y-math.cos(a)*r, cintura+.006)))
    lista = [tubo(pts, [.0075]*48, 8, True)+(0,)]
    no = pts[0]+Vector((0, -.006, 0))
    lista.append(esfera(no, (.016, .013, .015), 12, 8)+(0,))
    for lado in (1, -1):
        caminho = [no+Vector((lado*.004, -.004, -.006)), no+Vector((lado*.012, -.010, -.07)), no+Vector((lado*.018, -.012, -.135))]
        lista.append(tubo(caminho, [.0055, .005, .0045], 8)+(0,))
        lista.append(esfera(caminho[-1]+Vector((0, 0, -.012)), (.008, .008, .016), 10, 6)+(0,))
    vs_c, fs_c, ids = juntar(lista)
    objeto(pessoa.name+'_Corda', vs_c, fs_c, [mats['corda']], ids, pessoa)
    if fem:
        busto = min((p for p in vs if .68*h < p.z < .80*h and abs(p.x) < .1*h), key=lambda p: p.y)
        z0, z1 = busto.z+.058, busto.z-.07
        listras = lambda a: z1
        v, f = faixa(arvore, centro, z0, listras, .007, .0, linhas=10)
        indices = []
        for i in range(72):
            for k in range(10):
                indices.append(1 if k in (1, 8) else 0)
        o = objeto(pessoa.name+'_Top', v, f, [mats['top'], mats['top_listra']], indices, pessoa)
        aplicar(o, ('SOLIDIFY', {'thickness': .005, 'offset': -1}), ('SUBSURF', {'levels': 1, 'render_levels': 1}))


# ---------------------------------------------------------------- cabelo

def cabelo(pessoa, corpo, olhos_z, h, fem, estilo, mat):
    arvore = BVHTree.FromObject(corpo, bpy.context.evaluated_depsgraph_get())
    vs = [v.co for v in corpo.data.vertices]
    cabeca = [p for p in vs if p.z > olhos_z-.02]
    c = Vector((0, (min(p.y for p in cabeca)+max(p.y for p in cabeca))/2+.005, olhos_z+.035))
    comprido = {'longo': (.40 if fem else .26), 'ombros': .17, 'franja': .36, 'curto': .045,
                'coque': .045, 'tranca': .06, 'rabo': .06}[estilo]
    preso = estilo in ('coque', 'tranca', 'rabo')
    colunas, linhas = 80, 30
    grade = []
    for i in range(colunas):
        a = 2*PI*i/colunas-PI
        d = Vector((math.sin(a), -math.cos(a), 0))
        frente = suave(1.2, .62, abs(a))          # 1 no rosto, 0 nas laterais/nuca
        lateral = suave(.55, 1.35, abs(a))          # cresce para trás
        # Linha do cabelo: testa com risca lateral; laterais descem até o fim do cabelo.
        risca = .012*math.sin(a+.6)
        testa = olhos_z+(.058 if estilo == 'franja' else .084)+risca-.05*(abs(a)/1.2)**2
        testa -= .009*abs(math.sin(a*13))   # pontas de mecha na linha da testa
        fim = olhos_z-comprido*(.55+.45*lateral)-.02*math.sin(9*a+i*.7)*(0 if preso else 1)
        if preso:
            fim = olhos_z-.055-.05*lateral
        parada = fim+(testa-fim)*frente
        espessura = (.007 if preso else .010)+(.008 if estilo == 'franja' and frente > .5 else 0)
        coluna = []
        phi = 0.0
        while phi <= math.radians(94):
            direcao = (math.sin(phi)*d+math.cos(phi)*Vector((0, 0, 1))).normalized()
            hit = arvore.ray_cast(c+direcao*.5, -direcao, .5)[0]
            if hit is None:
                break
            p = hit+direcao*(espessura+.006*math.sin(phi))
            if p.z < parada:
                break
            coluna.append(p)
            phi += math.radians(3)
        # Mechas caindo retas, sempre por fora de pescoço e ombros.
        p = coluna[-1].copy()
        passos = 0
        while p.z-.02 > parada and passos < 60:
            passos += 1
            p = p+Vector((0, 0, -.02))
            # Abaixo do pescoço as mechas laterais giram para as costas (caem por
            # trás dos ombros, não por cima deles) e pousam a 1,6 cm da pele.
            descida = suave(0, .14, (olhos_z-.09)-p.z)
            a_ef = a+math.copysign((PI-abs(a))*.6*descida, a) if abs(a) > .45 else a
            dirh = Vector((math.sin(a_ef), -math.cos(a_ef), 0))
            horiz = Vector((p.x-c.x, p.y-c.y, 0))
            alvo_hit = arvore.ray_cast(Vector((c.x, c.y, p.z))+dirh*.6, -dirh, .6)[0]
            if alvo_hit is not None:
                alvo_r = Vector((alvo_hit.x-c.x, alvo_hit.y-c.y, 0)).length+.016
                novo_r = horiz.length+(alvo_r-horiz.length)*.45
                p = Vector((c.x, c.y, p.z))+horiz.normalized().lerp(dirh, .35).normalized()*novo_r
            perto, normal, _, dist = arvore.find_nearest(p)
            if perto is not None and (p-perto).dot(normal) < .016:
                # Empurra só na horizontal: no ombro a normal aponta para cima
                # e prenderia a mecha no lugar.
                lado = Vector((normal.x, normal.y, 0))
                lado = lado.normalized() if lado.length > 1e-4 else d
                fora = Vector((p.x-perto.x, p.y-perto.y, 0)).dot(lado)
                p = p+lado*max(0.0, .016-fora)
            coluna.append(p.copy())
        if coluna[-1].z > parada and len(coluna) > 1:
            fimp = coluna[-1].copy()
            fimp.z = parada
            coluna.append(fimp)
        # Reamostra por comprimento para todas as colunas terem as mesmas linhas.
        acum = [0.0]
        for k in range(1, len(coluna)):
            acum.append(acum[-1]+(coluna[k]-coluna[k-1]).length)
        total = acum[-1] or 1
        res = []
        for k in range(linhas+1):
            alvo = total*k/linhas
            j = max(0, min(len(acum)-2, next((j for j in range(len(acum)-1) if acum[j+1] >= alvo), len(acum)-2)))
            t = (alvo-acum[j])/max(1e-6, acum[j+1]-acum[j])
            q = coluna[j].lerp(coluna[j+1], t)
            # Mechas: leve relevo alternado na parte solta.
            solto = k/linhas
            q += d*(.006*abs(math.sin(a*6.5))*solto*(0 if preso else 1))
            res.append(q)
        grade.append(res)
    verts = [p for col in grade for p in col]
    faces = []
    for i in range(colunas):
        j = (i+1) % colunas
        for k in range(linhas):
            faces.append((i*(linhas+1)+k, j*(linhas+1)+k, j*(linhas+1)+k+1, i*(linhas+1)+k+1))
    pecas = [(verts, faces, 0)]
    nuca = c+Vector((0, .095, -.005))
    if estilo == 'coque':
        pecas.append(esfera(c+Vector((0, .088, .055)), (.048, .044, .042), 16, 10)+(0,))
        pecas.append(tubo([c+Vector((0, .070, .045)), c+Vector((0, .098, .060))], [.03, .03], 12)+(0,))
    if estilo == 'rabo':
        base = c+Vector((0, .105, .035))
        caminho = [base, base+Vector((0, .04, -.03)), base+Vector((0, .055, -.13)), base+Vector((0, .05, -.26)),
                   base+Vector((0, .035, -.38))]
        pecas.append(tubo(caminho, [.028, .034, .030, .022, .006], 12)+(0,))
        pecas.append(esfera(base, (.03, .022, .03), 12, 8)+(0,))
    if estilo == 'tranca':
        inicio = c+Vector((.085, .06, -.06))
        for k in range(15):
            t = k/14
            p = inicio+Vector((.035*math.sin(t*1.2), -.10*math.sin(t*1.4), -.40*t))
            perto, normal, _, _ = arvore.find_nearest(p)
            if perto is not None and (p-perto).dot(normal) < .03:
                p = perto+normal*.03
            r = .026*(1-.45*t)
            p += Vector((.006*(1 if k % 2 else -1), 0, 0))
            pecas.append(esfera(p, (r, r*.85, r*1.25), 12, 8)+(0,))
    v, f, ids = juntar(pecas)
    o = objeto(pessoa.name+'_Cabelo', v, f, [mat], ids, pessoa)
    # Une o polo do topo (todas as colunas nascem no mesmo ponto).
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=.0015)
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    aplicar(o, ('SOLIDIFY', {'thickness': .007, 'offset': -1}), ('SUBSURF', {'levels': 1, 'render_levels': 1}))
    for p in o.data.polygons:
        p.use_smooth = True


# ---------------------------------------------------------------- montagem

def variar(doador, fem, indice, perfil):
    altura, largura, estilo, pele = perfil
    tag = ('mulher' if fem else 'homem')+'_%02d' % (indice+1)
    pessoa = bpy.data.objects.new(tag, None)
    CENA.collection.objects.link(pessoa)
    pecas = {}
    for filho in doador.children:
        if filho.type != 'MESH' or filho.name.endswith('_CabeloRostoRoupa'):
            continue
        o = filho.copy()
        o.data = filho.data.copy()
        for m in list(o.modifiers):
            o.modifiers.remove(m)
        CENA.collection.objects.link(o)
        o.parent = pessoa
        o.matrix_parent_inverse = Matrix.Identity(4)
        o.matrix_basis = Matrix.Identity(4)
        pecas[filho.name] = o
    corpo = next(o for n, o in pecas.items() if n.endswith('_Anatomia'))
    corpo.name = tag+'_Anatomia'
    h0 = max(v.co.z for v in corpo.data.vertices)
    pescoco = .86*h0
    for o in pecas.values():
        for v in o.data.vertices:
            x, y, z = v.co
            w = 1+largura*(1-suave(pescoco-.06, pescoco, z))
            v.co = Vector((x*w*altura, y*w*altura, z*altura))
        o.data.update()
    h = h0*altura
    pele_mat = material(tag+'_Pele', pele, .62)
    corpo.data.materials.clear()
    corpo.data.materials.append(pele_mat)
    baixar_bracos(corpo, h)
    olhos = [o for n, o in pecas.items() if '.eye.' in n]
    olhos_z = sum(sum(v.co.z for v in o.data.vertices)/len(o.data.vertices) for o in olhos)/len(olhos)
    cor_cabelo = '3b2f25' if estilo == 'ombros' else '231b16'
    mats = {'terracota': material('SaiaTerracota', 'b2552f', .85), 'folha': material('SaiaFolha', '6f7c35', .85),
            'corda': material('FibraCorda', 'd3b06e', .9), 'top': material('TecidoTop', '73823a', .85),
            'top_listra': material('TecidoTopListra', '4f5b27', .85)}
    roupa(pessoa, corpo, h, fem, mats)
    cabelo(pessoa, corpo, olhos_z, h, fem, estilo, material('Cabelo_'+tag, cor_cabelo, .55, .06))
    return tag, pessoa, corpo, h


def exportar(tag, pessoa, h):
    bpy.ops.object.select_all(action='DESELECT')
    partes = [o for o in pessoa.children if o.type == 'MESH']
    copias = []
    for o in partes:
        c = o.copy()
        c.data = o.data.copy()
        CENA.collection.objects.link(c)
        c.parent = None
        c.matrix_world = Matrix.Identity(4)
        copias.append(c)
    for c in copias:
        c.select_set(True)
    bpy.context.view_layer.objects.active = copias[0]
    bpy.ops.object.join()
    malha = copias[0]
    malha.name = tag+'_corpo'
    grupo = malha.vertex_groups.get('braco')
    pesos = {}
    if grupo:
        for v in malha.data.vertices:
            for g in v.groups:
                if g.group == grupo.index:
                    pesos[v.index] = g.weight
    malha.shape_key_add(name='Basis')
    for pose in ['Passo_E', 'Passo_D', 'Coletar']:
        chave = malha.shape_key_add(name=pose)
        for i, vert in enumerate(chave.data):
            x, y, z = vert.co
            u = z/h
            lado = 1 if x >= 0 else -1
            braco = pesos.get(i, 0.0)
            if pose == 'Coletar':
                inclina = max(0, u-.50)
                vert.co.y -= inclina*.48
                vert.co.z -= inclina*.18
                vert.co.y -= .14*braco*suave(.40, .62, u)
            else:
                s = lado*(1 if pose == 'Passo_E' else -1)
                if u < .49 and braco < .5:
                    passo = (.49-u)/.49
                    vert.co.y += s*.21*passo
                    vert.co.z += .026*passo*(s+1)*.5
                elif braco > 0:
                    vert.co.y -= s*.12*braco*min(1, (.81-u)/.30)
    for m in malha.data.materials:
        pass
    bpy.ops.object.select_all(action='DESELECT')
    malha.select_set(True)
    bpy.context.view_layer.objects.active = malha
    bpy.ops.export_scene.gltf(filepath=str(SAIDA/(tag+'.glb')), use_selection=True, export_animations=False,
                              export_morph=True, export_morph_normal=False, export_yup=True)
    print('EXPORTADO', tag, len(malha.data.vertices), 'vertices', len(malha.data.polygons), 'faces')
    bpy.data.objects.remove(malha, do_unlink=True)


doadores = {False: bpy.data.objects['Morador_Revisao2'], True: bpy.data.objects['Moradora_Revisao2']}
familia = []
for fem in (False, True):
    for i, perfil in enumerate(PERFIS[fem]):
        tag, pessoa, corpo, h = variar(doadores[fem], fem, i, perfil)
        exportar(tag, pessoa, h)
        familia.append((fem, i, pessoa))
for d in doadores.values():
    for o in list(d.children)+[d]:
        bpy.data.objects.remove(o, do_unlink=True)

# Fonte editável e renders de revisão.
camera = CENA.camera
for fem, i, p in familia:
    p.location.x = (i-1.5)*.9
for sexo, nome in [(False, 'homens'), (True, 'mulheres')]:
    for fem, i, p in familia:
        p.hide_render = fem != sexo
        for c in p.children:
            c.hide_render = fem != sexo
    alvo = Vector((0, 0, .95))
    camera.location = alvo+Vector((-.6, -8, .9))
    camera.rotation_euler = (alvo-camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.ortho_scale = 4.1
    CENA.render.resolution_x = 1100
    CENA.render.resolution_y = 650
    CENA.render.filepath = str(REVISAO/(nome+'.png'))
    with bpy.context.temp_override(scene=CENA):
        bpy.ops.render.render(write_still=True, scene=CENA.name)
# Close de rosto/cabelo da dupla principal.
for fem, i, p in familia:
    p.hide_render = i != 0
    for c in p.children:
        c.hide_render = i != 0
    if i == 0:
        p.location.x = -.32 if not fem else .32
alvo = Vector((0, 0, 1.45))
camera.location = alvo+Vector((-.3, -8, .25))
camera.rotation_euler = (alvo-camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.ortho_scale = 1.25
CENA.render.resolution_x = 1000
CENA.render.resolution_y = 650
CENA.render.filepath = str(REVISAO/'rostos.png')
with bpy.context.temp_override(scene=CENA):
    bpy.ops.render.render(write_still=True, scene=CENA.name)
for fem, i, p in familia:
    p.hide_render = False
    for c in p.children:
        c.hide_render = False
    p.location.x = (i-1.5)*.9+(1.9 if fem else -1.9)
bpy.data.libraries.write(str(RAIZ/'art/blender/moradores_1500_v4.blend'), {CENA}, fake_user=True, compress=True)
print('FAMILIA V4 PRONTA')
