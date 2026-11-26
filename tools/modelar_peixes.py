"""Peixes da pesca (etapa 12): lambari, acará, piau, traíra, jundiá, robalo e camurupim.

Uso: blender --background --factory-startup --python tools/modelar_peixes.py
Grava art/blender/peixes.blend e assets/models/peixes/peixes.glb (um objeto por espécie,
com o mesmo nome do id em assets/configuracoes/pesca.json).

Cada peixe mede 1 m (o jogo escala pelo comprimento sorteado). O focinho fica em -Y no
Blender (+Z no Godot) e a ponta da cauda em +Y. O corpo é um loft de seções
superelípticas; as nadadeiras são lâminas finas com raios pintados. As cores vão por
vértice ('Cor'): dorso escuro, ventre claro, linha lateral e as marcas de cada espécie.
A natação é feita no Godot por shader (onda que cresce para a cauda), sem esqueleto.
"""
import bpy, bmesh, math
from pathlib import Path
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[1]
TAU = math.tau
ANEL = 18


def hexcor(h, a=1.0):
    h = h.lstrip('#')
    c = [int(h[i:i+2], 16)/255 for i in (0, 2, 4)]
    return [x**2.2 for x in c]+[a]


def mistura(a, b, t):
    t = max(0.0, min(1.0, t))
    return [a[i]+(b[i]-a[i])*t for i in range(4)]


def suave(a, b, x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3-2*t)


class Peixe:
    def __init__(self, nome):
        self.nome = nome
        self.v, self.f, self.c = [], [], []

    def ponto(self, p, cor):
        self.v.append(tuple(p))
        self.c.append(cor)
        return len(self.v)-1

    def corpo(self, perfil, cor, secoes=30, cauda_ini=.8):
        """perfil(t) -> (meia_largura, topo, base); t = 0 focinho .. cauda_ini pedúnculo."""
        aneis = []
        ponta = self.ponto((0, -.5, perfil(0)[1]*.5+perfil(0)[2]*.5), cor(0, 0, 0))
        for i in range(1, secoes+1):
            t = cauda_ini*(i/secoes)**.92
            w, topo, base = perfil(t)
            anel = []
            for k in range(ANEL):
                a = TAU*k/ANEL
                ca, sa = math.cos(a), math.sin(a)
                # superelipse: costas mais cheias que o ventre
                ex = 2.4
                x = w*math.copysign(abs(sa)**(2/ex), sa)
                cz = math.copysign(abs(ca)**(2/ex), ca)
                meio = (topo+base)/2
                z = meio+cz*((topo-meio) if cz > 0 else (meio-base))
                anel.append(self.ponto((x, -.5+t, z), cor(t, cz, x/max(w, 1e-4))))
            aneis.append(anel)
        for k in range(ANEL):
            self.f.append((ponta, aneis[0][(k+1) % ANEL], aneis[0][k]))
        for a, b in zip(aneis, aneis[1:]):
            for k in range(ANEL):
                k2 = (k+1) % ANEL
                self.f.append((a[k], a[k2], b[k2], b[k]))
        fim = aneis[-1]
        c = self.ponto((0, -.5+cauda_ini, sum(self.v[i][2] for i in fim)/ANEL), cor(cauda_ini, 0, 0))
        for k in range(ANEL):
            self.f.append((fim[k], fim[(k+1) % ANEL], c))
        self.aneis = aneis

    def lamina(self, contorno, cor_base, cor_raio, raios=8, espessura=.004, eixo='x'):
        """Nadadeira: contorno fechado no plano (y, z) (ou (x, y) se eixo='z'); dupla face."""
        n = len(contorno)
        cy = sum(p[0] for p in contorno)/n
        cz = sum(p[1] for p in contorno)/n
        for lado in (1, -1):
            ids = []
            for j, (a, b) in enumerate(contorno):
                raio = .5+.5*math.cos(j/max(n-1, 1)*raios*TAU)
                cor = mistura(cor_base, cor_raio, raio*.6)
                p = (espessura*lado, a, b) if eixo == 'x' else (a, b, espessura*lado)
                ids.append(self.ponto(p, cor))
            centro = self.ponto((espessura*lado, cy, cz) if eixo == 'x' else (cy, cz, espessura*lado), cor_base)
            for j in range(n):
                tri = (ids[j], ids[(j+1) % n], centro)
                self.f.append(tri if lado > 0 else tri[::-1])

    def par(self, contorno_xyz, cor):
        """Nadadeira peitoral/pélvica: contorno 3D no lado +x espelhado para -x."""
        for s in (1, -1):
            ids = [self.ponto((p[0]*s, p[1], p[2]), cor) for p in contorno_xyz]
            for j in range(1, len(ids)-1):
                tri = (ids[0], ids[j], ids[j+1])
                self.f.append(tri if s > 0 else tri[::-1])
                self.f.append(tri[::-1] if s > 0 else tri)

    def olho(self, y, z, x, r, iris, pupila='0b0b0a'):
        for s in (1, -1):
            centro = self.ponto((x*s+.004*s, y, z), hexcor(pupila))
            borda = []
            for k in range(12):
                a = TAU*k/12
                borda.append(self.ponto((x*s, y+r*math.cos(a), z+r*math.sin(a)), hexcor(iris)))
            meio = []
            for k in range(12):
                a = TAU*k/12
                meio.append(self.ponto((x*s+.003*s, y+r*.55*math.cos(a), z+r*.55*math.sin(a)), hexcor(pupila)))
            for k in range(12):
                k2 = (k+1) % 12
                q = (borda[k], borda[k2], meio[k2], meio[k])
                self.f.append(q if s < 0 else q[::-1])
                t = (meio[k], meio[k2], centro)
                self.f.append(t if s < 0 else t[::-1])

    def barbilhao(self, base, ponta, r, cor):
        for s in (1, -1):
            b = Vector((base[0]*s, base[1], base[2]))
            e = Vector((ponta[0]*s, ponta[1], ponta[2]))
            d = (e-b).normalized()
            o = d.orthogonal().normalized()
            o2 = d.cross(o)
            anel = []
            for k in range(4):
                a = TAU*k/4
                anel.append(self.ponto(b+(o*math.cos(a)+o2*math.sin(a))*r, cor))
            pe = self.ponto(e, cor)
            for k in range(4):
                self.f.append((anel[k], anel[(k+1) % 4], pe))

    def criar(self):
        me = bpy.data.meshes.new(self.nome)
        me.from_pydata(self.v, [], self.f)
        me.update()
        cor = me.color_attributes.new(name='Cor', type='FLOAT_COLOR', domain='POINT')
        for i, c in enumerate(self.c):
            cor.data[i].color = c
        ob = bpy.data.objects.new(self.nome, me)
        bpy.context.scene.collection.objects.link(ob)
        for p in me.polygons:
            p.use_smooth = True
        mat = bpy.data.materials.get('Peixe') or criar_material()
        me.materials.append(mat)
        return ob


def criar_material():
    m = bpy.data.materials.new('Peixe')
    m.use_nodes = True
    bs = m.node_tree.nodes['Principled BSDF']
    bs.inputs['Roughness'].default_value = .32
    vc = m.node_tree.nodes.new('ShaderNodeVertexColor')
    vc.layer_name = 'Cor'
    m.node_tree.links.new(vc.outputs['Color'], bs.inputs['Base Color'])
    return m


def perfil_padrao(altura, largura, pico=.33, cabeca=.5, pedunculo=.075, ventre=.45, focinho=.04):
    """Altura/largura relativas ao comprimento. cabeca: 0 pontuda .. 1 romba."""
    def f(t):
        u = t/.8
        sobe = math.sin(min(1.0, u/pico)*math.pi/2)**(.55+.6*(1-cabeca)) if u < pico else 1.0
        desce = 1.0 if u < pico else math.cos(min(1.0, (u-pico)/(1-pico))*math.pi/2)**.9
        forma = sobe*desce
        h = focinho+(altura-focinho)*forma
        h = max(h, pedunculo) if u > .6 else h
        w = max(.012, largura*(.25+.75*forma) * (1 if u < .85 else .8))
        topo = h*(1-ventre)
        base = -h*ventre
        return w, topo, base
    return f


def cauda(p, cor, cor_raio, garfo=.55, altura=.2, rabo='garfo'):
    """Nadadeira caudal de .8 a 1.0. rabo: garfo (bifurcada), reta ou redonda."""
    y0 = .3
    if rabo == 'garfo':
        cont = [(y0, .035), (.5, altura), (.47, altura*.55), (.5-.2*garfo*.5, 0), (.47, -altura*.55), (.5, -altura), (y0, -.035)]
    elif rabo == 'reta':
        cont = [(y0, .035), (.48, altura*.85), (.5, altura*.3), (.5, -altura*.3), (.48, -altura*.85), (y0, -.035)]
    else:
        cont = [(y0, .035)]+[(.38+.12*math.cos(a), altura*math.sin(a)) for a in [math.pi/2-i*math.pi/8 for i in range(9)]]+[(y0, -.035)]
    p.lamina(cont, cor, cor_raio, raios=7)


def colorir(dorso, flanco, ventre, linha=None, extra=None):
    dorso, flanco, ventre = hexcor(dorso), hexcor(flanco), hexcor(ventre)
    l = hexcor(linha) if linha else None

    def cor(t, cz, lateral):
        c = mistura(ventre, flanco, suave(-.75, -.05, cz))
        c = mistura(c, dorso, suave(.15, .8, cz))
        if l and abs(cz-.05) < .07 and t > .18:
            c = mistura(c, l, .75)
        if extra:
            c = extra(t, cz, lateral, c)
        return c
    return cor


def mancha(cx, cz, r, hexa, forca=.9):
    alvo = hexcor(hexa)

    def f(t, z, lat, c):
        d = math.hypot((t-cx)/r, (z-cz)/(r*2.2))
        return mistura(c, alvo, forca*(1-suave(.7, 1.0, d)))
    return f


def juntar(*fs):
    def f(t, z, lat, c):
        for g in fs:
            c = g(t, z, lat, c)
        return c
    return f


def curva(pts):
    """Catmull-Rom entre pontos (u, valor): contorno contínuo, sem degraus nos pontos."""
    def f(u):
        u = max(0.0, min(1.0, u))
        n = len(pts)
        for i in range(n-1):
            a, va = pts[i]
            b, vb = pts[i+1]
            if u <= b:
                k = (u-a)/(b-a) if b > a else 0
                h = b-a
                m0 = (vb-pts[i-1][1])/(b-pts[i-1][0])*h if i > 0 else vb-va
                m1 = (pts[i+2][1]-va)/(pts[i+2][0]-a)*h if i+2 < n else vb-va
                k2, k3 = k*k, k*k*k
                return (2*k3-3*k2+1)*va+(k3-2*k2+k)*m0+(-2*k3+3*k2)*vb+(k3-k2)*m1
        return pts[-1][1]
    return f


class Forma:
    """Silhueta da espécie: topo, base e meia-largura ao longo de u (0 focinho, 1 pedúnculo)."""
    def __init__(self, topo, base, largura):
        self.topo, self.base, self.larg = curva(topo), curva(base), curva(largura)

    def __call__(self, t):
        u = t/.8
        return self.larg(u), self.topo(u), self.base(u)

    def y(self, u):
        return -.5+.8*u


def dorsal(p, f, u0, u1, h, cor, raio, forma=((0, 0), (.25, 1), (1, .3)), raios=9, base_neg=False):
    """Nadadeira presa ao dorso (ou ao ventre, base_neg) entre u0 e u1."""
    cont = []
    lado = f.base if base_neg else f.topo
    sinal = -1 if base_neg else 1
    for fr, hh in forma:
        u = u0+(u1-u0)*fr
        cont.append((f.y(u), lado(u)+sinal*h*hh))
    for fr in (1.0, .66, .33, 0.0):
        u = u0+(u1-u0)*fr
        cont.append((f.y(u), lado(u)-sinal*.012))
    p.lamina(cont, cor, raio, raios=raios)


def caudal(p, f, cor, raio, altura, rabo='garfo', garfo=.6, comp=.2):
    t0 = f.y(1.0)
    topo, base = f.topo(1.0), f.base(1.0)
    m = (topo+base)/2
    if rabo == 'garfo':
        cont = [(t0-.01, topo-.005), (t0+comp, m+altura), (t0+comp*.82, m+altura*.6), (t0+comp*(1-garfo*.55), m),
                (t0+comp*.82, m-altura*.6), (t0+comp, m-altura), (t0-.01, base+.005)]
    elif rabo == 'reta':
        cont = [(t0-.01, topo-.005), (t0+comp*.95, m+altura), (t0+comp, m+altura*.3), (t0+comp, m-altura*.3), (t0+comp*.95, m-altura), (t0-.01, base+.005)]
    else:
        cont = [(t0-.01, topo-.005)]+[(t0+comp*.15+comp*.85*math.cos(a), m+altura*math.sin(a)) for a in [math.pi/2-i*math.pi/8 for i in range(9)]]+[(t0-.01, base+.005)]
    p.lamina(cont, cor, raio, raios=8)


def peitoral(p, f, u, comp, cor, alto=.35, caida=.6):
    w, topo, base = f(.8*u)
    z = base+(topo-base)*alto
    y = f.y(u)
    p.par([(w*.85, y, z), (w*.85+comp*.35, y+comp*.85, z-comp*caida*.5), (w*.8+comp*.15, y+comp, z-comp*caida),
           (w*.75, y+comp*.4, z-comp*.15)], cor)


def pelvica(p, f, u, comp, cor):
    w, topo, base = f(.8*u)
    y = f.y(u)
    p.par([(w*.35, y, base+.008), (w*.35+comp*.3, y+comp, base-comp*.45), (w*.2, y+comp*.85, base-comp*.3)], cor)


def olho_em(p, f, u, r, iris, alto=.62):
    w, topo, base = f(.8*u)
    p.olho(f.y(u), base+(topo-base)*alto, w*.92, r, iris)


def lambari():
    p = Peixe('lambari')
    f = Forma([(0, .01), (.08, .055), (.22, .115), (.36, .14), (.52, .125), (.72, .07), (.9, .042), (1, .038)],
              [(0, -.012), (.08, -.05), (.22, -.098), (.38, -.125), (.56, -.115), (.76, -.06), (.9, -.038), (1, -.036)],
              [(0, .012), (.15, .042), (.35, .055), (.7, .035), (1, .018)])
    cor = colorir('4f5e58', 'c7d0cb', 'eef0e8', None, juntar(mancha(.22, .25, .025, '1d1f1c', .8), mancha(.78, .05, .03, '141514')))
    p.corpo(f, cor)
    amarelo, ocre = hexcor('d9a83a'), hexcor('a8792a')
    caudal(p, f, amarelo, ocre, .14, garfo=.95, comp=.2)
    dorsal(p, f, .42, .52, .08, hexcor('b5a46a'), hexcor('7b6f4a'))
    dorsal(p, f, .76, .8, .03, hexcor('9a9a88'), hexcor('9a9a88'), forma=((0, 0), (.3, 1), (1, .6)))
    dorsal(p, f, .55, .82, .055, amarelo, ocre, forma=((0, 0), (.15, 1), (1, .35)), base_neg=True)
    peitoral(p, f, .2, .1, hexcor('d6c48a'))
    pelvica(p, f, .45, .07, amarelo)
    olho_em(p, f, .1, .03, 'c9c4b0')
    return p


def acara():
    p = Peixe('acara')
    f = Forma([(0, .025), (.07, .1), (.17, .19), (.32, .235), (.55, .215), (.76, .14), (.9, .085), (1, .075)],
              [(0, -.03), (.1, -.095), (.26, -.17), (.46, -.19), (.66, -.145), (.86, -.08), (1, -.072)],
              [(0, .02), (.2, .085), (.42, .1), (.75, .055), (1, .028)])
    faixas = lambda t, z, lat, c: mistura(c, hexcor('3f4a2e'), .38 if (math.sin(t*40) > .6 and z > -.4) else 0.0)
    azul = lambda t, z, lat, c: mistura(c, hexcor('6a9cb2'), .6 if (t < .2 and math.sin(z*26+t*30) > .55) else 0.0)
    cor = colorir('3c4a2e', '8f9a62', 'd8cf9c', None, juntar(faixas, azul, mancha(.42, .05, .045, '151812')))
    p.corpo(f, cor)
    nad, raio = hexcor('6d7448'), hexcor('a4b0c8')
    caudal(p, f, nad, raio, .13, rabo='redonda', comp=.17)
    dorsal(p, f, .3, 1.0, .09, nad, raio, forma=((0, 0), (.08, .9), (.6, .8), (.9, 1.25), (1, .6)), raios=16)
    dorsal(p, f, .68, 1.0, .1, nad, raio, forma=((0, 0), (.15, .8), (.8, 1.2), (1, .5)), base_neg=True, raios=9)
    peitoral(p, f, .26, .1, hexcor('a8a36a'), alto=.4)
    pelvica(p, f, .3, .11, nad)
    olho_em(p, f, .13, .038, 'b8662e', alto=.64)
    return p


def piau():
    p = Peixe('piau')
    f = Forma([(0, .012), (.08, .05), (.24, .105), (.42, .13), (.6, .115), (.8, .065), (1, .048)],
              [(0, -.016), (.1, -.055), (.3, -.1), (.5, -.112), (.76, -.068), (1, -.046)],
              [(0, .014), (.2, .06), (.45, .07), (.8, .038), (1, .02)])
    pontos = juntar(mancha(.3, .05, .028, '23221a'), mancha(.48, .05, .028, '23221a'), mancha(.68, .05, .028, '23221a'),
                    lambda t, z, l, c: mistura(c, hexcor('3d3c2e'), .3 if math.sin(t*90)*math.sin(z*14) > .5 and z > 0 else 0))
    cor = colorir('5a5844', 'b2a77c', 'e4dcc0', None, pontos)
    p.corpo(f, cor)
    nad, escuro = hexcor('8e7f55'), hexcor('5d5338')
    caudal(p, f, nad, escuro, .13, garfo=.9, comp=.19)
    dorsal(p, f, .36, .5, .085, nad, escuro)
    dorsal(p, f, .8, .86, .028, nad, nad, forma=((0, 0), (.4, 1), (1, .5)))
    dorsal(p, f, .66, .86, .06, hexcor('c08a4a'), nad, forma=((0, 0), (.2, 1), (1, .3)), base_neg=True)
    peitoral(p, f, .2, .09, hexcor('c49a5a'))
    pelvica(p, f, .46, .07, hexcor('c49a5a'))
    olho_em(p, f, .1, .028, 'c9b46e')
    return p


def traira():
    p = Peixe('traira')
    f = Forma([(0, .028), (.05, .058), (.15, .085), (.35, .1), (.6, .097), (.8, .07), (1, .058)],
              [(0, -.04), (.08, -.078), (.25, -.096), (.5, -.098), (.76, -.068), (1, -.054)],
              [(0, .035), (.15, .075), (.35, .082), (.7, .058), (1, .028)])
    pintas = lambda t, z, lat, c: mistura(c, hexcor('1f1d14'), .65 if (math.sin(t*61+z*9)*math.sin(z*17-t*23) > .35 and z > -.5) else 0.0)
    cor = colorir('2f2d1e', '6b6747', 'bdb39a', None, pintas)
    p.corpo(f, cor)
    nad, escuro = hexcor('4c4630'), hexcor('1e1c14')
    caudal(p, f, nad, escuro, .11, rabo='redonda', comp=.17)
    dorsal(p, f, .4, .62, .085, nad, escuro, forma=((0, 0), (.15, 1), (.8, .9), (1, .4)), raios=11)
    dorsal(p, f, .7, .9, .06, nad, escuro, forma=((0, 0), (.2, 1), (1, .4)), base_neg=True)
    peitoral(p, f, .2, .09, nad, alto=.3)
    pelvica(p, f, .45, .08, nad)
    olho_em(p, f, .09, .024, 'b39b4e', alto=.75)
    for s in (1, -1):
        a = p.ponto((.03*s, -.5, -.012), hexcor('2a2418'))
        b = p.ponto((.072*s, -.37, -.022), hexcor('2a2418'))
        c = p.ponto((.07*s, -.38, -.045), hexcor('2a2418'))
        p.f.append((a, b, c) if s > 0 else (a, c, b))
    return p


def jundia():
    p = Peixe('jundia')
    f = Forma([(0, .02), (.06, .042), (.2, .07), (.42, .09), (.62, .082), (.82, .058), (1, .045)],
              [(0, -.025), (.08, -.048), (.3, -.076), (.56, -.08), (.82, -.048), (1, -.04)],
              [(0, .045), (.1, .09), (.3, .088), (.6, .062), (1, .024)])
    manchas = lambda t, z, lat, c: mistura(c, hexcor('2e2820'), .45 if (math.sin(t*37+z*5)*math.sin(z*11+t*13) > .4 and z > -.2) else 0.0)
    cor = colorir('4a4036', '8a7a66', 'd4c8b4', None, manchas)
    p.corpo(f, cor)
    nad, escuro = hexcor('5b4e40'), hexcor('3a3129')
    caudal(p, f, nad, escuro, .1, garfo=.55, comp=.18)
    dorsal(p, f, .3, .4, .08, nad, escuro)
    dorsal(p, f, .55, .95, .04, nad, nad, forma=((0, 0), (.1, .8), (.9, 1), (1, .5)), raios=0)
    dorsal(p, f, .7, .92, .05, nad, escuro, forma=((0, 0), (.2, 1), (1, .4)), base_neg=True)
    peitoral(p, f, .2, .12, nad, alto=.25, caida=.3)
    pelvica(p, f, .5, .08, nad)
    olho_em(p, f, .1, .015, '8f826a', alto=.8)
    barb = hexcor('3a3129')
    p.barbilhao((.05, -.48, .0), (.2, -.15, -.03), .005, barb)
    p.barbilhao((.025, -.48, -.02), (.09, -.36, -.08), .0035, barb)
    p.barbilhao((.012, -.47, -.024), (.05, -.38, -.085), .0035, barb)
    return p


def robalo():
    p = Peixe('robalo')
    f = Forma([(0, .0), (.07, .03), (.17, .065), (.3, .108), (.45, .115), (.66, .09), (.86, .052), (1, .044)],
              [(0, -.022), (.08, -.055), (.25, -.096), (.45, -.105), (.7, -.072), (.88, -.046), (1, -.043)],
              [(0, .01), (.2, .05), (.45, .06), (.8, .032), (1, .017)])
    cor = colorir('5c6660', 'c4cbc4', 'f0f0e8', '161816')
    p.corpo(f, cor)
    nad, escuro = hexcor('8e9690'), hexcor('4d524f')
    caudal(p, f, nad, escuro, .14, garfo=.7, comp=.2)
    dorsal(p, f, .36, .52, .1, nad, escuro, forma=((0, 0), (.2, 1), (.6, .7), (1, .15)), raios=8)
    dorsal(p, f, .56, .72, .08, nad, escuro, forma=((0, 0), (.25, 1), (1, .3)))
    dorsal(p, f, .66, .8, .075, hexcor('d3c27a'), nad, forma=((0, 0), (.3, 1), (1, .3)), base_neg=True)
    peitoral(p, f, .22, .085, hexcor('c8c4a8'))
    pelvica(p, f, .3, .08, hexcor('d9c67e'))
    olho_em(p, f, .1, .026, 'c9b26a', alto=.7)
    return p


def camurupim():
    p = Peixe('camurupim')
    f = Forma([(0, .03), (.06, .055), (.18, .095), (.35, .128), (.5, .125), (.7, .085), (.88, .048), (1, .043)],
              [(0, .0), (.04, -.045), (.15, -.095), (.35, -.122), (.6, -.095), (.85, -.048), (1, -.043)],
              [(0, .014), (.2, .05), (.45, .056), (.8, .028), (1, .015)])
    escamas = lambda t, z, lat, c: mistura(c, hexcor('ffffff'), .2 if (math.sin(t*70)*math.sin(z*12) > .2) else 0.0)
    cor = colorir('3f5560', 'cfd8d8', 'f4f5f0', None, escamas)
    p.corpo(f, cor)
    nad, escuro = hexcor('7f8e93'), hexcor('46545a')
    caudal(p, f, nad, escuro, .19, garfo=1.0, comp=.2)
    dorsal(p, f, .46, .6, .1, nad, escuro, forma=((0, 0), (.25, 1), (.8, .5), (1.4, 1.5), (1, .1)))
    dorsal(p, f, .66, .82, .08, nad, escuro, forma=((0, 0), (.2, 1), (1, .3)), base_neg=True)
    peitoral(p, f, .2, .1, nad, alto=.3)
    pelvica(p, f, .4, .08, nad)
    olho_em(p, f, .09, .03, 'c9c2a0', alto=.62)
    return p


def principal():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    feitos = []
    for i, fn in enumerate([lambari, acara, piau, traira, jundia, robalo, camurupim]):
        ob = fn().criar()
        ob.location.x = i*1.2
        feitos.append(ob)
    bpy.ops.wm.save_as_mainfile(filepath=str(RAIZ/'art/blender/peixes.blend'))
    for ob in feitos:
        ob.location.x = 0
    destino = RAIZ/'assets/models/peixes/peixes.glb'
    destino.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(destino), export_cameras=False, export_lights=False, export_vertex_color='ACTIVE')
    for ob in feitos:
        print('PEIXE', ob.name, len(ob.data.vertices))
    print('PEIXES PRONTOS')


if __name__ == '__main__':
    principal()
