"""Pinturas corporais dos moradores: jenipapo (preto-azulado) e urucum (vermelho).

Cada desenho é uma película de geometria a 1,6 mm da pele (traços nítidos sem
depender de UV/textura). As formas são descritas num espaço de parâmetros por
região (s = arco em volta do eixo, t = altura ou fração do membro) e projetadas
no corpo por raios a partir do eixo da região:
 - rosto e tronco: eixo vertical; s > 0 é o lado esquerdo do personagem (+x);
 - braços e pernas: eixo ombro→mão / quadril→tornozelo; t é fração do membro;
   s > 0 aponta para fora do corpo.
Os vértices herdam o peso 'braco' da pele mais próxima: acompanham as poses de
passo/coleta e o rig de batalha (o material não é roupa nem cabelo).
Cada personagem recebe um desenho próprio (DESENHOS). Interpretação artística
inspirada em pinturas indígenas brasileiras, sem reproduzir um padrão
específico de um povo.

Uso: exec deste arquivo num dicionário e chamar pintar(...)
(ver tools/variar_moradores_v4.py).
"""
import bpy, bmesh, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

PI = math.pi
FOLGA = .0016
CORES = {'J': ('Pintura_Jenipapo', '1b2230', .7), 'U': ('Pintura_Urucum', 'a8341c', .75)}


def linear(hexa):
    c = [int(hexa[i:i+2], 16)/255 for i in (0, 2, 4)]
    return tuple(((v+.055)/1.055)**2.4 if v > .04045 else v/12.92 for v in c)+(1.0,)


def material(nome, cor, aspereza):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value = linear(cor)
    bs.inputs['Roughness'].default_value = aspereza
    if 'Specular IOR Level' in bs.inputs:
        bs.inputs['Specular IOR Level'].default_value = .3
    return m


def bvh_filtrado(corpo, manter):
    bm = bmesh.new()
    bm.from_mesh(corpo.data)
    deform = bm.verts.layers.deform.active
    g = corpo.vertex_groups['braco'].index
    fora = [v for v in bm.verts if not manter(v.co, v[deform].get(g, 0.0) if deform else 0.0)]
    bmesh.ops.delete(bm, geom=fora, context='VERTS')
    arvore = BVHTree.FromBMesh(bm)
    bm.free()
    return arvore


class Regiao:
    """Projeção (s, t) → ponto na pele. Ponto do eixo = origem + eixo*t."""

    def __init__(self, bvh, origem, eixo, frente, lado, r0, alcance=.4):
        self.bvh, self.origem, self.eixo, self.r0, self.alcance = bvh, origem, eixo, r0, alcance
        u = eixo.normalized()
        self.frente = (frente-u*frente.dot(u)).normalized()
        self.lado = (lado-u*lado.dot(u)-self.frente*lado.dot(self.frente)).normalized()
        self.escala_t = eixo.length
        self.centros = None

    def centralizar(self, pontos, fatias=40):
        """Membros não são retos: o raio mira o centro da fatia, não o eixo."""
        soma = [[Vector(), 0] for _ in range(fatias+1)]
        l2 = self.eixo.length_squared
        for p in pontos:
            t = (p-self.origem).dot(self.eixo)/l2
            if 0 <= t <= 1:
                k = round(t*fatias)
                soma[k][0] += p
                soma[k][1] += 1
        self.centros = [(c/n if n else None) for c, n in soma]

    def base(self, t):
        if self.centros:
            f = max(0.0, min(1.0, t))*(len(self.centros)-1)
            i = min(len(self.centros)-2, int(f))
            a, b = self.centros[i], self.centros[i+1]
            if a is not None and b is not None:
                return a.lerp(b, f-i)
        return self.origem+self.eixo*t

    def mapear(self, s, t):
        th = s/self.r0
        d = self.frente*math.cos(th)+self.lado*math.sin(th)
        base = self.base(t)
        hit, n, _, _ = self.bvh.ray_cast(base+d*self.alcance, -d, self.alcance)
        if hit is None:
            return None
        if n.dot(d) < 0:
            n = -n
        return hit+n*FOLGA, n


class Pintor:
    def __init__(self, corpo, olhos, olhos_z, h, fem):
        self.h, self.fem, self.oz = h, fem, olhos_z
        vs = [v.co for v in corpo.data.vertices]
        g = corpo.vertex_groups['braco'].index
        self.peso = {v.index: next((x.weight for x in v.groups if x.group == g), 0.0) for v in corpo.data.vertices}
        self.kd = KDTree(len(vs))
        for i, p in enumerate(vs):
            self.kd.insert(p, i)
        self.kd.balance()
        cheio = BVHTree.FromObject(corpo, bpy.context.evaluated_depsgraph_get())
        frente, direita = Vector((0, -1, 0)), Vector((1, 0, 0))
        cab = [p for p in vs if p.z > olhos_z-.02]
        cy = (min(p.y for p in cab)+max(p.y for p in cab))/2+.005
        self.rosto = Regiao(cheio, Vector((0, cy, 0)), Vector((0, 0, 1)), frente, direita, .1)
        cintura = [p for p in vs if abs(p.z-.6*h) < .02 and abs(p.x) < .12*h/1.83]
        cy_t = sum(p.y for p in cintura)/len(cintura)
        self.r_tronco = .14
        self.tronco = Regiao(bvh_filtrado(corpo, lambda c, w: w < .25), Vector((0, cy_t, 0)), Vector((0, 0, 1)),
                             frente, direita, self.r_tronco)
        # Olhos: posição em s e altura; queixo achado pelo perfil frontal.
        self.olho_s = abs(math.atan2(olhos[0].x, -(olhos[0].y-cy)))*.1
        z = olhos_z-.08
        while z > olhos_z-.22:
            hit = cheio.ray_cast(Vector((0, cy-.5, z)), Vector((0, 1, 0)), .5)[0]
            if hit is None or cy-hit.y < .07:
                break
            z -= .004
        self.queixo = z+.004
        self.braco, self.perna = {}, {}
        for s in (1, -1):
            bv = [p for i, p in enumerate(vs) if p.x*s > 0 and self.peso[i] > .95]
            ponta = min(bv, key=lambda p: p.z)
            ombro = Vector((s*.091*h, ponta.y*.5, .786*h))
            self.braco[s] = Regiao(bvh_filtrado(corpo, lambda c, w, s=s: w > .5 and c.x*s > 0), ombro, ponta-ombro,
                                   frente, Vector((s, 0, 0)), .045, .25)
            self.braco[s].centralizar([p for i, p in enumerate(vs) if p.x*s > 0 and self.peso[i] > .5])
            alto = [p for p in vs if abs(p.z-.45*h) < .01 and p.x*s > .01]
            baixo = [p for p in vs if abs(p.z-.06*h) < .006 and p.x*s > .01]
            quadril = sum(alto, Vector())/len(alto)
            tornozelo = sum(baixo, Vector())/len(baixo)
            self.perna[s] = Regiao(bvh_filtrado(corpo, lambda c, w, s=s: c.z < .5*h and c.x*s > .004 and w < .25),
                                   quadril, tornozelo-quadril, frente, Vector((s, 0, 0)), .065, .3)
            self.perna[s].centralizar([p for i, p in enumerate(vs) if p.z < .5*h and p.x*s > .004 and self.peso[i] < .25])
        # Top das mulheres (não pintar por baixo dele).
        busto = min((p for p in vs if .68*h < p.z < .80*h and abs(p.x) < .1*h), key=lambda p: p.y)
        self.top = (busto.z-.075, busto.z+.063) if fem else None
        self.verts, self.faces, self.mats, self.normais = [], [], [], []

    # ------------------------------------------------------------ primitivas

    def _grade(self, reg, linhas, cor):
        """linhas: lista de listas de (s,t) (mesmo tamanho) → faixa de quads."""
        mapa = [[reg.mapear(s, t) for s, t in linha] for linha in linhas]
        idx = [[None]*len(linhas[0]) for _ in linhas]
        for i, linha in enumerate(mapa):
            for j, m in enumerate(linha):
                if m is not None:
                    idx[i][j] = len(self.verts)
                    self.verts.append(m[0])
                    self.normais.append(m[1])
        for i in range(len(linhas)-1):
            for j in range(len(linhas[0])-1):
                q = (idx[i][j], idx[i+1][j], idx[i+1][j+1], idx[i][j+1])
                if None in q:
                    continue
                a, b, c = (self.verts[k] for k in q[:3])
                if max((a-b).length, (b-c).length) > .05:   # raio escapou para outra parte
                    continue
                self.faces.append(q)
                self.mats.append(cor)

    def faixa(self, reg, pts, largura, cor, passo=.005, fechado=False):
        """Traço de largura constante ao longo de uma polilinha em (s, t)."""
        k = reg.escala_t
        met = lambda a, b: math.hypot(b[0]-a[0], (b[1]-a[1])*k)
        if fechado:
            pts = list(pts)+[pts[0]]
        acum = [0.0]
        for i in range(1, len(pts)):
            acum.append(acum[-1]+met(pts[i-1], pts[i]))
        n = max(2, int(acum[-1]/passo)+1)
        amostras = []
        j = 0
        for i in range(n):
            alvo = acum[-1]*i/(n-1)
            while j < len(pts)-2 and acum[j+1] < alvo:
                j += 1
            f = (alvo-acum[j])/max(1e-9, acum[j+1]-acum[j])
            amostras.append((pts[j][0]+(pts[j+1][0]-pts[j][0])*f, pts[j][1]+(pts[j+1][1]-pts[j][1])*f))
        m = max(1, math.ceil(largura/.008))
        linhas = []
        for i in range(m+1):
            off = largura*(i/m-.5)
            linha = []
            for a in range(n):
                p0 = amostras[max(0, a-1)]
                p1 = amostras[min(n-1, a+1)]
                ds, dt = p1[0]-p0[0], (p1[1]-p0[1])*k
                l = math.hypot(ds, dt) or 1
                linha.append((amostras[a][0]-dt/l*off, amostras[a][1]+ds/l*off/k))
            linhas.append(linha)
        self._grade(reg, linhas, cor)

    def zigue(self, reg, a, b, amp, n, largura, cor):
        k = reg.escala_t
        ds, dt = b[0]-a[0], (b[1]-a[1])*k
        l = math.hypot(ds, dt)
        px, pt = -dt/l, ds/l
        pts = []
        for i in range(2*n+1):
            f = i/(2*n)
            o = amp*(1 if i % 2 else -1)
            pts.append((a[0]+(b[0]-a[0])*f+px*o, a[1]+(b[1]-a[1])*f+pt*o/k))
        self.faixa(reg, pts, largura, cor, passo=.004)

    def disco(self, reg, c, r, cor, seg=12):
        k = reg.escala_t
        aneis = max(1, math.ceil(r/.006))
        linhas = []
        for i in range(aneis+1):
            rr = r*i/aneis
            linhas.append([(c[0]+rr*math.cos(2*PI*j/seg), c[1]+rr*math.sin(2*PI*j/seg)/k) for j in range(seg+1)])
        self._grade(reg, linhas, cor)

    def pontos(self, reg, a, b, n, r, cor):
        for i in range(n):
            f = i/(n-1) if n > 1 else .5
            self.disco(reg, (a[0]+(b[0]-a[0])*f, a[1]+(b[1]-a[1])*f), r, cor)

    def losango(self, reg, c, largura, altura, cor, cheio=True):
        k = reg.escala_t
        topo, dir_, base, esq = ((c[0], c[1]+altura/2/k), (c[0]+largura/2, c[1]), (c[0], c[1]-altura/2/k),
                                 (c[0]-largura/2, c[1]))
        if not cheio:
            self.faixa(reg, [topo, dir_, base, esq], .004, cor, fechado=True)
            return
        m = 4
        linhas = []
        for i in range(m+1):
            u = i/m
            a = (esq[0]+(topo[0]-esq[0])*u, esq[1]+(topo[1]-esq[1])*u)
            b = (base[0]+(dir_[0]-base[0])*u, base[1]+(dir_[1]-base[1])*u)
            linhas.append([(a[0]+(b[0]-a[0])*v/m, a[1]+(b[1]-a[1])*v/m) for v in range(m+1)])
        self._grade(reg, linhas, cor)

    def triangulo(self, reg, c, largura, altura, cor):
        """Triângulo com a ponta para baixo (pingente)."""
        k = reg.escala_t
        m = 4
        linhas = []
        for i in range(m+1):
            u = i/m
            a = (c[0]-largura/2+largura/2*u, c[1]-altura/k*u)
            b = (c[0]+largura/2-largura/2*u, c[1]-altura/k*u)
            linhas.append([(a[0]+(b[0]-a[0])*v/m, a[1]) for v in range(m+1)])
        self._grade(reg, linhas, cor)

    def anel(self, reg, t, largura, cor):
        volta = 2*PI*reg.r0
        self.faixa(reg, [(-volta/2+volta*i/24, t) for i in range(25)], largura, cor, passo=.006)

    def anel_zigue(self, reg, t, amp, n, largura, cor):
        volta = 2*PI*reg.r0
        self.zigue(reg, (-volta/2, t), (volta/2, t), amp, n, largura, cor)

    # ------------------------------------------------------------ objeto

    def objeto(self, CENA, pessoa):
        if not self.faces:
            return None
        usados = sorted({v for f in self.faces for v in f})
        novo = {v: i for i, v in enumerate(usados)}
        verts = [self.verts[v] for v in usados]
        faces = []
        for f in self.faces:
            q = [novo[v] for v in f]
            a, b, c = (self.verts[v] for v in f[:3])
            normal = (b-a).cross(c-a)
            if normal.dot(self.normais[f[0]]) < 0:
                q.reverse()
            faces.append(q)
        malha = bpy.data.meshes.new(pessoa.name+'_Pintura')
        malha.from_pydata([tuple(v) for v in verts], [], faces)
        ordem = ['J', 'U']
        for c in ordem:
            nome, cor, asp = CORES[c]
            malha.materials.append(material(nome, cor, asp))
        for i, p in enumerate(malha.polygons):
            p.material_index = ordem.index(self.mats[i])
            p.use_smooth = True
        malha.update()
        o = bpy.data.objects.new(pessoa.name+'_Pintura', malha)
        CENA.collection.objects.link(o)
        o.parent = pessoa
        grupo = o.vertex_groups.new(name='braco')
        for i, v in enumerate(verts):
            _, j, _ = self.kd.find(v)
            w = self.peso[j]
            if w > 0:
                grupo.add([i], w, 'REPLACE')
        return o


# ---------------------------------------------------------------- desenhos
# Traços largos o bastante para a câmera do jogo (corpo 8–14 mm, rosto 5–17 mm).

def luva(p, reg, centro, largura, cor):
    """Faixa cheia em volta do membro (antebraço/canela tingidos)."""
    volta = 2*PI*reg.r0
    p.faixa(reg, [(-volta/2+volta*i/24, centro) for i in range(25)], largura*reg.escala_t, cor)


def _homem_01(p):
    oz, h, R, T = p.oz, p.h, p.rosto, p.tronco
    for s in (1, -1):
        for dz in (0, -.017):
            p.faixa(R, [(s*.032, oz-.034+dz), (s*.06, oz-.03+dz), (s*.088, oz-.026+dz)], .006, 'J')
    for z, amp in ((.76*h, .02), (.70*h, .016)):
        p.zigue(T, (-.17, z), (.17, z), amp, 9, .01, 'J')
        for dz in (amp+.014, -amp-.014):
            p.faixa(T, [(-.17, z+dz), (.17, z+dz)], .008, 'J')
    for s in (1, -1):
        for u in (.17, .22, .27):
            p.anel(p.braco[s], u, .011, 'J')
        P = p.perna[s]
        p.faixa(P, [(0, .45), (0, .88)], .014, 'J')
        for o in (.03, -.03):
            p.pontos(P, (o, .47), (o, .86), 8, .006, 'J')


def _homem_02(p):
    oz, h, R, T = p.oz, p.h, p.rosto, p.tronco
    p.faixa(R, [(-.092, oz-.022), (-.045, oz-.03), (0, oz-.033), (.045, oz-.03), (.092, oz-.022)], .018, 'U')
    for s in (-.12, -.08, -.04, 0, .04, .08, .12):
        p.faixa(T, [(s, .79*h), (s*1.08, .6*h)], .012, 'J')
    costas = PI*p.r_tronco
    for s in (-.08, -.04, 0, .04, .08):
        p.faixa(T, [(costas+s, .8*h), (costas+s*1.05, .62*h)], .012, 'J')
    for s in (1, -1):
        B = p.braco[s]
        p.anel(B, .19, .024, 'U')
        for u in (.58, .63, .68):
            p.anel(B, u, .011, 'J')
        luva(p, p.perna[s], .72, .1, 'U')


def _homem_03(p):
    oz, h, R, T = p.oz, p.h, p.rosto, p.tronco
    for s in (1, -1):
        p.pontos(R, (s*.04, oz-.024), (s*.09, oz-.012), 6, .004, 'J')
    for s in (-.014, 0, .014):
        p.faixa(R, [(s, p.queixo+.034), (s, p.queixo+.006)], .005, 'J')
    for i in range(5):
        p.losango(T, (0, .775*h-.045*i), .05, .04, 'J')
    for s in (.045, -.045):
        p.faixa(T, [(s, .79*h), (s, .775*h-.045*4.4)], .008, 'J')
    costas = PI*p.r_tronco
    for i in range(4):
        p.losango(T, (costas, .78*h-.05*i), .05, .042, 'J')
    for s in (1, -1):
        p.zigue(p.braco[s], (.03, .07), (.03, .5), .02, 7, .009, 'J')
        P = p.perna[s]
        p.anel(P, .5, .02, 'U')
        p.anel(P, .56, .02, 'U')
        p.anel(P, .62, .01, 'J')


def _homem_04(p):
    oz, h, R, T = p.oz, p.h, p.rosto, p.tronco
    q = p.queixo
    p.faixa(R, [(-.082, oz-.088), (-.06, q+.04), (-.03, q+.018), (0, q+.014), (.03, q+.018), (.06, q+.04),
                (.082, oz-.088)], .024, 'J')
    for s in (1, -1):
        for dz in (0, -.028):
            p.faixa(T, [(s*.05, .80*h+dz), (s*.11, .79*h+dz), (s*.17, .77*h+dz)], .014, 'U')
        B = p.braco[s]
        luva(p, B, .68, .2, 'J')
        p.anel_zigue(B, .55, .014, 7, .008, 'J')
        P = p.perna[s]
        for o in (-.035, 0, .035):
            p.pontos(P, (o, .48), (o, .84), 7, .007, 'J')


def _mulher_01(p):
    oz, h, R, T = p.oz, p.h, p.rosto, p.tronco
    p.faixa(R, [(-.045, oz+.058), (0, oz+.062), (.045, oz+.058)], .012, 'U')
    for s in (1, -1):
        p.faixa(R, [(s*.048, oz-.026), (s*.062, oz-.045), (s*.072, oz-.064)], .004, 'J')
        p.faixa(R, [(s*.064, oz-.024), (s*.078, oz-.042), (s*.088, oz-.06)], .004, 'J')
    z = p.top[0]-.03
    p.faixa(T, [(-.14, z+.008), (0, z), (.14, z+.008)], .008, 'J')
    p.pontos(T, (-.12, z-.026), (.12, z-.026), 9, .0055, 'J')
    p.faixa(T, [(-.14, z-.05), (0, z-.056), (.14, z-.05)], .008, 'J')
    for s in (1, -1):
        for u in (.62, .66, .7, .74):
            p.anel(p.braco[s], u, .008, 'J')
        P = p.perna[s]
        luva(p, P, .89, .1, 'J')
        p.anel_zigue(P, .8, .016, 8, .009, 'J')


def _mulher_02(p):
    oz, h, R, T = p.oz, p.h, p.rosto, p.tronco
    for s in (-.013, 0, .013):
        p.faixa(R, [(s, p.queixo+.032), (s, p.queixo+.006)], .0045, 'J')
    for s in (1, -1):
        p.pontos(R, (s*.035, oz-.03), (s*.08, oz-.024), 5, .0035, 'J')
    z = .6*h
    p.zigue(T, (-.17, z), (.17, z), .016, 11, .009, 'J')
    p.faixa(T, [(-.17, z+.03), (.17, z+.03)], .008, 'J')
    p.faixa(T, [(-.17, z-.03), (.17, z-.03)], .012, 'U')
    for s in (1, -1):
        B = p.braco[s]
        for u in (.11, .19, .27):
            p.losango(B, (.03, u), .032, .042, 'J')
        P = p.perna[s]
        for o in (-.028, .028):
            p.faixa(P, [(o, .48), (o, .88)], .011, 'U')


def _mulher_03(p):
    oz, h, R, T = p.oz, p.h, p.rosto, p.tronco
    for s in (1, -1):
        p.disco(R, (s*.066, oz-.046), .015, 'U')
    p.pontos(R, (-.02, p.queixo+.02), (.02, p.queixo+.02), 3, .0035, 'J')
    costas = PI*p.r_tronco
    for i in range(-2, 3):
        p.faixa(T, [(costas+.035*i-.06, .785*h), (costas+.035*i+.06, .64*h)], .007, 'J')
        p.faixa(T, [(costas+.035*i+.06, .785*h), (costas+.035*i-.06, .64*h)], .007, 'J')
    p.zigue(T, (-.16, p.top[0]-.03), (.16, p.top[0]-.03), .014, 10, .008, 'J')
    p.pontos(T, (-.1, p.top[1]+.022), (.1, p.top[1]+.022), 7, .006, 'U')
    for s in (1, -1):
        B = p.braco[s]
        p.anel(B, .2, .024, 'U')
        p.anel(B, .6, .009, 'J')
        p.anel(B, .65, .009, 'J')
        for u in (.55, .62, .69):
            p.anel(p.perna[s], u, .011, 'J')


def _mulher_04(p):
    oz, h, R, T = p.oz, p.h, p.rosto, p.tronco
    p.faixa(R, [(-.088, oz-.022), (-.05, oz-.03), (0, oz-.034), (.05, oz-.03), (.088, oz-.022)], .006, 'J')
    p.pontos(R, (-.018, p.queixo+.016), (.018, p.queixo+.016), 3, .004, 'J')
    z = p.top[1]+.032
    p.faixa(T, [(-.13, z+.016), (-.06, z+.003), (0, z), (.06, z+.003), (.13, z+.016)], .007, 'J')
    for i in range(-3, 4):
        p.triangulo(T, (.034*i, z+.002*abs(i)-.004), .026, .028, 'J')
    p.zigue(T, (-.16, p.top[0]-.03), (.16, p.top[0]-.03), .012, 10, .008, 'U')
    for s in (1, -1):
        B = p.braco[s]
        luva(p, B, .7, .15, 'J')
        P = p.perna[s]
        for o in (-.03, .03):
            p.pontos(P, (o, .5), (o, .86), 7, .0075, 'U')


DESENHOS = {'homem_01': _homem_01, 'homem_02': _homem_02, 'homem_03': _homem_03, 'homem_04': _homem_04,
            'mulher_01': _mulher_01, 'mulher_02': _mulher_02, 'mulher_03': _mulher_03, 'mulher_04': _mulher_04}


def pintar(CENA, pessoa, corpo, olhos_z, h, fem, tag):
    olhos = [sum((v.co for v in o.data.vertices), Vector())/len(o.data.vertices)
             for o in pessoa.children if '.eye.' in o.name]
    p = Pintor(corpo, olhos, olhos_z, h, fem)
    DESENHOS[tag](p)
    o = p.objeto(CENA, pessoa)
    print('PINTURA', tag, len(o.data.vertices) if o else 0, 'vertices')
    return o
