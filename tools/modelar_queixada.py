"""Queixada (Tayassu pecari) — modelo orgânico, rig e materiais.

Uso: blender --background --factory-startup --python tools/modelar_queixada.py
Grava art/blender/queixada.blend (cena 'Queixada', raiz vazia + rig + malha). As
animações e a exportação GLB ficam em tools/animar_capivara.py -- queixada.

Referência (guia de mamíferos do ICMBio e ilustrações da WCS Brasil): cabeça e corpo de
0,75–1,0 m, 0,44–0,58 m na cernelha, 25–40 kg; corpo em barril, cabeça
triangular, pescoço curto, olhos pequenos, focinho em disco, pernas finas com
cascos; pelagem grossa marrom-escura a preta, crina dorsal eriçável, mandíbula
e lábios brancos, caninos aparentes sob o lábio.

Forma: corpo, pescoço e cabeça por lofting do perfil lateral, pernas tubulares com
articulações; tudo fundido por voxel numa só superfície e suavizado; crina de cerdas sobre a linha do
dorso; relevo leve de pelo. Cores por vértice (pós-importador do Godot ativa).
Frente = −Y, solo em z = 0. Ossos com os mesmos nomes da capivara.
"""
import bpy, bmesh, math, random
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
from mathutils.bvhtree import BVHTree

RAIZ = Path(__file__).resolve().parents[1]
rng = random.Random(1500)


def suave(a, b, x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3-2*t)


def dist_seg(p, a, b):
    d = b-a
    t = max(0.0, min(1.0, (p-a).dot(d)/max(d.length_squared, 1e-9)))
    return (p-a-d*t).length


def linear(hexa):
    c = [int(hexa[i:i+2], 16)/255 for i in (0, 2, 4)]
    return Vector([((v+.055)/1.055)**2.4 if v > .04045 else v/12.92 for v in c])


cena = bpy.data.scenes.new('Queixada')
bpy.context.window.scene = cena


def contexto(o):
    return bpy.context.temp_override(scene=cena, object=o, active_object=o, selected_objects=[o],
                                     selected_editable_objects=[o], view_layer=cena.view_layers[0])


# ---------------------------------------------------------------- forma
# Corpo, pescoço e cabeça: um lofting ao longo de −Y com o perfil lateral da
# espécie (y, meia largura, z do topo, z da base). A cabeça triangular desce em
# linha reta da testa ao disco do focinho.
PERFIL = [(.26, .143, .508, .283), (.20, .16, .520, .263), (.08, .173, .530, .241), (-.04, .175, .551, .235),
          (-.13, .170, .564, .236), (-.21, .154, .552, .252), (-.28, .134, .532, .286), (-.34, .121, .517, .288),
          (-.40, .113, .486, .277), (-.45, .096, .434, .282), (-.49, .077, .399, .291), (-.532, .059, .372, .298),
          (-.561, .051, .361, .300), (-.583, .040, .353, .306)]
# Garupa arredondada: calota que se fecha ao longo de 14 cm atrás do pernil.
GARUPA = []
for k in range(8, 0, -1):
    f = k/8
    esc = math.sqrt(max(0.0, 1-f**2.2))
    zc, meia = (.508+.283)/2-.027*f, (.508-.283)/2
    GARUPA.append((.26+.13*f, .143*max(esc, .05), zc+meia*max(esc, .05), zc-meia*max(esc, .05)))
PERFIL = GARUPA+PERFIL
# Pernas: (x, y, z, raio) da escápula/pernil ao casco; articulações marcadas.
PERNA_FRENTE = [(.074, -.15, .37, .062), (.074, -.152, .26, .043), (.074, -.155, .19, .031), (.074, -.156, .15, .021),
                (.074, -.157, .085, .019), (.074, -.16, .055, .02), (.074, -.168, .03, .021), (.074, -.182, .007, .017)]
PERNA_TRAS = [(.08, .20, .38, .088), (.08, .215, .28, .062), (.08, .238, .195, .039), (.08, .25, .145, .028),
              (.08, .243, .10, .02), (.08, .234, .056, .019), (.08, .226, .03, .021), (.08, .211, .007, .017)]


def loft(secoes, lados=40):
    """secoes: [(centro Vector, eixo_largura Vector, eixo_altura Vector, a, b)] -> malha fechada."""
    vs, fs = [], []
    for c, u, w, a, b in secoes:
        for i in range(lados):
            t = 2*math.pi*i/lados
            vs.append(c+u*math.sin(t)*a+w*math.cos(t)*b)
    n = len(secoes)
    for j in range(n-1):
        for i in range(lados):
            k = (i+1) % lados
            fs.append((j*lados+i, (j+1)*lados+i, (j+1)*lados+k, j*lados+k))
    vs.append(secoes[0][0])
    vs.append(secoes[-1][0])
    a0, a1 = len(vs)-2, len(vs)-1
    for i in range(lados):
        fs.append((a0, (i+1) % lados, i))
        fs.append((a1, (n-1)*lados+i, (n-1)*lados+(i+1) % lados))
    return vs, fs


partes = []
secoes = []
for y, hw, zt, zb in PERFIL:
    secoes.append((Vector((0, y, (zt+zb)/2)), Vector((1, 0, 0)), Vector((0, 0, 1)), hw, (zt-zb)/2))
partes.append(loft(secoes))
for s in (1, -1):
    for perna in (PERNA_FRENTE, PERNA_TRAS):
        pts = [Vector((s*x, y, z)) for x, y, z, _ in perna]
        sec = []
        for i, (p, (_, _, _, r)) in enumerate(zip(pts, perna)):
            d = (pts[min(len(pts)-1, i+1)]-pts[max(0, i-1)]).normalized()
            u = Vector((1, 0, 0))
            u = (u-d*u.dot(d)).normalized()
            w = d.cross(u).normalized()
            sec.append((p, u, w, r, r*(1.15 if i >= len(pts)-2 else 1.0)))
        partes.append(loft(sec, 14))
vs, fs = [], []
for pv, pf in partes:
    base = len(vs)
    vs += [tuple(v) for v in pv]
    fs += [tuple(i+base for i in f) for f in pf]
malha = bpy.data.meshes.new('Queixada_Malha')
malha.from_pydata(vs, [], fs)
malha.update()
corpo = bpy.data.objects.new('Queixada_Malha', malha)
cena.collection.objects.link(corpo)

# Refaz a superfície (topologia uniforme), suaviza e reduz para o jogo.
with contexto(corpo):
    m = corpo.modifiers.new('Remesh', 'REMESH')
    m.mode = 'VOXEL'
    m.voxel_size = .006
    bpy.ops.object.modifier_apply(modifier=m.name)
    m = corpo.modifiers.new('Suave', 'SMOOTH')
    m.factor = .5
    m.iterations = 6
    bpy.ops.object.modifier_apply(modifier=m.name)
# Relevo leve de pelo grosso (ao longo da normal), mais forte no dorso.
bm = bmesh.new()
bm.from_mesh(corpo.data)
bm.normal_update()
tex_seed = [rng.uniform(0, 100) for _ in range(6)]
for v in bm.verts:
    p = v.co
    ruido = (math.sin(p.x*91+tex_seed[0])*math.sin(p.y*87+tex_seed[1])*math.sin(p.z*95+tex_seed[2])
             + .6*math.sin(p.x*173+tex_seed[3])*math.sin(p.y*181+tex_seed[4])*math.sin(p.z*167+tex_seed[5]))
    dorso = suave(.35, .52, p.z)*suave(-.50, -.42, p.y)
    pele = suave(.08, .2, p.z)*suave(-.56, -.50, p.y)
    v.co += v.normal*ruido*(.0007+.0015*dorso)*pele
bm.to_mesh(corpo.data)
bm.free()
with contexto(corpo):
    m = corpo.modifiers.new('Reduzir', 'DECIMATE')
    m.ratio = .22
    bpy.ops.object.modifier_apply(modifier=m.name)
for p in corpo.data.polygons:
    p.use_smooth = True

arvore = BVHTree.FromObject(corpo, bpy.context.evaluated_depsgraph_get())


def no_corpo(origem, direcao):
    hit = arvore.ray_cast(Vector(origem), Vector(direcao).normalized(), 2)[0]
    return hit


# ---------------------------------------------------------------- detalhes

pecas = []   # (verts, faces, cor_hex, material 0 corpo / 1 olho)


def cone(base, ponta, r, seg=8, achata=1.0, eixo_achata=None):
    base, ponta = Vector(base), Vector(ponta)
    d = (ponta-base).normalized()
    u = d.orthogonal().normalized() if eixo_achata is None else (Vector(eixo_achata)-d*d.dot(Vector(eixo_achata))).normalized()
    w = d.cross(u)
    vs = [base+(u*math.cos(2*math.pi*i/seg)*achata+w*math.sin(2*math.pi*i/seg))*r for i in range(seg)]+[ponta]
    fs = [(i, (i+1) % seg, seg) for i in range(seg)]+[tuple(reversed(range(seg)))]
    return vs, fs


def elipsoide(c, raios, seg=16, aneis=8, giro=None):
    c = Vector(c)
    escala = Vector(raios)
    giro = giro or Matrix.Identity(3)
    def ponto(x, y, z):
        return c+giro@Vector((x*escala.x, y*escala.y, z*escala.z))
    vs = [ponto(0, 0, 1)]
    for j in range(1, aneis):
        th = math.pi*j/aneis
        for i in range(seg):
            ph = 2*math.pi*i/seg
            vs.append(ponto(math.sin(th)*math.cos(ph), math.sin(th)*math.sin(ph), math.cos(th)))
    vs.append(ponto(0, 0, -1))
    fs = []
    for i in range(seg):
        fs.append((0, 1+i, 1+(i+1) % seg))
    for j in range(aneis-2):
        for i in range(seg):
            a = 1+j*seg+i
            b = 1+j*seg+(i+1) % seg
            fs.append((a, a+seg, b+seg, b))
    ult = len(vs)-1
    base = 1+(aneis-2)*seg
    for i in range(seg):
        fs.append((ult, base+(i+1) % seg, base+i))
    return vs, fs


def orelha(centro, lado):
    """Concha arredondada com interior rebaixado, orientada para frente e para fora."""
    eixo = Vector((1, lado*.30, -lado*.43)).normalized()
    frente = Vector((lado*.30, -1, .07)).normalized()
    alto = frente.cross(eixo).normalized()
    eixo = alto.cross(frente).normalized()
    formas = [(1, .0), (.88, .009), (.61, .005), (.30, -.004)]
    vs, fs = [], []
    n = 14
    for escala, prof in formas:
        for i in range(n):
            angulo = math.tau*i/n
            vs.append(centro+escala*(eixo*.025*math.cos(angulo)+alto*.038*math.sin(angulo))+frente*prof)
    for j in range(len(formas)-1):
        fs.extend((j*n+i, j*n+(i+1)%n, (j+1)*n+(i+1)%n, (j+1)*n+i) for i in range(n))
    # A base traseira fica embutida na cabeça.
    pecas.append((vs, fs[:n], '312d2b', 0))
    pecas.append((vs, fs[n:]+[tuple(range(3*n, 4*n))], '796859', 0))
    pecas.append(elipsoide(centro-frente*.003, (.024,.011,.036), giro=Matrix((eixo, -frente, alto)).transposed())+('35302e', 0))


giro_disco = Matrix.Rotation(math.radians(-16), 3, 'X')
disco = Vector((0, -.578, .330))
vs_disco, faces_disco = elipsoide(Vector(), (.051, .020, .030), 48, 24)
def mascara_narina(p):
    if p.y > -.010:
        return 0.0
    return math.exp(-((abs(p.x)-.022)/.010)**2-((p.z-.003)/.006)**2)

def cor_disco(p):
    return linear('62534f').lerp(linear('2a2322'), suave(.10, .82, mascara_narina(p)))

cores_disco = [cor_disco(p) for p in vs_disco]
vs_disco = [disco+giro_disco@(p+Vector((0, .006*mascara_narina(p), 0))) for p in vs_disco]
pecas.append((vs_disco, faces_disco, cores_disco, 0))
for s in (1, -1):
    raiz_orelha = no_corpo((s*.074, -.331, .8), (0, 0, -1)) or Vector((s*.074, -.331, .49))
    orelha(raiz_orelha+Vector((s*.004, .004, .014)), s)
    olho = no_corpo((s*.5, -.425, .412), (-s, 0, 0)) or Vector((s*.08, -.425, .412))
    pecas.append(elipsoide(olho-Vector((s*.003, 0, 0)), (.008, .015, .010))+('352d29', 0))
    pecas.append(elipsoide(olho+Vector((s*.002, 0, 0)), (.006, .009, .0065))+('201610', 1))
    canino = no_corpo((s*.4, -.512, .308), (-s, 0, 0)) or Vector((s*.048, -.512, .308))
    pecas.append(cone(canino+Vector((-s*.003, 0, -.007)), canino+Vector((s*.006, -.002, .014)), .0045, 7)+('dfd4b9', 0))
    # Dois dedos dianteiros por casco, com sulco e bico voltado para frente.
    for perna in (PERNA_FRENTE, PERNA_TRAS):
        x, y, _, _ = perna[-1]
        for dedo in (-1, 1):
            pecas.append(elipsoide((s*x+dedo*.010, y-.006, .017), (.009, .026, .017), 10, 5)+('2a2522', 0))

# Crina de cerdas: cristas finas sobre a linha do dorso, mais altas na cernelha.
amostras = []
y = -.30
while y < .2:
    topo = no_corpo((0, y, .9), (0, 0, -1))
    if topo:
        amostras.append(topo)
    y += .010
for i, t in enumerate(amostras):
    s_i = i/(len(amostras)-1)
    altura = (.013+.019*math.exp(-((t.y+.12)/.15)**2))*suave(0,.13,s_i)*(1-suave(.67, 1, s_i))*(.75+.5*rng.random())
    for lado in (-1, 1):
        base = t+Vector((lado*rng.uniform(.004, .012), 0, -.008))
        ponta = t+Vector((lado*rng.uniform(.006, .02), rng.uniform(.014, .04), altura))
        pecas.append(cone(base, ponta, .005, 5, .65, (1, 0, 0))+('38322e' if rng.random() < .7 else '64574c', 0))

# ---------------------------------------------------------------- cores do corpo

base_escura = linear('34312e')
grisalho = linear('655b51')
branco = linear('ded6c5')
casco = linear('1c1815')
ventre = linear('4e4239')
perna = linear('2c2520')
cor = corpo.data.color_attributes.new(name='Cor', type='FLOAT_COLOR', domain='POINT')
for v in corpo.data.vertices:
    p = v.co
    pelo = .5+.5*math.sin(p.x*91+p.y*23)*math.sin(p.y*47+p.z*55)
    luz_dorso = suave(.30, .56, p.z)
    c = base_escura.lerp(grisalho, .18+.42*luz_dorso+.20*pelo)
    c = c.lerp(ventre, suave(.33, .27, p.z)*(1-suave(.05, .09, abs(p.x)))*(1-suave(-.25, -.3, p.y)))
    c = c.lerp(perna, suave(.27, .2, p.z)*suave(.05, .07, abs(p.x)))
    # Mandíbula e lábios brancos (o nome "queixada" vem do queixo), com borda suave.
    limite_bochecha = .342+.044*suave(-.53, -.405, p.y)
    queixo = suave(-.37, -.46, p.y)*suave(limite_bochecha+.015, limite_bochecha-.012, p.z)
    c = c.lerp(branco, queixo*.92)
    sulco = (1-suave(.002, .008, abs(p.z-(.300+.045*suave(-.59,-.44,p.y)))))*suave(-.43,-.49,p.y)*suave(-.608,-.582,p.y)
    c = c.lerp(linear('51433c'), sulco*.78)
    c = c.lerp(casco, suave(.055, .035, p.z))
    cor.data[v.index].color = (c.x, c.y, c.z, 1.0)

# Junta os detalhes com as próprias cores.
bm = bmesh.new()
bm.from_mesh(corpo.data)
camada = bm.verts.layers.float_color.get('Cor')
for vs, fs, hexa, mat in pecas:
    usados = sorted({i for f in fs for i in f})
    novos = {i: bm.verts.new(vs[i]) for i in usados}
    cor_fixa = linear(hexa) if isinstance(hexa, str) else None
    for i, nv in novos.items():
        cc = cor_fixa if cor_fixa is not None else hexa[i]
        nv[camada] = (cc.x, cc.y, cc.z, 1.0)
    for f in fs:
        try:
            face = bm.faces.new([novos[i] for i in f])
            face.material_index = mat
            face.smooth = True
        except ValueError:
            pass
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bm.to_mesh(corpo.data)
bm.free()

pele = bpy.data.materials.new('Queixada_Cores')
pele.use_nodes = True
bs = next(n for n in pele.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bs.inputs['Roughness'].default_value = .88
if 'Specular IOR Level' in bs.inputs:
    bs.inputs['Specular IOR Level'].default_value = .25
vc = pele.node_tree.nodes.new('ShaderNodeVertexColor')
vc.layer_name = 'Cor'
pele.node_tree.links.new(vc.outputs['Color'], bs.inputs['Base Color'])
olho = bpy.data.materials.new('Queixada_Olho')
olho.use_nodes = True
bo = next(n for n in olho.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bo.inputs['Base Color'].default_value = (.01, .008, .007, 1)
bo.inputs['Roughness'].default_value = .15
vo = olho.node_tree.nodes.new('ShaderNodeVertexColor')
vo.layer_name = 'Cor'
olho.node_tree.links.new(vo.outputs['Color'], bo.inputs['Base Color'])
corpo.data.materials.append(pele)
corpo.data.materials.append(olho)

# ---------------------------------------------------------------- rig e pesos

raiz = bpy.data.objects.new('Queixada', None)
cena.collection.objects.link(raiz)
arm = bpy.data.armatures.new('Esqueleto_queixada')
rig = bpy.data.objects.new('Rig_queixada', arm)
cena.collection.objects.link(rig)
rig.parent = raiz
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
if True:
    bpy.ops.object.mode_set(mode='EDIT')
    def osso(nome, a, b, pai=None):
        o = arm.edit_bones.new(nome)
        o.head, o.tail = a, b
        if pai:
            o.parent = arm.edit_bones[pai]
    osso('raiz', (0, 0, 0), (0, 0, .15))
    osso('tronco', (0, .27, .41), (0, -.20, .44), 'raiz')
    osso('pescoco', (0, -.20, .44), (0, -.33, .43), 'tronco')
    osso('cabeca', (0, -.33, .43), (0, -.60, .31), 'pescoco')
    PERNAS = {}
    for lado, s in (('E', 1), ('D', -1)):
        x = s*.072
        PERNAS[('frente', lado)] = [Vector((x, -.15, .37)), Vector((x, -.155, .19)), Vector((x, -.158, .055)), Vector((x, -.19, .008))]
        PERNAS[('tras', lado)] = [Vector((x, .20, .37)), Vector((x, .245, .17)), Vector((x, .232, .055)), Vector((x, .20, .008))]
        for membro in ('frente', 'tras'):
            a, b, c, d = PERNAS[(membro, lado)]
            osso('%s_%s' % (membro, lado), a, b, 'raiz')
            osso('%s_canela_%s' % (membro, lado), b, c, '%s_%s' % (membro, lado))
            osso('%s_pe_%s' % (membro, lado), c, d, '%s_canela_%s' % (membro, lado))
    bpy.ops.object.mode_set(mode='OBJECT')

for b in arm.bones:
    corpo.vertex_groups.new(name=b.name)
G = corpo.vertex_groups
for v in corpo.data.vertices:
    p = v.co
    if p.z < .038:
        membro = 'frente' if p.y < 0 else 'tras'
        lado = 'E' if p.x > 0 else 'D'
        G[f'{membro}_pe_{lado}'].add([v.index], 1.0, 'REPLACE')
        continue
    pesos = {}
    perna_total = 0.0
    for lado, s in (('E', 1), ('D', -1)):
        if p.x*s < .015:
            continue
        for membro in ('frente', 'tras'):
            a, b, c, d = PERNAS[(membro, lado)]
            ds = [dist_seg(p, a, b), dist_seg(p, b, c), dist_seg(p, c, d)]
            alcance = .08 if membro == 'tras' else .062
            w = (1-suave(alcance*.55, alcance, min(ds)))*suave(.42, .30, p.z)
            if p.z < .3:
                w = max(w, 1-suave(.045, .075, min(ds)))
            if w <= 0:
                continue
            inv = [1/(x+.004)**8 for x in ds]   # articulações definidas, sem 'borracha'
            tot = sum(inv)
            for nome, wi in zip(('%s_%s', '%s_canela_%s', '%s_pe_%s'), inv):
                pesos[nome % (membro, lado)] = pesos.get(nome % (membro, lado), 0)+w*wi/tot
            perna_total += w
    if perna_total > 1:
        for k in pesos:
            pesos[k] /= perna_total
        perna_total = 1
    resto = 1-perna_total
    pesc = suave(-.17, -.25, p.y)
    cab = suave(-.31, -.37, p.y)
    pesos['tronco'] = pesos.get('tronco', 0)+resto*(1-pesc)
    pesos['pescoco'] = pesos.get('pescoco', 0)+resto*(pesc-cab)
    pesos['cabeca'] = pesos.get('cabeca', 0)+resto*cab
    for nome, w in pesos.items():
        if w > .001:
            G[nome].add([v.index], w, 'REPLACE')
corpo.parent = rig
mod = corpo.modifiers.new('Deformacao', 'ARMATURE')
mod.object = rig
rig.animation_data_create()

medidas = [v.co for v in corpo.data.vertices]
print('QUEIXADA', 'vertices', len(corpo.data.vertices), 'faces', len(corpo.data.polygons),
      'comprimento', round(max(p.y for p in medidas)-min(p.y for p in medidas), 3),
      'altura', round(max(p.z for p in medidas), 3), 'largura', round(max(p.x for p in medidas)*2, 3))
bpy.data.libraries.write(str(RAIZ/'art/blender/queixada.blend'), {cena}, fake_user=True, compress=True)
print('QUEIXADA PRONTA')
