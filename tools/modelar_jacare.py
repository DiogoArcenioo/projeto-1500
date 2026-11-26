"""Jacaré-de-papo-amarelo (Caiman latirostris) — modelo orgânico detalhado, rig e cores.

Uso: blender --background --factory-startup --python tools/modelar_jacare.py
Grava art/blender/jacare.blend (cena 'Jacare': raiz vazia + rig + malha). Animações e
GLBs: tools/animar_jacare.py.

Referências (Wikipedia/IUCN CSG, ICMBio, Embrapa, Verdade & Piña): focinho mais largo
entre os crocodilianos (lati + rostris), dorso verde-oliva a acinzentado, osteodermos
dorsais bem ossificados, manchas escuras na cabeça e na nuca, papo amarelado nos adultos,
cauda com faixas escuras e crista dupla que vira simples; até 3,5 m (aqui 1,9 m, adulto
comum).

Forma: corpo, cabeça e cauda por lofting do perfil (cauda achatada lateralmente), patas
abertas com dedos (5 na mão, 4 no pé, com membrana) e garras, saliências dos olhos e das
narinas; tudo fundido por voxel e suavizado. Mandíbula separada (abre a boca). Detalhes:
osteodermos em fileiras, crista caudal, dentes, olhos com fenda, relevo de escamas.
Cores por vértice. Frente = −Y, solo em z = 0.
"""
import bpy, bmesh, math, random
from pathlib import Path
from mathutils import Vector, Quaternion
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


cena = bpy.context.scene
cena.name = 'Jacare'
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)


def contexto(o):
    return bpy.context.temp_override(object=o, active_object=o, selected_objects=[o], selected_editable_objects=[o])


def loft(secoes, lados=36, achata_base=1.0):
    """secoes: [(centro, eixo_largura, eixo_altura, a, b)]; base um pouco achatada (ventre)."""
    vs, fs = [], []
    for c, u, w, a, b in secoes:
        for i in range(lados):
            t = 2*math.pi*i/lados
            cz = math.cos(t)
            if cz < 0:
                cz = -(abs(cz)**achata_base)
            vs.append(c+u*math.sin(t)*a+w*cz*b)
    n = len(secoes)
    for j in range(n-1):
        for i in range(lados):
            k = (i+1) % lados
            fs.append((j*lados+i, (j+1)*lados+i, (j+1)*lados+k, j*lados+k))
    vs += [secoes[0][0], secoes[-1][0]]
    a0, a1 = len(vs)-2, len(vs)-1
    for i in range(lados):
        fs.append((a0, (i+1) % lados, i))
        fs.append((a1, (n-1)*lados+i, (n-1)*lados+(i+1) % lados))
    return vs, fs


def perfil(lista, lados=36, achata=1.0):
    sec = [(Vector((0, y, (zt+zb)/2)), Vector((1, 0, 0)), Vector((0, 0, 1)), hw, (zt-zb)/2) for y, hw, zt, zb in lista]
    return loft(sec, lados, achata)


def tubo(pontos, raios, lados=14, achatado=1.0):
    pts = [Vector(p) for p in pontos]
    sec = []
    for i, (p, r) in enumerate(zip(pts, raios)):
        d = (pts[min(len(pts)-1, i+1)]-pts[max(0, i-1)]).normalized()
        u = Vector((0, 0, 1))
        u = (u-d*u.dot(d))
        u = u.normalized() if u.length > 1e-4 else d.orthogonal().normalized()
        w = d.cross(u).normalized()
        sec.append((p, w, u, r, r*achatado))
    return loft(sec, lados)


def elipsoide(c, r, lados=16, aneis=10):
    c, r = Vector(c), Vector(r)
    sec = []
    for j in range(1, aneis):
        th = math.pi*j/aneis
        sec.append((c+Vector((0, -math.cos(th)*r.y, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), math.sin(th)*r.x, math.sin(th)*r.z))
    return loft(sec, lados)


def objeto(nome, partes):
    vs, fs = [], []
    for pv, pf in partes:
        base = len(vs)
        vs += [tuple(v) for v in pv]
        fs += [tuple(i+base for i in f) for f in pf]
    me = bpy.data.meshes.new(nome)
    me.from_pydata(vs, [], fs)
    me.update()
    o = bpy.data.objects.new(nome, me)
    cena.collection.objects.link(o)
    return o


def refazer(o, voxel, suavizar, reduzir):
    with contexto(o):
        m = o.modifiers.new('Remesh', 'REMESH')
        m.mode = 'VOXEL'
        m.voxel_size = voxel
        bpy.ops.object.modifier_apply(modifier=m.name)
        m = o.modifiers.new('Suave', 'SMOOTH')
        m.factor = .5
        m.iterations = suavizar
        bpy.ops.object.modifier_apply(modifier=m.name)


def decimar(o, razao):
    with contexto(o):
        m = o.modifiers.new('Reduzir', 'DECIMATE')
        m.ratio = razao
        bpy.ops.object.modifier_apply(modifier=m.name)


# ---------------------------------------------------------------- forma
# (y, meia largura, z topo, z base). Cabeça larga e achatada; a base da cabeça é a
# linha da boca (a mandíbula é outra peça). Cauda achatada lateralmente.
CORPO = [(-.905, .05, .083, .057), (-.885, .072, .09, .056), (-.85, .087, .096, .055), (-.80, .097, .101, .055),
         (-.75, .106, .109, .055), (-.71, .113, .123, .056), (-.665, .116, .132, .058),
         (-.625, .107, .128, .052), (-.57, .12, .138, .045), (-.49, .148, .153, .04), (-.37, .172, .163, .035),
         (-.23, .182, .168, .034), (-.09, .178, .166, .036), (.03, .164, .16, .043), (.11, .14, .154, .053),
         (.19, .106, .15, .063), (.31, .08, .143, .071), (.44, .062, .133, .077), (.57, .047, .121, .079),
         (.69, .034, .109, .08), (.79, .023, .099, .08), (.87, .013, .092, .081), (.915, .005, .088, .083)]
MANDIBULA = [(-.892, .044, .053, .039), (-.868, .066, .054, .034), (-.82, .084, .054, .031), (-.76, .096, .055, .03),
             (-.70, .104, .056, .033), (-.66, .107, .056, .037), (-.635, .1, .056, .044)]
# Patas abertas: ombro/quadril → cotovelo/joelho → punho/tornozelo → base dos dedos.
PATA_FRENTE = [(.11, -.47, .10, .05), (.225, -.445, .085, .036), (.235, -.515, .022, .025), (.245, -.56, .01, .022)]
PATA_TRAS = [(.11, .06, .10, .07), (.25, .0, .1, .048), (.27, .095, .025, .03), (.29, .03, .012, .026)]

partes = [perfil(CORPO, 40, .55)]
for s in (1, -1):
    for pata, dedos, comp in ((PATA_FRENTE, 5, (.045, .055, .058, .052, .04)), (PATA_TRAS, 4, (.06, .072, .07, .058))):
        pts = [Vector((s*x, y, z)) for x, y, z, _ in pata]
        partes.append(tubo(pts, [r for *_, r in pata], 16, .8))
        base = pts[-1]
        frente = (base-pts[-2])
        frente.z = 0
        frente.normalize()
        lado = Vector((0, 0, 1)).cross(frente).normalized()
        # Palma achatada e dedos em leque (pé com membrana: dedos mais juntos).
        partes.append(tubo([base-frente*.02, base+frente*.02], [.03, .03], 12, .32))
        abertura = .75 if dedos == 5 else .55
        for k in range(dedos):
            ang = (k/(dedos-1)-.5)*abertura
            d = (frente*math.cos(ang)+lado*math.sin(ang)*s).normalized()
            p0 = base+d*.015+Vector((0, 0, -.004))
            p1 = p0+d*comp[k]*.6+Vector((0, 0, -.004))
            p2 = p0+d*comp[k]+Vector((0, 0, -.006))
            partes.append(tubo([p0, p1, p2], [.0085, .007, .0045], 8, .7))
# Saliências dos olhos (órbitas elevadas) e das narinas, fundidas à cabeça.
for s in (1, -1):
    partes.append(elipsoide((s*.05, -.703, .125), (.027, .033, .021)))
partes.append(elipsoide((0, -.877, .086), (.028, .022, .014)))
corpo = objeto('Jacare_Malha', partes)
refazer(corpo, .0055, 5, None)
mand = objeto('Jacare_Mandibula', [perfil(MANDIBULA, 32, .7)])
refazer(mand, .004, 3, None)

# ---------------------------------------------------------------- relevo de escamas
fase = [rng.uniform(0, 6) for _ in range(4)]


def relevo(o, dorso_forte):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.normal_update()
    for v in bm.verts:
        p, n = v.co, v.normal
        # Placas retangulares no dorso/flancos; grade fina no ventre.
        dorsal = suave(.0, .5, n.z)
        placas = (abs(math.sin(p.y*95+fase[0]))**.35)*(abs(math.sin(p.x*95+fase[1]))**.35)
        grade = (abs(math.sin(p.y*150))**.5)*(abs(math.sin(p.x*150))**.5)
        rugas = math.sin(p.x*260+fase[2])*math.sin(p.y*240+fase[3])
        v.co += n*(dorsal*placas*dorso_forte+(1-dorsal)*grade*.0012+rugas*.0004)
    bm.to_mesh(o.data)
    bm.free()


relevo(corpo, .0032)
relevo(mand, .0012)
decimar(corpo, .2)
decimar(mand, .35)
for o in (corpo, mand):
    for p in o.data.polygons:
        p.use_smooth = True
arvore = BVHTree.FromObject(corpo, bpy.context.evaluated_depsgraph_get())


def no_corpo(origem, direcao=(0, 0, -1)):
    return arvore.ray_cast(Vector(origem), Vector(direcao).normalized(), 2)[0]


# ---------------------------------------------------------------- detalhes
detalhes = []   # (verts, faces, cor_hex, material, osso)


def cone(base, ponta, r, seg=6, achata=1.0, eixo=None):
    base, ponta = Vector(base), Vector(ponta)
    d = (ponta-base).normalized()
    u = d.orthogonal().normalized() if eixo is None else (Vector(eixo)-d*d.dot(Vector(eixo))).normalized()
    w = d.cross(u)
    vs = [base+(u*math.cos(2*math.pi*i/seg)*achata+w*math.sin(2*math.pi*i/seg))*r for i in range(seg)]+[ponta]
    fs = [(i, (i+1) % seg, seg) for i in range(seg)]+[tuple(reversed(range(seg)))]
    return vs, fs


def escudo(topo, comp, larg, alt):
    """Osteodermo com quilha: base retangular afundada e crista ao longo do corpo."""
    t = Vector(topo)
    b = [t+Vector((-larg/2, -comp/2, -.004)), t+Vector((larg/2, -comp/2, -.004)), t+Vector((larg/2, comp/2, -.004)),
         t+Vector((-larg/2, comp/2, -.004))]
    q = [t+Vector((0, -comp*.3, alt)), t+Vector((0, comp*.35, alt*.8))]
    vs = b+q
    fs = [(0, 1, 4), (1, 2, 5, 4), (2, 3, 5), (3, 0, 4, 5), (3, 2, 1, 0)]
    return vs, fs


# Osteodermos: escudos da nuca e fileiras dorsais (seis no tronco).
for y in (-.6, -.565):
    for x in (-.065, -.025, .025, .065):
        t = no_corpo((x, y, .6))
        if t:
            detalhes.append(escudo(t, .032, .03, .011)+('4f5543', 0, 'pescoco'))
y = -.5
while y < .12:
    meia = 1-suave(-.1, .12, y)*.4
    for x in (-.11, -.07, -.03, .03, .07, .11):
        if abs(x) > .12*meia+.01:
            continue
        t = no_corpo((x*meia, y+rng.uniform(-.004, .004), .6))
        if t:
            h = .0065+.003*(1-abs(x)/.11)+rng.uniform(-.0015, .0015)
            detalhes.append(escudo(t, .038, .032, h)+('545a47' if rng.random() < .6 else '6a6d55', 0, 'tronco'))
    y += .047
# Crista caudal dupla que vira simples na ponta.
y = .13
while y < .9:
    dupla = y < .55
    alt = .022+.012*suave(.13, .4, y)*(1-suave(.55, .9, y))
    xs = (-.03*(1-.5*suave(.13, .55, y)), .03*(1-.5*suave(.13, .55, y))) if dupla else (0.0,)
    for x in xs:
        t = no_corpo((x, y, .6))
        if t:
            detalhes.append(escudo(t, .034, .012 if not dupla else .016, alt*(1 if not dupla else .85))+('45493a', 0, 'cauda'))
    y += .04
# Dentes: interligados para fora da boca, visíveis com ela fechada.
for s in (1, -1):
    k = 0
    y = -.875
    while y < -.69:
        hw = next((c[1] for c in reversed(CORPO) if c[0] <= y), .05)
        longo = k % 3 == 1
        base = Vector((s*(hw-.007), y, .058))
        detalhes.append(cone(base, base+Vector((s*.002, 0, -(.016 if longo else .01))), .0042, 5)+('e6dfc8', 0, 'cabeca'))
        hj = next((c[1] for c in reversed(MANDIBULA) if c[0] <= y+.011), .05)
        base = Vector((s*(hj-.006), y+.011, .052))
        detalhes.append(cone(base, base+Vector((s*.002, 0, .011 if k % 2 else .008)), .0038, 5)+('e6dfc8', 0, 'mandibula'))
        y += .022
        k += 1
# Olhos: globo dourado-esverdeado com pupila em fenda vertical; garras escuras.
for s in (1, -1):
    c = Vector((s*.054, -.704, .139))
    vs, fs = [], []
    seg, aneis = 14, 9
    for j in range(aneis+1):
        th = math.pi*j/aneis
        for i in range(seg):
            ph = 2*math.pi*i/seg
            vs.append(c+Vector((math.sin(th)*math.cos(ph), math.sin(th)*math.sin(ph), math.cos(th)))*.0155)
    for j in range(aneis):
        for i in range(seg):
            fs.append((j*seg+i, j*seg+(i+1) % seg, (j+1)*seg+(i+1) % seg, (j+1)*seg+i))
    detalhes.append((vs, fs, 'olho', 1, 'cabeca'))
for s in (1, -1):
    for pata, n in ((PATA_FRENTE, 5), (PATA_TRAS, 4)):
        base = Vector((s*pata[-1][0], pata[-1][1], pata[-1][2]))
        anterior = Vector((s*pata[-2][0], pata[-2][1], pata[-2][2]))
        frente = base-anterior
        frente.z = 0
        frente.normalize()
        lado = Vector((0, 0, 1)).cross(frente).normalized()
        comp = (.045, .055, .058, .052, .04) if n == 5 else (.06, .072, .07, .058)
        abertura = .75 if n == 5 else .55
        for k in range(n if n == 4 else 3):   # garras em três dedos da mão e quatro do pé
            ang = (k/(n-1)-.5)*abertura
            d = (frente*math.cos(ang)+lado*math.sin(ang)*s).normalized()
            ponta = base+d*(.015+comp[k])+Vector((0, 0, -.01))
            detalhes.append(cone(ponta-d*.006, ponta+d*.014+Vector((0, 0, -.003)), .004, 5)+('2b2720', 0, 'pata'))

# ---------------------------------------------------------------- cores


def pintar(o, mandibula):
    dorso = linear('5c6250')
    dorso_claro = linear('7d8066')
    faixa = linear('343a2d')
    flanco = linear('8a8a6c')
    ventre = linear('d3cba6')
    papo = linear('dcc66a')
    boca = linear('c98f80')
    mancha = linear('2f3428')
    cor = o.data.color_attributes.new(name='Cor', type='FLOAT_COLOR', domain='POINT')
    for v in o.data.vertices:
        p, n = v.co, v.normal
        salpico = .5+.5*math.sin(p.x*233+1.1)*math.sin(p.y*251+.4)*math.sin(p.z*241+2.3)
        c = dorso.lerp(dorso_claro, .45*salpico)
        # Faixas transversais escuras na cauda e no dorso (mais fortes na cauda).
        onda = .5+.5*math.sin(p.y*29+1.6*math.sin(p.x*20))
        intens = .35+.55*suave(.05, .3, p.y)
        c = c.lerp(faixa, suave(.62, .9, onda)*intens*suave(.0, .4, n.z+.2))
        # Manchas escuras na cabeça e na nuca.
        if p.y < -.5:
            pint = .5+.5*math.sin(p.x*140)*math.sin(p.y*120+.7)
            c = c.lerp(mancha, suave(.75, .95, pint)*.8)
        c = c.lerp(flanco, suave(.3, -.4, n.z)*.6)
        barriga = suave(-.2, -.75, n.z)
        c = c.lerp(ventre, barriga)
        # Papo amarelo: garganta, sob a mandíbula e o pescoço.
        if mandibula or p.y < -.45:
            c = c.lerp(papo, barriga*suave(-.42, -.6, p.y)*(1.0 if mandibula else .9))
        # Interior da boca rosado (superfícies voltadas para a fenda).
        if mandibula and n.z > .5 and p.z > .046 and abs(p.x) < .055:
            c = c.lerp(boca, .8)
        if not mandibula and p.y < -.64 and n.z < -.5 and p.z < .062 and abs(p.x) < .065:
            c = c.lerp(boca, .85)
        if not mandibula and p.y < -.862 and p.z > .08 and abs(abs(p.x)-.012) < .007:
            c = c.lerp(linear('1d1d18'), .9)                   # narinas
        cor.data[v.index].color = (c.x, c.y, c.z, 1.0)


pintar(corpo, False)
pintar(mand, True)

# Junta mandíbula e detalhes ao corpo, guardando o osso de cada vértice.
osso_vertice = {}
bm = bmesh.new()
bm.from_mesh(corpo.data)
n_corpo = len(bm.verts)
bm2 = bmesh.new()
bm2.from_mesh(mand.data)
camada = bm.verts.layers.float_color.get('Cor')
camada2 = bm2.verts.layers.float_color.get('Cor')
mapa = {}
for v in bm2.verts:
    nv = bm.verts.new(v.co)
    nv[camada] = v[camada2]
    mapa[v] = nv
    osso_vertice[nv] = 'mandibula'
for f in bm2.faces:
    nf = bm.faces.new([mapa[v] for v in f.verts])
    nf.smooth = True
bm2.free()
bpy.data.objects.remove(mand)
iris = linear('b29a3e')
pupila = linear('0c0c0a')
for vs, fs, hexa, mat, osso in detalhes:
    novos = [bm.verts.new(v) for v in vs]
    for nv in novos:
        if hexa == 'olho':
            rel = (nv.co-Vector((math.copysign(.054, nv.co.x), -.704, .139))).normalized()
            fenda = abs(rel.x*-.0+rel.y*.35+rel.x*.9*math.copysign(1, nv.co.x)) > .6 and abs(rel.y) < .3
            cc = pupila if (rel.x*math.copysign(1, nv.co.x) > .55 and abs(rel.y) < .22) else iris
        else:
            cc = linear(hexa)
        nv[camada] = (cc.x, cc.y, cc.z, 1.0)
        osso_vertice[nv] = osso
    for f in fs:
        try:
            face = bm.faces.new([novos[i] for i in f])
            face.material_index = mat
            face.smooth = True
        except ValueError:
            pass
bm.verts.index_update()
osso_idx = {v.index: o for v, o in osso_vertice.items()}
bm.to_mesh(corpo.data)
bm.free()

pele = bpy.data.materials.new('Jacare_Cores')
pele.use_nodes = True
bs = next(n for n in pele.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bs.inputs['Roughness'].default_value = .62
if 'Specular IOR Level' in bs.inputs:
    bs.inputs['Specular IOR Level'].default_value = .4
vc = pele.node_tree.nodes.new('ShaderNodeVertexColor')
vc.layer_name = 'Cor'
pele.node_tree.links.new(vc.outputs['Color'], bs.inputs['Base Color'])
olho = bpy.data.materials.new('Jacare_Olho')
olho.use_nodes = True
bo = next(n for n in olho.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bo.inputs['Roughness'].default_value = .12
vo = olho.node_tree.nodes.new('ShaderNodeVertexColor')
vo.layer_name = 'Cor'
olho.node_tree.links.new(vo.outputs['Color'], bo.inputs['Base Color'])
corpo.data.materials.append(pele)
corpo.data.materials.append(olho)

# ---------------------------------------------------------------- rig e pesos
raiz = bpy.data.objects.new('Jacare', None)
cena.collection.objects.link(raiz)
arm = bpy.data.armatures.new('Esqueleto_jacare')
rig = bpy.data.objects.new('Rig_jacare', arm)
cena.collection.objects.link(rig)
rig.parent = raiz
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')


def osso(nome, a, b, pai=None):
    o = arm.edit_bones.new(nome)
    o.head, o.tail = a, b
    if pai:
        o.parent = arm.edit_bones[pai]


CAUDA = [(.12, .32), (.32, .52), (.52, .72), (.72, .92)]
osso('raiz', (0, 0, 0), (0, 0, .15))
osso('tronco', (0, .12, .1), (0, -.5, .1), 'raiz')
osso('pescoco', (0, -.5, .1), (0, -.66, .1), 'tronco')
osso('cabeca', (0, -.66, .1), (0, -.905, .075), 'pescoco')
osso('mandibula', (0, -.64, .05), (0, -.892, .043), 'cabeca')
for i, (a, b) in enumerate(CAUDA):
    osso('cauda_%d' % (i+1), (0, a, .1), (0, b, .095-.005*i), 'raiz' if i == 0 else 'cauda_%d' % i)
PERNAS = {}
for lado, s in (('E', 1), ('D', -1)):
    for membro, pata in (('frente', PATA_FRENTE), ('tras', PATA_TRAS)):
        pts = [Vector((s*x, y, z)) for x, y, z, _ in pata]
        ponta = pts[-1]+(pts[-1]-pts[-2]).normalized()*.05
        ponta.z = .004
        PERNAS[(membro, lado)] = [pts[0], pts[1], pts[2], ponta]
        osso('%s_%s' % (membro, lado), pts[0], pts[1], 'raiz')
        osso('%s_canela_%s' % (membro, lado), pts[1], pts[2], '%s_%s' % (membro, lado))
        osso('%s_pe_%s' % (membro, lado), pts[2], ponta, '%s_canela_%s' % (membro, lado))
bpy.ops.object.mode_set(mode='OBJECT')

for b in arm.bones:
    corpo.vertex_groups.new(name=b.name)
G = corpo.vertex_groups


def coluna(y):
    """Peso da coluna ao longo de y: cabeça, pescoço, tronco e quatro segmentos da cauda."""
    cortes = [('cabeca', -.66), ('pescoco', -.5), ('tronco', .12), ('cauda_1', .32), ('cauda_2', .52), ('cauda_3', .72), ('cauda_4', 9)]
    largura = .05
    pesos = {}
    anterior = -9
    for i, (nome, fim) in enumerate(cortes):
        ini = anterior
        w = suave(ini-largura, ini+largura, y)*(1-suave(fim-largura, fim+largura, y)) if i else 1-suave(fim-largura, fim+largura, y)
        if w > 0:
            pesos[nome] = w
        anterior = fim
    tot = sum(pesos.values())
    return {k: v/tot for k, v in pesos.items()}


for v in corpo.data.vertices:
    p = v.co
    dono = osso_idx.get(v.index)
    if dono == 'mandibula':
        G['mandibula'].add([v.index], 1.0, 'REPLACE')
        continue
    if dono in ('cabeca', 'pescoco'):
        G[dono].add([v.index], 1.0, 'REPLACE')
        continue
    pesos = {}
    perna = 0.0
    for lado, s in (('E', 1), ('D', -1)):
        if p.x*s < .05:
            continue
        for membro in ('frente', 'tras'):
            a, b, c, d = PERNAS[(membro, lado)]
            ds = [dist_seg(p, a, b), dist_seg(p, b, c), dist_seg(p, c, d)]
            alcance = .085 if membro == 'tras' else .068
            w = (1-suave(alcance*.55, alcance, min(ds)))*suave(.1, .16, abs(p.x))
            if dono == 'pata' or abs(p.x) > .2:
                w = max(w, 1-suave(.04, .07, min(ds)))
            if w <= 0:
                continue
            inv = [1/(x+.004)**8 for x in ds]
            tot = sum(inv)
            for nome, wi in zip(('%s_%s', '%s_canela_%s', '%s_pe_%s'), inv):
                pesos[nome % (membro, lado)] = pesos.get(nome % (membro, lado), 0)+w*wi/tot
            perna += w
    if perna > 1:
        pesos = {k: v/perna for k, v in pesos.items()}
        perna = 1
    for nome, w in coluna(p.y).items():
        pesos[nome] = pesos.get(nome, 0)+(1-perna)*w
    for nome, w in pesos.items():
        if w > .001:
            G[nome].add([v.index], w, 'REPLACE')
corpo.parent = rig
mod = corpo.modifiers.new('Deformacao', 'ARMATURE')
mod.object = rig
rig.animation_data_create()

pts = [v.co for v in corpo.data.vertices]
print('JACARE', 'vertices', len(pts), 'faces', len(corpo.data.polygons), 'comprimento',
      round(max(p.y for p in pts)-min(p.y for p in pts), 3), 'largura', round(max(p.x for p in pts)*2, 3),
      'altura', round(max(p.z for p in pts), 3))
bpy.data.libraries.write(str(RAIZ/'art/blender/jacare.blend'), {cena}, fake_user=True, compress=True)
print('JACARE PRONTO')
