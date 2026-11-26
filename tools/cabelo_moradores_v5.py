"""Cabelo dos moradores — revisão 5 (mechas).

Substitui a casca única da revisão 4 (lisa, chapada e com volume de "protetor
de orelha") por um couro cabeludo fino e escuro coberto por dezenas de mechas:
 - cada mecha é um feixe achatado e afinado na ponta; nasce na risca/coroa,
   percorre o crânio por arcos (slerp de direções a partir do centro da cabeça)
   e cai por gravidade, contornando pescoço e ombros;
 - as orelhas ficam livres: o cabelo passa por cima e por trás delas;
 - largura, comprimento, ondulação e pontas variam com semente fixa por
   personagem (o resultado é reproduzível);
 - três tons (raiz, mecha e reflexo) dão profundidade sem ficar chapado.
Estilos soltos: longo, ombros, franja, curto. Presos: coque, rabo, tranca.
Todos os materiais têm 'Cabelo' no nome: o rig de batalha prende esses
vértices ao osso da cabeça.

Uso: exec deste arquivo num dicionário e chamar gerar(...) (ver
tools/variar_moradores_v4.py).
"""
import bpy, bmesh, math, random, zlib
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

PI = math.pi
CIMA = Vector((0, 0, 1))

# Linha do cabelo: altura em relação aos olhos por |azimute| (0 = testa, PI = nuca).
# Testa, têmpora, costeleta, acima da orelha, atrás da orelha e nuca.
LINHA = [(0, .086), (.8, .074), (1.15, .05), (1.32, .006), (1.48, -.016), (1.6, .056),
         (2.02, .056), (2.16, -.02), (2.42, -.075), (PI, -.085)]
COMPRIMENTO = {'longo': (.26, .40), 'ombros': (.17, .17), 'franja': (.36, .36), 'curto': (.0, .0)}


def suave(a, b, x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3-2*t)


def tabela(t, x):
    x = abs(x)
    for (x0, y0), (x1, y1) in zip(t, t[1:]):
        if x <= x1:
            return y0+(y1-y0)*suave(x0, x1, x)
    return t[-1][1]


def linear(hexa):
    c = [int(hexa[i:i+2], 16)/255 for i in (0, 2, 4)]
    return tuple(((v+.055)/1.055)**2.4 if v > .04045 else v/12.92 for v in c)+(1.0,)


def misturar(a, b, t):
    ca = [int(a[i:i+2], 16) for i in (0, 2, 4)]
    cb = [int(b[i:i+2], 16) for i in (0, 2, 4)]
    return ''.join('%02x' % round(x+(y-x)*t) for x, y in zip(ca, cb))


def material(nome, cor, aspereza):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value = linear(cor)
    bs.inputs['Roughness'].default_value = aspereza
    if 'Coat Weight' in bs.inputs:
        bs.inputs['Coat Weight'].default_value = 0.0
    # Brilho mais contido: cabelo seco, não plástico molhado.
    if 'Specular IOR Level' in bs.inputs:
        bs.inputs['Specular IOR Level'].default_value = .35
    return m


# ---------------------------------------------------------------- geometria

def reamostrar(pts, n):
    acum = [0.0]
    for k in range(1, len(pts)):
        acum.append(acum[-1]+(pts[k]-pts[k-1]).length)
    total = acum[-1] or 1e-6
    res, j = [], 0
    for k in range(n):
        alvo = total*k/(n-1)
        while j < len(pts)-2 and acum[j+1] < alvo:
            j += 1
        t = (alvo-acum[j])/max(1e-9, acum[j+1]-acum[j])
        res.append(pts[j].lerp(pts[j+1], min(1.0, max(0.0, t))))
    return res


def alisar(pts, vezes=2):
    for _ in range(vezes):
        pts = [pts[0]]+[pts[i]*.5+(pts[i-1]+pts[i+1])*.25 for i in range(1, len(pts)-1)]+[pts[-1]]
    return pts


def comprimento(pts):
    return sum((pts[k]-pts[k-1]).length for k in range(1, len(pts)))


def moldura(pts, j, c):
    """Tangente, 'fora' (radial a partir da cabeça) e 'lado' de um ponto."""
    n = len(pts)
    t = (pts[min(n-1, j+1)]-pts[max(0, j-1)])
    t = t.normalized() if t.length > 1e-9 else Vector((0, 0, -1))
    p = pts[j]
    fora = p-Vector((c.x, c.y, min(p.z, c.z)))
    fora = fora-t*fora.dot(t)
    fora = fora.normalized() if fora.length > 1e-6 else t.orthogonal().normalized()
    return t, fora, t.cross(fora).normalized()


def ondular(pts, c, rng, amp, freq, levanta):
    fase = rng.uniform(0, 2*PI)
    n = len(pts)
    res = []
    for j, p in enumerate(pts):
        s = j/(n-1)
        _, fora, lado = moldura(pts, j, c)
        res.append(p+lado*amp*s**1.3*math.sin(2*PI*freq*s+fase)+fora*levanta*suave(.65, 1, s))
    return res


def feixe(pts, c, largura, achatado, perfil, lados=6):
    """Tubo de seção elíptica (largura no 'lado', espessura no 'fora'), normais para fora."""
    verts, faces = [], []
    n = len(pts)
    for j, p in enumerate(pts):
        _, fora, lado = moldura(pts, j, c)
        w = largura*max(.02, perfil(j/(n-1)))
        for i in range(lados):
            ang = 2*PI*i/lados
            verts.append(p+lado*math.cos(ang)*w+fora*math.sin(ang)*w*achatado)
    for j in range(n-1):
        for i in range(lados):
            k = (i+1) % lados
            faces.append((j*lados+i, (j+1)*lados+i, (j+1)*lados+k, j*lados+k))
    faces.append(tuple(range(lados)))
    faces.append(tuple(reversed(range((n-1)*lados, n*lados))))
    return verts, faces


def perfil_solto(s):
    """Raiz fina (some no couro), corpo cheio, ponta afinada."""
    return (.2+.8*suave(0, .16, s))*(1-.94*suave(.5, 1, s)**1.2)


def perfil_preso(s):
    """Penteado puxado: afina pouco no fim, que some sob a amarra."""
    return (.2+.8*suave(0, .16, s))*(1-.45*suave(.7, 1, s))


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


def anel(centro, eixo, raio, grossura, lados=8, seg=20):
    """Amarra: toro em volta de 'eixo'."""
    e1 = eixo.orthogonal().normalized()
    e2 = eixo.cross(e1).normalized()
    pts = [centro+(e1*math.cos(2*PI*k/seg)+e2*math.sin(2*PI*k/seg))*raio for k in range(seg)]
    verts, faces = [], []
    for j, p in enumerate(pts):
        fora = (p-centro).normalized()
        for i in range(lados):
            ang = 2*PI*i/lados
            verts.append(p+fora*math.cos(ang)*grossura+eixo*math.sin(ang)*grossura)
    for j in range(seg):
        jj = (j+1) % seg
        for i in range(lados):
            k = (i+1) % lados
            faces.append((j*lados+i, jj*lados+i, jj*lados+k, j*lados+k))
    return verts, faces


# ---------------------------------------------------------------- cabeça

class Cabeca:
    def __init__(self, corpo, olhos_z):
        self.bvh = BVHTree.FromObject(corpo, bpy.context.evaluated_depsgraph_get())
        vs = [v.co for v in corpo.data.vertices]
        cab = [p for p in vs if p.z > olhos_z-.02]
        self.c = Vector((0, (min(p.y for p in cab)+max(p.y for p in cab))/2+.005, olhos_z+.035))
        self.oz = olhos_z

    def direcao(self, a, phi):
        return (math.sin(phi)*Vector((math.sin(a), -math.cos(a), 0))+math.cos(phi)*CIMA).normalized()

    def azimute(self, p):
        return math.atan2(p.x-self.c.x, -(p.y-self.c.y))

    def couro(self, u, folga=0.0):
        hit = self.bvh.ray_cast(self.c+u*.5, -u, .5)[0]
        return None if hit is None else hit+u*folga

    def na_altura(self, a, z):
        """Direção (a partir do centro da cabeça) cujo ponto no couro fica na altura z."""
        lo, hi = math.radians(2), math.radians(150)
        for _ in range(22):
            mid = (lo+hi)/2
            p = self.couro(self.direcao(a, mid))
            if p is None or p.z < z:
                hi = mid
            else:
                lo = mid
        return self.direcao(a, (lo+hi)/2)

    def linha(self, a):
        return self.oz+tabela(LINHA, a)

    def trilha(self, ctrl, folga, passos=22):
        """Percorre o couro passando pelas direções de controle (slerp por trechos)."""
        # Trechos quase opostos teriam o arco indefinido (podia cruzar o rosto):
        # um ponto intermediário puxado para cima força o caminho por cima da cabeça.
        seguro = [ctrl[0]]
        for u in ctrl[1:]:
            if seguro[-1].angle(u, 0.0) > math.radians(95):
                seguro.append((seguro[-1]+u+CIMA*.8).normalized())
            seguro.append(u)
        ctrl = seguro
        angs =[ctrl[i].angle(ctrl[i+1], 0.0) for i in range(len(ctrl)-1)]
        total = sum(angs) or 1e-6
        pts = []
        for k in range(passos+1):
            alvo = total*k/passos
            i, acc = 0, 0.0
            while i < len(angs)-1 and acc+angs[i] < alvo:
                acc += angs[i]
                i += 1
            t = min(1.0, (alvo-acc)/max(angs[i], 1e-6))
            u = ctrl[i].slerp(ctrl[i+1], t, ctrl[i]).normalized()
            p = self.couro(u, folga(k/passos))
            if p is not None:
                pts.append(p)
        return pts

    def cair(self, p, fim_z, cola):
        """Mecha caindo: abaixo do pescoço gira para as costas (passa por trás dos
        ombros) e assenta a 'cola' metros da pele."""
        c, oz = self.c, self.oz
        a = self.azimute(p)
        pts = []
        p = p.copy()
        passos = 0
        while p.z-.02 > fim_z and passos < 80:
            passos += 1
            p = p+Vector((0, 0, -.02))
            # Gira para trás antes de chegar ao ombro (evita pontas espetadas nele).
            descida = suave(0, .12, (oz-.06)-p.z)
            a_ef = a+math.copysign((PI-abs(a))*.72*descida, a) if abs(a) > .45 else a
            dirh = Vector((math.sin(a_ef), -math.cos(a_ef), 0))
            horiz = Vector((p.x-c.x, p.y-c.y, 0))
            hit = self.bvh.ray_cast(Vector((c.x, c.y, p.z))+dirh*.6, -dirh, .6)[0]
            if hit is not None:
                alvo_r = Vector((hit.x-c.x, hit.y-c.y, 0)).length+cola
                novo_r = horiz.length+(alvo_r-horiz.length)*.45
                p = Vector((c.x, c.y, p.z))+horiz.normalized().lerp(dirh, .35).normalized()*novo_r
            perto, normal, _, _ = self.bvh.find_nearest(p)
            if perto is not None and (p-perto).dot(normal) < cola:
                # Empurra só na horizontal: no ombro a normal aponta para cima.
                lado = Vector((normal.x, normal.y, 0))
                lado = lado.normalized() if lado.length > 1e-4 else dirh
                fora = Vector((p.x-perto.x, p.y-perto.y, 0)).dot(lado)
                p = p+lado*max(0.0, cola-fora)
            pts.append(p.copy())
        if pts and pts[-1].z > fim_z:
            fimp = pts[-1].copy()
            fimp.z = fim_z
            pts.append(fimp)
        return pts


# ---------------------------------------------------------------- penteados

class Penteado:
    def __init__(self, cab, rng, mats):
        self.cab, self.rng, self.mats = cab, rng, mats
        self.pecas = []

    def material_mecha(self):
        return self.mats['reflexo'] if self.rng.random() < .3 else self.mats['mecha']

    def adicionar(self, pts, largura, achatado=.34, perfil=perfil_solto, amp=.005, freq=1.4, levanta=.0,
                  aneis=None, mat=None):
        if len(pts) < 3 or comprimento(pts) < .015:
            return
        n = aneis or max(8, min(26, int(comprimento(pts)/.018)+6))
        pts = alisar(reamostrar(pts, n), 2)
        pts = ondular(pts, self.cab.c, self.rng, amp, freq, levanta)
        v, f = feixe(pts, self.cab.c, largura, achatado, perfil)
        self.pecas.append((v, f, mat if mat is not None else self.material_mecha()))

    def folga(self, base, volume=.004):
        # Raiz enterrada no couro; altura própria por mecha (mechas no mesmo
        # nível cintilam ao se cruzar).
        base *= self.rng.uniform(.8, 1.45)
        return lambda t: .0005+(base-.0005)*suave(0, .22, t)+volume*math.sin(PI*min(1.0, t))

    def solta(self, ctrl, base, fim_z, largura, cola=.016, volume=.004, ponta=.02, mat=None, amp=.006,
              levanta=.0, perfil=perfil_solto):
        """Mecha solta: percorre o couro e cai até fim_z (ou só solta a ponta)."""
        cab = self.cab
        pts = cab.trilha(ctrl, self.folga(base, volume))
        if len(pts) < 3:
            return
        if fim_z < pts[-1].z-.025:
            pts += cab.cair(pts[-1], fim_z, cola)
        else:
            t = (pts[-1]-pts[-2]).normalized()
            pts.append(pts[-1]+t*ponta)
        self.adicionar(pts, largura, amp=amp, levanta=levanta, mat=mat, perfil=perfil)

    # -- soltos

    def soltos(self, estilo, fem):
        cab, rng = self.cab, self.rng
        oz = cab.oz
        if estilo == 'curto':
            return self.curto()
        comp = COMPRIMENTO[estilo][1 if fem else 0]
        risca = 0.0 if estilo == 'franja' else rng.choice((-1, 1))*.38
        coroa = cab.direcao(PI, math.radians(20))
        frente_risca = cab.direcao(risca, math.radians(44 if estilo != 'franja' else 26))
        normal_risca = frente_risca.cross(coroa).normalized()

        def raiz(f, destino):
            u = frente_risca.slerp(coroa, max(0.0, min(1.0, f)), coroa)
            lado = 1 if destino.dot(normal_risca) > 0 else -1
            return (u+normal_risca*lado*rng.uniform(.03, .06)).normalized()

        def fim(a, fator=1.0):
            lateral = suave(.55, 1.35, abs(a))
            return oz-comp*(.55+.45*lateral)*fator*rng.uniform(.9, 1.04)

        # Costas: das orelhas para trás, saem do occipital e cobrem a nuca.
        for s in (-1, 1):
            for k in range(15):
                x = min(PI, 2.3+(PI-2.3)*(k+rng.uniform(-.4, .4))/14)
                sai = cab.na_altura(s*x, oz+rng.uniform(-.035, .0))
                f = .45+.55*(x-2.3)/(PI-2.3)+rng.uniform(-.12, .12)
                self.solta([raiz(f, sai), sai], rng.uniform(.010, .016), fim(s*x), rng.uniform(.019, .027))
        # Laterais: passam por cima da orelha e descem por trás dela.
        for s in (-1, 1):
            for k in range(9):
                via = cab.na_altura(s*(1.52+.58*(k+rng.uniform(-.3, .3))/8), oz+rng.uniform(.066, .095))
                a_sai = s*(2.25+.22*k/8+rng.uniform(-.04, .04))
                sai = cab.na_altura(a_sai, oz+rng.uniform(-.02, .012))
                self.solta([raiz(.4+.5*k/8+rng.uniform(-.06, .06), sai), via, sai], rng.uniform(.012, .018),
                           fim(a_sai), rng.uniform(.018, .025))
        if estilo == 'franja':
            # Franja reta na testa; as pontas laterais descem emoldurando o rosto.
            for k in range(25):
                a = -1.12+2.24*(k+rng.uniform(-.3, .3))/24
                lateral = suave(.72, 1.05, abs(a))
                sai = cab.na_altura(a, cab.linha(a)+.004)
                ini = cab.direcao(a*.35, math.radians(rng.uniform(14, 24)))
                alvo = oz+.026+rng.uniform(-.004, .004)
                alvo = alvo+(oz-.07*rng.uniform(.8, 1.2)-alvo)*lateral
                self.solta([ini, sai], rng.uniform(.011, .016), alvo, rng.uniform(.018, .024), cola=.010,
                           amp=.003, levanta=.002,
                           perfil=lambda s: (.55+.45*suave(0, .12, s))*(1-.75*suave(.55, 1, s)))
        else:
            # Frente: varrida da risca para as têmporas, em camadas. As de baixo
            # acompanham a linha da testa (sem faixa de couro aparente) e caem ao
            # lado do rosto.
            varrida = -1 if risca > 0 else 1
            for s in (-1, 1):
                n = 11 if s == varrida else 7
                for k in range(n):
                    b = (k/(n-1))**1.3
                    a_sai = s*rng.uniform(1.18, 1.38)
                    sai = cab.na_altura(a_sai, cab.linha(a_sai)+.01)
                    ctrl = []
                    for frac in (.3, .65):
                        a_v = risca+(a_sai-risca)*(frac+rng.uniform(-.06, .06))
                        ctrl.append(cab.na_altura(a_v, cab.linha(a_v)+.003+.045*b))
                    self.solta([raiz(rng.uniform(0, .2)+.3*b, ctrl[0])]+ctrl+[sai], rng.uniform(.010, .015)+.004*b,
                               fim(a_sai, rng.uniform(.72, .9)), rng.uniform(.019, .026))
            # Têmporas: cobrem a faixa entre a testa e a orelha.
            for s in (-1, 1):
                for k in range(5):
                    a_t = s*(1.12+.42*(k+rng.uniform(-.3, .3))/4)
                    alvo_t = cab.na_altura(a_t, cab.linha(a_t)+.004)
                    self.solta([raiz(rng.uniform(.15, .45), alvo_t), alvo_t], rng.uniform(.009, .013),
                               fim(a_t, rng.uniform(.6, .8)), rng.uniform(.02, .026))
        # Forro: camada interna rente à nuca, mais escura, preenche a cortina.
        if comp > .1:
            for s in (-1, 1):
                for k in range(7):
                    a = s*min(PI, 2.35+(PI-2.35)*(k+rng.uniform(-.3, .3))/6)
                    ini = cab.na_altura(a, cab.linha(a)+.035)
                    sai = cab.na_altura(a, cab.linha(a)+.004)
                    self.solta([ini, sai], .005, fim(a, .96), rng.uniform(.022, .03), cola=.008, volume=.0,
                               mat=self.mats['raiz'])

    def curto(self):
        """Curto: mechas irradiam do redemoinho até a linha do cabelo; pontas soltas."""
        cab, rng = self.cab, self.rng
        redemoinho = cab.direcao(PI, math.radians(24))
        for base, n, frac in ((.007, 46, 1.0), (.013, 34, .78)):
            for k in range(n):
                a = -PI+2*PI*(k+rng.uniform(0, 1))/n
                ini = (redemoinho+Vector((rng.uniform(-.1, .1), rng.uniform(-.1, .1), 0))).normalized()
                sai = cab.na_altura(a, cab.linha(a)+rng.uniform(.0, .01))
                if frac < 1:
                    sai = ini.slerp(sai, frac*rng.uniform(.85, 1.0), sai)
                pts = cab.trilha([ini, sai], self.folga(base, .003), passos=16)
                if len(pts) < 3:
                    continue
                t = (pts[-1]-pts[-2]).normalized()
                pts.append(pts[-1]+t*rng.uniform(.012, .024))
                self.adicionar(pts, rng.uniform(.017, .024), amp=.003, freq=1.0, levanta=rng.uniform(.002, .006))

    # -- presos

    def puxado(self, alvo):
        """Cabelo puxado da linha do cabelo até a amarra, contornando as orelhas."""
        cab, rng = self.cab, self.rng
        oz = cab.oz
        for base, n, recuo in ((.007, 62, 0.0), (.012, 34, .35)):
            for k in range(n):
                a = -PI+2*PI*(k+rng.uniform(0, 1))/n
                ini = cab.na_altura(a, cab.linha(a)+.004)
                if ini.angle(alvo) < math.radians(14):
                    continue
                ctrl = [ini]
                x = abs(a)
                if 1.15 < x < 2.3:
                    # Sobe antes de seguir para trás: passa por cima da orelha. Cada
                    # mecha usa um apoio próprio (as da frente passam mais alto),
                    # senão todas se empilham num tubo só.
                    z_v = oz+.098-.036*suave(1.15, 2.3, x)+rng.uniform(-.008, .008)
                    if x < 1.62:
                        ctrl.append(cab.na_altura(a, z_v))
                    a_v = max(x+.12, 1.9+rng.uniform(-.06, .08))
                    ctrl.append(cab.na_altura(math.copysign(a_v, a), z_v))
                ctrl.append(alvo)
                fol = self.folga(base, .002)
                pts = cab.trilha(ctrl, lambda t: fol(t)*(1-.6*suave(.85, 1, t)))
                if recuo:
                    # Camada de cima: o mesmo caminho, começando mais para trás.
                    pts = pts[int(len(pts)*recuo*rng.uniform(.6, 1.2)):]
                self.adicionar(pts, rng.uniform(.018, .025), perfil=perfil_preso, amp=.0015, freq=1.0)

    def rabo(self):
        cab, rng = self.cab, self.rng
        alvo = (cab.c+Vector((0, .105, .035))-cab.c).normalized()
        self.puxado(alvo)
        base = cab.couro(alvo, .012)
        cam = [base, base+Vector((0, .04, -.03)), base+Vector((0, .058, -.13)), base+Vector((0, .053, -.26)),
               base+Vector((0, .038, -.38))]
        cam = alisar(reamostrar(cam, 24), 3)
        for k in range(26):
            ang = rng.uniform(0, 2*PI)
            r0 = math.sqrt(rng.random())*.017
            corte = int(24*rng.uniform(.78, 1.0))
            pts = []
            for j, p in enumerate(cam[:corte]):
                s = j/23
                t, fora, lado = moldura(cam, j, cab.c)
                abre = r0*(1+.7*math.sin(PI*min(1.0, s*1.4)))*(1-.45*s)
                pts.append(p+(lado*math.cos(ang+s*1.1)+fora*math.sin(ang+s*1.1))*abre)
            self.adicionar(pts, rng.uniform(.013, .018), achatado=.45, amp=.004, freq=1.2)
        eixo = (cam[2]-cam[0]).normalized()
        v, f = anel(base+eixo*.008, eixo, .019, .0055)
        self.pecas.append((v, f, self.mats['amarra']))

    def coque(self):
        cab, rng = self.cab, self.rng
        alvo = Vector((0, .088, .055)).normalized()
        self.puxado(alvo)
        centro = cab.couro(alvo, .006)
        e1 = Vector((1, 0, 0))
        e2 = alvo.cross(e1).normalized()
        R, r = .025, .015
        for k in range(8):
            fase = 2*PI*k/8
            pts = []
            for j in range(56):
                th = 2*PI*1.1*j/55+fase*.35
                giro = 1.5*th+fase
                pts.append(centro+alvo*(r*.95+r*math.sin(giro))+(e1*math.cos(th)+e2*math.sin(th))*(R+r*math.cos(giro)))
            self.adicionar(pts, rng.uniform(.012, .015), achatado=.5, perfil=lambda s: suave(0, .08, s)*(1-.8*suave(.85, 1, s)),
                           amp=.0, aneis=56)
        v, f = esfera(centro+alvo*.016, (.021, .021, .021), 14, 9)
        self.pecas.append((v, f, self.mats['mecha']))

    def tranca(self):
        cab, rng = self.cab, self.rng
        oz = cab.oz
        alvo = cab.na_altura(2.45, oz-.035)
        self.puxado(alvo)
        inicio = cab.couro(alvo, .014)
        cam = []
        for k in range(30):
            t = k/29
            p = inicio+Vector((.03*math.sin(t*1.2), -.15*math.sin(t*1.4), -.42*t))
            perto, normal, _, _ = cab.bvh.find_nearest(p)
            if perto is not None and (p-perto).dot(normal) < .03:
                p = perto+normal*.03
            cam.append(p)
        cam = alisar(reamostrar(cam, 90), 4)
        fim_tranca = int(90*.86)
        for fio in range(3):
            pts = []
            for j, p in enumerate(cam[:fim_tranca]):
                s = j/89
                t = (cam[min(89, j+1)]-cam[max(0, j-1)]).normalized()
                e1 = t.cross(CIMA)
                e1 = e1.normalized() if e1.length > 1e-4 else Vector((1, 0, 0))
                e2 = t.cross(e1).normalized()
                th = 2*PI*6.5*s+2*PI*fio/3
                amp = .013*(1-.35*s)
                pts.append(p+e1*amp*math.sin(th)+e2*amp*.55*math.sin(2*th))
            v, f = feixe(pts, cab.c, .0115, .62, lambda s: (.7+.3*suave(0, .05, s))*(1-.3*s))
            self.pecas.append((v, f, self.mats['mecha'] if fio != 1 else self.mats['reflexo']))
        eixo = (cam[fim_tranca]-cam[fim_tranca-3]).normalized()
        v, f = anel(cam[fim_tranca-1], eixo, .011, .0045)
        self.pecas.append((v, f, self.mats['amarra']))
        # Ponta solta abaixo da amarra.
        for k in range(7):
            ang = 2*PI*k/7+rng.uniform(-.3, .3)
            lado = eixo.orthogonal().normalized()
            lado = (Matrix.Rotation(ang, 3, eixo)@lado)
            p0 = cam[fim_tranca-1]
            pts = [p0+lado*.003, p0+eixo*.025+lado*.008, p0+eixo*rng.uniform(.05, .065)+lado*.012]
            self.adicionar(pts, .008, achatado=.5, amp=.0, aneis=8)


# ---------------------------------------------------------------- objeto

def couro_cabeludo(cab, folga=.0035, colunas=96, linhas=22, recuo_testa=0.0):
    """recuo_testa sobe a borda na testa: nos penteados varridos quem desenha a
    linha do cabelo são as mechas, e o couro fica escondido por baixo delas."""
    grade = []
    for i in range(colunas):
        a = -PI+2*PI*i/colunas
        limite = cab.linha(a)+recuo_testa*suave(1.3, .95, abs(a))
        col, phi = [], 0.0
        while phi <= math.radians(150):
            p = cab.couro(cab.direcao(a, phi), folga)
            if p is None or p.z < limite:
                break
            col.append(p)
            phi += math.radians(3)
        borda = cab.couro(cab.na_altura(a, limite), folga*.2)
        col.append(borda)
        col = reamostrar(col, linhas+1)
        # A borda afunda até a pele: a linha do cabelo não vira um degrau.
        col = [p.lerp(cab.couro((p-cab.c).normalized(), .0005) or p, suave(.8, 1, k/linhas)) for k, p in enumerate(col)]
        grade.append(col)
    verts = [p for col in grade for p in col]
    faces = []
    for i in range(colunas):
        j = (i+1) % colunas
        for k in range(linhas):
            faces.append((i*(linhas+1)+k, i*(linhas+1)+k+1, j*(linhas+1)+k+1, j*(linhas+1)+k))
    return verts, faces


def gerar(CENA, pessoa, corpo, olhos_z, h, fem, estilo, tag, cor):
    rng = random.Random(zlib.crc32(tag.encode()))
    cab = Cabeca(corpo, olhos_z)
    mats = {'raiz': material('Cabelo_'+tag+'_Raiz', misturar(cor, '000000', .12), .7),
            'mecha': material('Cabelo_'+tag, cor, .56),
            'reflexo': material('Cabelo_'+tag+'_Reflexo', misturar(cor, '6b4a33', .18), .5),
            'amarra': material('Cabelo_'+tag+'_Amarra', 'a5824c', .9)}
    lista = [mats['raiz'], mats['mecha'], mats['reflexo'], mats['amarra']]
    p = Penteado(cab, rng, mats)
    if estilo in ('coque', 'rabo', 'tranca'):
        getattr(p, estilo)()
    else:
        p.soltos(estilo, fem)
    v, f = couro_cabeludo(cab, recuo_testa=.014 if estilo in ('longo', 'ombros') else 0.0)
    pecas = [(v, f, mats['raiz'])]+p.pecas
    verts, faces, idx = [], [], []
    for vs, fs, m in pecas:
        base = len(verts)
        verts += vs
        faces += [tuple(i+base for i in fc) for fc in fs]
        idx += [lista.index(m)]*len(fs)
    malha = bpy.data.meshes.new(pessoa.name+'_Cabelo')
    malha.from_pydata([tuple(x) for x in verts], [], faces)
    for m in lista:
        malha.materials.append(m)
    for i, pol in enumerate(malha.polygons):
        pol.material_index = idx[i]
        pol.use_smooth = True
    bm = bmesh.new()
    bm.from_mesh(malha)
    # O polo do couro (todas as colunas nascem no topo) vira um vértice só.
    bmesh.ops.remove_doubles(bm, verts=[v for v in bm.verts if v.index < len(pecas[0][0])], dist=.0015)
    bm.to_mesh(malha)
    bm.free()
    malha.update()
    o = bpy.data.objects.new(pessoa.name+'_Cabelo', malha)
    CENA.collection.objects.link(o)
    o.parent = pessoa
    print('CABELO', tag, estilo, len(malha.vertices), 'vertices', len(p.pecas), 'mechas')
    return o
