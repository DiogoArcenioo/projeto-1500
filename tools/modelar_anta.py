"""Anta (Tapirus terrestris) — modelo orgânico, rig com tromba e cores.

Uso: blender --background --factory-startup --python tools/modelar_anta.py
Grava art/blender/anta.blend (cena 'Anta': raiz vazia + rig + malha). Animações e GLBs:
tools/animar_anta.py.

Referências gerais da espécie: 1,8–2,5 m, ~0,9 m de altura, 150–300 kg; corpo pesado e
arredondado com garupa alta, cabeça longa terminando em tromba curta e móvel, crina curta
da testa aos ombros, orelhas ovais com borda branca, olhos pequenos, toco de cauda;
4 dedos nas patas dianteiras e 3 nas traseiras; pelagem marrom-acinzentada escura,
bochechas e garganta mais claras.

Forma: corpo/pescoço/cabeça/tromba por lofting do perfil lateral, pernas tubulares com
articulações e dedos com cascos; tudo fundido por voxel e suavizado; relevo leve de pelo.
Cores por vértice. Frente = −Y, solo em z = 0. Ossos com os nomes dos outros animais e um
osso 'tromba'.
"""
import bpy, bmesh, math, random
from pathlib import Path
from mathutils import Vector
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
cena.name = 'Anta'
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)


def contexto(o):
    return bpy.context.temp_override(object=o, active_object=o, selected_objects=[o], selected_editable_objects=[o])


def loft(secoes, lados=40):
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
    vs += [secoes[0][0], secoes[-1][0]]
    a0, a1 = len(vs)-2, len(vs)-1
    for i in range(lados):
        fs.append((a0, (i+1) % lados, i))
        fs.append((a1, (n-1)*lados+i, (n-1)*lados+(i+1) % lados))
    return vs, fs


def tubo(pontos, raios, lados=16):
    pts = [Vector(p) for p in pontos]
    sec = []
    for i, (p, r) in enumerate(zip(pts, raios)):
        d = (pts[min(len(pts)-1, i+1)]-pts[max(0, i-1)]).normalized()
        u = Vector((1, 0, 0))
        u = (u-d*u.dot(d)).normalized()
        sec.append((p, u, d.cross(u).normalized(), r, r))
    return loft(sec, lados)


# ---------------------------------------------------------------- forma
# (y, meia largura, z topo, z base). Garupa mais alta que a cernelha; cabeça longa e
# baixa; tromba curta levemente caída. A crina sobe um pouco o topo do pescoço.
PERFIL = [(.55, .245, .965, .47), (.38, .255, .955, .45), (.18, .255, .93, .44), (-.02, .25, .91, .445),
          (-.18, .235, .905, .465), (-.3, .205, .905, .5), (-.4, .158, .885, .545), (-.49, .135, .855, .55),
          (-.58, .134, .845, .52), (-.68, .122, .81, .522), (-.78, .108, .77, .528), (-.87, .094, .73, .534),
          (-.94, .082, .70, .538), (-.99, .07, .67, .542), (-1.03, .06, .645, .546), (-1.06, .05, .625, .552),
          (-1.08, .036, .61, .562), (-1.088, .02, .6, .572)]
GARUPA = []
for k in range(8, 0, -1):
    f = k/8
    esc = max(.05, math.sqrt(max(0.0, 1-f**2.2)))
    zc, meia = (.965+.47)/2+.01*f, (.965-.47)/2
    GARUPA.append((.55+.2*f, .245*esc, zc+meia*esc, zc-meia*esc))
PERFIL = GARUPA+PERFIL
# Pernas: (x, y, z, raio) do ombro/pernil ao casco.
PERNA_FRENTE = [(.08, -.25, .8, .05), (.13, -.25, .66, .1), (.145, -.255, .5, .08), (.15, -.245, .3, .064), (.15, -.238, .2, .056),
                (.15, -.235, .09, .052), (.15, -.245, .045, .052)]
PERNA_TRAS = [(.08, .5, .84, .06), (.12, .5, .7, .13), (.145, .56, .52, .1), (.15, .61, .32, .07), (.15, .6, .22, .06),
              (.15, .575, .09, .052), (.15, .565, .045, .052)]
partes = []
sec = [(Vector((0, y, (zt+zb)/2)), Vector((1, 0, 0)), Vector((0, 0, 1)), hw, (zt-zb)/2) for y, hw, zt, zb in PERFIL]
partes.append(loft(sec))
for s in (1, -1):
    for perna, dedos in ((PERNA_FRENTE, 4), (PERNA_TRAS, 3)):
        pts = [Vector((s*x, y, z)) for x, y, z, _ in perna]
        partes.append(tubo(pts, [r for *_, r in perna]))
        base = pts[-1]
        # Dedos com cascos em leque (4 na mão, 3 no pé), o do meio maior.
        for k in range(dedos):
            f = k/(dedos-1)-.5
            d = Vector((s*f*.9, -1, 0)).normalized()
            p0 = base+Vector((s*f*.05, -.01, -.02))
            partes.append(tubo([p0, p0+d*.04+Vector((0, 0, -.018))], [.024 if abs(f) < .3 else .019, .02], 12))
# Toco de cauda e orelhas fundidas na cabeça.
partes.append(tubo([(0, .74, .8), (0, .8, .76), (0, .83, .7)], [.04, .03, .018], 12))
vs, fs = [], []
for pv, pf in partes:
    b = len(vs)
    vs += [tuple(v) for v in pv]
    fs += [tuple(i+b for i in f) for f in pf]
malha = bpy.data.meshes.new('Anta_Malha')
malha.from_pydata(vs, [], fs)
malha.update()
corpo = bpy.data.objects.new('Anta_Malha', malha)
cena.collection.objects.link(corpo)
with contexto(corpo):
    m = corpo.modifiers.new('Remesh', 'REMESH')
    m.mode = 'VOXEL'
    m.voxel_size = .009
    bpy.ops.object.modifier_apply(modifier=m.name)
    m = corpo.modifiers.new('Suave', 'SMOOTH')
    m.factor = .5
    m.iterations = 8
    bpy.ops.object.modifier_apply(modifier=m.name)
bm = bmesh.new()
bm.from_mesh(corpo.data)
bm.normal_update()
fase = [rng.uniform(0, 100) for _ in range(6)]
for v in bm.verts:
    p = v.co
    ruido = (math.sin(p.x*61+fase[0])*math.sin(p.y*57+fase[1])*math.sin(p.z*63+fase[2])
             + .5*math.sin(p.x*131+fase[3])*math.sin(p.y*127+fase[4])*math.sin(p.z*119+fase[5]))
    pele = suave(.1, .25, p.z)*(1-suave(-.95, -.9, p.y))
    v.co += v.normal*ruido*.0018*pele
bm.to_mesh(corpo.data)
bm.free()
with contexto(corpo):
    m = corpo.modifiers.new('Reduzir', 'DECIMATE')
    m.ratio = .14
    bpy.ops.object.modifier_apply(modifier=m.name)
for p in corpo.data.polygons:
    p.use_smooth = True
arvore = BVHTree.FromObject(corpo, bpy.context.evaluated_depsgraph_get())


def no_corpo(origem, direcao=(0, 0, -1)):
    return arvore.ray_cast(Vector(origem), Vector(direcao).normalized(), 3)[0]


# ---------------------------------------------------------------- detalhes
pecas = []


def cone(base, ponta, r, seg=8, achata=1.0, eixo=None):
    base, ponta = Vector(base), Vector(ponta)
    d = (ponta-base).normalized()
    u = d.orthogonal().normalized() if eixo is None else (Vector(eixo)-d*d.dot(Vector(eixo))).normalized()
    w = d.cross(u)
    vs = [base+(u*math.cos(2*math.pi*i/seg)*achata+w*math.sin(2*math.pi*i/seg))*r for i in range(seg)]+[ponta]
    return vs, [(i, (i+1) % seg, seg) for i in range(seg)]+[tuple(reversed(range(seg)))]


def orelha(base, s):
    """Orelha oval em concha: miolo escuro (anel interno) e borda branca (anel externo)."""
    base = Vector(base)
    vs, fs = [base], []
    n = 16
    for escala in (.72, 1.0):
        for i in range(n):
            a = 2*math.pi*i/n
            vs.append(base+Vector((s*(.012+.03*math.sin(a))*escala, (.02*math.cos(a)-.008)*escala-.004*(1-escala)*0,
                                   .048+.048*math.cos(a)*escala)))
    for i in range(n):
        k = (i+1) % n
        fs.append((0, 1+i, 1+k))
        fs.append((1+i, 1+n+i, 1+n+k, 1+k))
    return vs, fs


for s in (1, -1):
    t = no_corpo((s*.08, -.56, 1.2)) or Vector((s*.08, -.56, .84))
    vs, fs = orelha(t+Vector((0, 0, -.015)), s)
    pecas.append((vs, fs, 'orelha', 0))
    pecas.append((vs[:1]+[v+Vector((s*.002, .002, 0)) for v in vs[1:]], [tuple(reversed(f)) for f in fs], 'orelha', 0))
    olho = no_corpo((s*.6, -.68, .735), (-s, 0, 0)) or Vector((s*.1, -.68, .735))
    vo = [olho+Vector((-s*.004, 0, 0))+Vector((math.sin(t2)*math.cos(p2), math.sin(t2)*math.sin(p2), math.cos(t2)))*.011
          for t2 in [math.pi*j/7 for j in range(8)] for p2 in [2*math.pi*i/10 for i in range(10)]]
    fo = []
    for j in range(7):
        for i in range(10):
            fo.append((j*10+i, j*10+(i+1) % 10, (j+1)*10+(i+1) % 10, (j+1)*10+i))
    pecas.append((vo, fo, '0e0c0b', 1))
# Crina curta e eriçada da testa aos ombros.
y = -.66
while y < -.2:
    t = no_corpo((0, y, 1.3))
    if t:
        alt = .028+.018*math.exp(-((y+.45)/.12)**2)
        for lado in (-1, 1):
            b = t+Vector((lado*rng.uniform(.003, .01), 0, -.006))
            pecas.append(cone(b, t+Vector((lado*rng.uniform(.002, .01), rng.uniform(.005, .02), alt*rng.uniform(.8, 1.15))), .007, 5, .45, (1, 0, 0))
                         + ('2e2722' if rng.random() < .65 else '5a4e44', 0))
    y += .013
# Narinas na ponta da tromba.
for s in (1, -1):
    pecas.append(cone((s*.014, -1.078, .588), (s*.014, -1.092, .588), .008, 6)+('1a1513', 0))

# ---------------------------------------------------------------- cores
base_c = linear('4b4139')
grisalho = linear('665a50')
claro = linear('8f8274')
perna_c = linear('352e29')
casco = linear('1f1b18')
tromba = linear('3a322d')
cor = corpo.data.color_attributes.new(name='Cor', type='FLOAT_COLOR', domain='POINT')
for v in corpo.data.vertices:
    p, n = v.co, v.normal
    sal = .5+.5*math.sin(p.x*211+1.3)*math.sin(p.y*197+.7)*math.sin(p.z*223+2.1)
    c = base_c.lerp(grisalho, .5*sal*sal)
    # Bochechas, lábio e garganta mais claros.
    c = c.lerp(claro, suave(-.5, -.66, p.y)*suave(.66, .58, p.z)*(1-suave(-.92, -.98, p.y))*.75)
    c = c.lerp(perna_c, suave(.45, .3, p.z)*suave(.08, .11, abs(p.x)))
    c = c.lerp(tromba, suave(-.94, -1.0, p.y))
    c = c.lerp(casco, suave(.045, .02, p.z))
    cor.data[v.index].color = (c.x, c.y, c.z, 1.0)
bm = bmesh.new()
bm.from_mesh(corpo.data)
camada = bm.verts.layers.float_color.get('Cor')
for vs, fs, hexa, mat in pecas:
    novos = [bm.verts.new(v) for v in vs]
    for i, nv in enumerate(novos):
        if hexa == 'orelha':
            borda = i > 16
            cc = linear('e6e0d4') if borda else (linear('3a312b') if i else linear('2a2420'))
        else:
            cc = linear(hexa)
        nv[camada] = (cc.x, cc.y, cc.z, 1.0)
    for f in fs:
        try:
            face = bm.faces.new([novos[i] for i in f])
            face.material_index = mat
            face.smooth = True
        except ValueError:
            pass
bm.to_mesh(corpo.data)
bm.free()
pele = bpy.data.materials.new('Anta_Cores')
pele.use_nodes = True
bs = next(n for n in pele.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bs.inputs['Roughness'].default_value = .85
if 'Specular IOR Level' in bs.inputs:
    bs.inputs['Specular IOR Level'].default_value = .25
vc = pele.node_tree.nodes.new('ShaderNodeVertexColor')
vc.layer_name = 'Cor'
pele.node_tree.links.new(vc.outputs['Color'], bs.inputs['Base Color'])
olho = bpy.data.materials.new('Anta_Olho')
olho.use_nodes = True
bo = next(n for n in olho.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bo.inputs['Roughness'].default_value = .15
vo = olho.node_tree.nodes.new('ShaderNodeVertexColor')
vo.layer_name = 'Cor'
olho.node_tree.links.new(vo.outputs['Color'], bo.inputs['Base Color'])
corpo.data.materials.append(pele)
corpo.data.materials.append(olho)

# ---------------------------------------------------------------- rig e pesos
raiz = bpy.data.objects.new('Anta', None)
cena.collection.objects.link(raiz)
arm = bpy.data.armatures.new('Esqueleto_anta')
rig = bpy.data.objects.new('Rig_anta', arm)
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


osso('raiz', (0, 0, 0), (0, 0, .15))
osso('tronco', (0, .62, .78), (0, -.32, .76), 'raiz')
osso('pescoco', (0, -.32, .76), (0, -.56, .72), 'tronco')
osso('cabeca', (0, -.56, .72), (0, -.97, .63), 'pescoco')
osso('tromba', (0, -.97, .63), (0, -1.09, .59), 'cabeca')
PERNAS = {}
for lado, s in (('E', 1), ('D', -1)):
    x = s*.15
    PERNAS[('frente', lado)] = [Vector((x, -.25, .66)), Vector((x, -.245, .3)), Vector((x, -.237, .07)), Vector((x, -.29, .008))]
    PERNAS[('tras', lado)] = [Vector((x, .52, .7)), Vector((x, .61, .3)), Vector((x, .575, .07)), Vector((x, .52, .008))]
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
    pesos = {}
    perna = 0.0
    for lado, s in (('E', 1), ('D', -1)):
        if p.x*s < .03:
            continue
        for membro in ('frente', 'tras'):
            a, b, c, d = PERNAS[(membro, lado)]
            ds = [dist_seg(p, a, b), dist_seg(p, b, c), dist_seg(p, c, d)]
            alcance = .2 if membro == 'tras' else .15
            w = (1-suave(alcance*.55, alcance, min(ds)))*suave(.66, .48, p.z)
            if p.z < .45:
                w = max(w, 1-suave(.09, .14, min(ds)))
            if w <= 0:
                continue
            inv = [1/(x+.006)**8 for x in ds]
            tot = sum(inv)
            for nome, wi in zip(('%s_%s', '%s_canela_%s', '%s_pe_%s'), inv):
                pesos[nome % (membro, lado)] = pesos.get(nome % (membro, lado), 0)+w*wi/tot
            perna += w
    if perna > 1:
        pesos = {k: x/perna for k, x in pesos.items()}
        perna = 1
    resto = 1-perna
    pesc = suave(-.28, -.38, p.y)
    cab = suave(-.52, -.6, p.y)
    trb = suave(-.92, -.98, p.y)
    for nome, w in (('tronco', 1-pesc), ('pescoco', pesc-cab), ('cabeca', cab-trb), ('tromba', trb)):
        pesos[nome] = pesos.get(nome, 0)+resto*w
    for nome, w in pesos.items():
        if w > .001:
            G[nome].add([v.index], w, 'REPLACE')
corpo.parent = rig
mod = corpo.modifiers.new('Deformacao', 'ARMATURE')
mod.object = rig
rig.animation_data_create()
pts = [v.co for v in corpo.data.vertices]
print('ANTA', 'vertices', len(pts), 'faces', len(corpo.data.polygons), 'comprimento',
      round(max(p.y for p in pts)-min(p.y for p in pts), 3), 'altura', round(max(p.z for p in pts), 3),
      'largura', round(max(p.x for p in pts)*2, 3))
bpy.data.libraries.write(str(RAIZ/'art/blender/anta.blend'), {cena}, fake_user=True, compress=True)
print('ANTA PRONTA')
