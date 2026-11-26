"""Rig e animações dos moradores — vida na aldeia e batalha.

Uso (com janela; o script fecha o Blender ao terminar):
  blender --factory-startup --python tools/animar_moradores.py [-- homem_01 ...]
Lê assets/models/habitantes/<tag>.glb (modelo sem esqueleto) e grava:
 - assets/models/habitantes/batalha/<tag>.glb  clipes de batalha (nomes e tempos
   usados por scripts/encontros/combate_manual.gd: golpe de lança em ~0,53 s,
   flecha solta em ~0,72 s, corda puxada entre ~0,22 e 0,77 s);
 - assets/models/habitantes/aldeia/<tag>.glb   clipes da aldeia e ferramentas
   (Prop_*) presas aos ossos;
 - assets/models/habitantes/aldeia/animacao.json  velocidade da caminhada de cada
   corpo (o deslocamento no jogo usa esse valor: os pés não escorregam);
 - art/blender/moradores_animados.blend (fonte).

Rig: base, quadril, coluna, peito, pescoco, cabeca, braco/antebraco/mao, coxa/
canela/pe/dedos (E = esquerda, +x; D = direita, -x; frente = -y). Os ossos dos
braços são medidos como na versão anterior: as armas da batalha continuam presas
a mao_D/mao_E na mesma posição. Pernas e braços são posicionados por cinemática
inversa a cada quadro (pés plantados, mãos no alvo). As poses-chave são
interpoladas por Catmull-Rom (movimento contínuo, sem paradas bruscas).
"""
import bpy, math, json, sys, time, traceback
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion, Euler
from mathutils.kdtree import KDTree

RAIZ = Path(__file__).resolve().parents[1]
TAU = math.tau
FPS = 24
TAGS = [f'{s}_{i:02d}' for s in ('homem', 'mulher') for i in range(1, 5)]


def suave(a, b, x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3-2*t)


def dist_seg(p, a, b):
    d = b-a
    t = max(0.0, min(1.0, (p-a).dot(d)/max(d.length_squared, 1e-9)))
    return (p-a-d*t).length


def V(*c):
    return Vector(c)


def norm(*c):
    return Vector(c).normalized()


class Curva:
    """Catmull-Rom por poses-chave [(t, valor)], cíclica ou não. Valores: float ou Vector."""

    def __init__(self, chaves, ciclica=True):
        self.k = sorted(chaves, key=lambda c: c[0])
        self.ciclica = ciclica

    def __call__(self, t):
        k = self.k
        n = len(k)
        if n == 1:
            return k[0][1]
        if self.ciclica:
            t %= 1.0
            tt = [c[0] for c in k]
            i = max(j for j in range(n) if tt[j] <= t) if t >= tt[0] else n-1
            t1 = tt[i] if t >= tt[0] else tt[i]-1
            t2 = tt[(i+1) % n]+(1 if i+1 >= n else 0)
            p0, p1, p2, p3 = (k[(i+d) % n][1] for d in (-1, 0, 1, 2))
        else:
            if t <= k[0][0]:
                return k[0][1]
            if t >= k[-1][0]:
                return k[-1][1]
            i = max(j for j in range(n) if k[j][0] <= t)
            t1, t2 = k[i][0], k[i+1][0]
            p0, p1, p2, p3 = k[max(0, i-1)][1], k[i][1], k[i+1][1], k[min(n-1, i+2)][1]
        u = (t-t1)/max(1e-9, t2-t1)
        return 0.5*((2*p1)+(-p0+p2)*u+(2*p0-5*p1+4*p2-p3)*u*u+(-p0+3*p1-3*p2+p3)*u*u*u)


def chaves(base, lista):
    """lista: [(t, {param: valor})]; cada chave herda a anterior (poses completas)."""
    atual = dict(base)
    res = []
    for t, mud in lista:
        atual = dict(atual)
        atual.update(mud)
        res.append((t, atual))
    return res


def curvas(lista, ciclica=True):
    nomes = lista[0][1].keys()
    c = {n: Curva([(t, d[n]) for t, d in lista], ciclica) for n in nomes if d_ok(lista[0][1][n])}
    fixos = {n: lista[0][1][n] for n in nomes if not d_ok(lista[0][1][n])}
    return lambda t: {**fixos, **{n: f(t) for n, f in c.items()}}


def d_ok(v):
    return isinstance(v, (float, int, Vector))


# ---------------------------------------------------------------- morador

class Morador:
    def __init__(self, tag):
        self.tag = tag
        self.cena = bpy.data.scenes.new('Animado_'+tag)
        bpy.context.window.scene = self.cena
        bpy.ops.import_scene.gltf(filepath=str(RAIZ/'assets/models/habitantes'/(tag+'.glb')))
        self.malha = mesh = next(o for o in self.cena.objects if o.type == 'MESH')
        if mesh.data.shape_keys:
            mesh.shape_key_clear()
        bpy.context.view_layer.objects.active = mesh
        mesh.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        self.h = h = max(v.co.z for v in mesh.data.vertices)
        self.k = h/1.83
        self.medir()
        self.esqueleto()
        self.pesos()

    # ---- medidas

    def medir(self):
        h, mesh = self.h, self.malha
        vs = [v.co.copy() for v in mesh.data.vertices]
        mats = [m.name.lower() for m in mesh.data.materials]
        self.cabelo, self.roupa, self.saia = set(), set(), set()
        for f in mesh.data.polygons:
            n = mats[f.material_index]
            if 'cabelo' in n or 'mecha' in n:
                self.cabelo.update(f.vertices)
            if any(t in n for t in ('barro', 'fibra', 'musgo', 'tecido', 'saia')):
                self.roupa.update(f.vertices)
            if 'saia' in n:
                self.saia.update(f.vertices)
        # Peso do braço exato: o grupo 'braco' da anatomia de origem (o braço é uma
        # peça separada do tronco abaixo da axila; o ombro tem transição suave).
        fonte = RAIZ/'art/blender/moradores_1500_v4.blend'
        with bpy.data.libraries.load(str(fonte)) as (src, dst):
            dst.objects = [self.tag+'_Anatomia']
        anat = dst.objects[0]
        g = anat.vertex_groups['braco'].index
        kd = KDTree(len(anat.data.vertices))
        peso_src = []
        for i, v in enumerate(anat.data.vertices):
            kd.insert(v.co, i)
            peso_src.append(next((x.weight for x in v.groups if x.group == g), 0.0))
        kd.balance()
        self.peso_braco = {}
        for i, v in enumerate(vs):
            if i in self.roupa or i in self.cabelo:
                continue
            _, j, d = kd.find(v)
            if d < .012:
                self.peso_braco[i] = peso_src[j]
        malha_anat = anat.data
        bpy.data.objects.remove(anat)
        bpy.data.meshes.remove(malha_anat)
        # Braços: a ponta é o dedo mais baixo do próprio braço (antes o vértice mais
        # afastado entre 30% e 62% da altura, que caía na barra da saia).
        self.eixo = {}
        for l, s in (('E', 1), ('D', -1)):
            ponta = min((v for i, v in enumerate(vs) if v.x*s > 0 and self.peso_braco.get(i, 0) > .95),
                        key=lambda c: c.z)/h
            ombro = Vector((s*.091, ponta.y*.5, .786))
            d = (ponta-ombro).normalized()
            pulso = ponta-d*.055
            cotovelo = ombro+(pulso-ombro)*.52+Vector((0, .012, 0))
            self.eixo[l] = (ombro, cotovelo, pulso, ponta)

        def fatia(u, s, largura=.16):
            pts = [v for i, v in enumerate(vs) if abs(v.z-u*h) < .008*h and v.x*s > .01*h and abs(v.x) < largura*h
                   and i not in self.roupa]
            return sum(pts, Vector())/len(pts)
        self.perna = {}
        for l, s in (('E', 1), ('D', -1)):
            quadril = fatia(.43, s)
            joelho = fatia(.285, s)
            tornozelo = fatia(.075, s)
            pe = [v for v in vs if v.z < .055*h and v.x*s > .01*h and abs(v.x) < .16*h]
            ponta_y = min(v.y for v in pe)
            calcanhar_y = max(v.y for v in pe)
            quadril = Vector((quadril.x, quadril.y, .475*h))
            joelho.z, tornozelo.z = .285*h, .075*h
            bola = Vector((tornozelo.x, tornozelo.y+(ponta_y-tornozelo.y)*.62, .022*h))
            dedo = Vector((tornozelo.x, ponta_y+.008, .012*h))
            calcanhar = Vector((tornozelo.x, calcanhar_y-.012, 0.0))
            self.perna[l] = dict(quadril=quadril, joelho=joelho, tornozelo=tornozelo, bola=bola, dedo=dedo,
                                 calcanhar=calcanhar)
        cintura = [v for v in vs if abs(v.z-.6*h) < .01*h and abs(v.x) < .1*h]
        pescoco = [v for v in vs if abs(v.z-.84*h) < .008*h and abs(v.x) < .05*h]
        self.y_tronco = sum(v.y for v in cintura)/len(cintura)
        self.y_pescoco = sum(v.y for v in pescoco)/len(pescoco)

    # ---- esqueleto

    def esqueleto(self):
        h = self.h
        arm = bpy.data.armatures.new(self.tag+'_esqueleto')
        self.rig = rig = bpy.data.objects.new(self.tag+'_rig', arm)
        self.cena.collection.objects.link(rig)
        bpy.context.view_layer.objects.active = rig
        rig.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')

        def osso(n, a, b, pai=None, conectar=False):
            x = arm.edit_bones.new(n)
            x.head, x.tail = a, b
            if pai:
                x.parent = arm.edit_bones[pai]
                x.use_connect = conectar

        yt, yn = self.y_tronco, self.y_pescoco
        osso('base', V(0, 0, 0), V(0, 0, .12*h))
        osso('quadril', V(0, yt, .475*h), V(0, yt, .58*h), 'base')
        osso('coluna', V(0, yt, .58*h), V(0, yt, .70*h), 'quadril')
        osso('peito', V(0, yt, .70*h), V(0, yn, .815*h), 'coluna')
        osso('pescoco', V(0, yn, .815*h), V(0, yn, .865*h), 'peito')
        osso('cabeca', V(0, yn, .865*h), V(0, yn, .96*h), 'pescoco')
        for l in ('E', 'D'):
            o_, c_, p_, m_ = self.eixo[l]
            osso('braco_'+l, o_*h, c_*h, 'peito')
            osso('antebraco_'+l, c_*h, p_*h, 'braco_'+l)
            osso('mao_'+l, p_*h, m_*h, 'antebraco_'+l)
            P = self.perna[l]
            osso('coxa_'+l, P['quadril'], P['joelho'], 'quadril')
            osso('canela_'+l, P['joelho'], P['tornozelo'], 'coxa_'+l)
            osso('pe_'+l, P['tornozelo'], P['bola'], 'canela_'+l)
            osso('dedos_'+l, P['bola'], P['dedo'], 'pe_'+l)
        bpy.ops.object.mode_set(mode='OBJECT')
        self.arm = arm
        for b in rig.pose.bones:
            b.rotation_mode = 'QUATERNION'

    # ---- pesos

    def pesos(self):
        h, mesh, arm = self.h, self.malha, self.arm
        for b in arm.bones:
            mesh.vertex_groups.new(name=b.name)
        grupos = mesh.vertex_groups
        cortes = [('quadril', .60, .03), ('coluna', .70, .03), ('peito', .815, .015), ('pescoco', .862, .012)]
        ordem = ['quadril', 'coluna', 'peito', 'pescoco', 'cabeca']

        def coluna(u):
            s = [suave(c-w, c+w, u) for _, c, w in cortes]
            pesos = [1-s[0]]+[s[i-1]-s[i] for i in range(1, 4)]+[s[3]]
            return dict(zip(ordem, pesos))

        def por(v, n, w):
            if w > .0005:
                grupos[n].add([v], w, 'ADD')
        for v in mesh.data.vertices:
            p = v.co
            u = p.z/h
            l = 'E' if p.x >= 0 else 'D'
            i = v.index
            if i in self.cabelo:
                w = suave(.70, .80, u)
                por(i, 'cabeca', w)
                por(i, 'peito', 1-w)
                continue
            braco = self.peso_braco.get(i, 0.0)
            if braco > 0:
                o_, c_, p_, m_ = self.eixo[l]
                q = p/h
                ds = [dist_seg(q, o_, c_), dist_seg(q, c_, p_), dist_seg(q, p_, m_)]
                inv = [1/(d+.004)**4 for d in ds]
                tot = sum(inv)
                for n, w in zip(('braco_', 'antebraco_', 'mao_'), inv):
                    por(i, n+l, braco*w/tot)
            resto = 1-braco
            if u < .54:
                perna = suave(.54, .43, u)
                if i in self.saia:
                    perna = .4*suave(.52, .40, u)
                elif i in self.roupa:
                    perna = 0.0
                c = suave(.25, .32, u)
                a = suave(.055, .09, u)
                P = self.perna[l]
                dd = suave(P['bola'].y+.012, P['bola'].y-.015, p.y) if u < .06 else 0.0
                por(i, 'quadril', resto*(1-perna))
                por(i, 'coxa_'+l, resto*perna*c)
                por(i, 'canela_'+l, resto*perna*(1-c)*a)
                por(i, 'pe_'+l, resto*perna*(1-c)*(1-a)*(1-dd))
                por(i, 'dedos_'+l, resto*perna*(1-c)*(1-a)*dd)
            else:
                for n, w in coluna(u).items():
                    por(i, n, resto*w)
        mesh.parent = self.rig
        mod = mesh.modifiers.new('Esqueleto', 'ARMATURE')
        mod.object = self.rig
        # Durante a autoria a malha não é deformada (muito mais rápido).
        mod.show_viewport = False
        self.rig.animation_data_create()
        R = self.rig.pose.bones
        self.rest = {b.name: b.matrix_local.copy() for b in arm.bones}
        self.W = {l: self.eixo[l][2]*h for l in ('E', 'D')}

    # ---------------------------------------------------------------- pose

    def atualizar(self):
        bpy.context.view_layer.update()

    def apontar(self, n, cabeca, cauda):
        b = self.arm.bones[n]
        q = (b.tail_local-b.head_local).rotation_difference(cauda-cabeca)@b.matrix_local.to_quaternion()
        self.rig.pose.bones[n].matrix = Matrix.Translation(cabeca)@q.to_matrix().to_4x4()

    def dois_ossos(self, a, b, raiz, alvo, polo):
        """IK analítica de dois ossos. Retorna (meio, alvo alcançável)."""
        la = self.arm.bones[a].length
        lb = self.arm.bones[b].length
        d = alvo-raiz
        dist = max(.01, min(d.length, (la+lb)*.999))
        d.normalize()
        alvo = raiz+d*dist
        proj = (la*la-lb*lb+dist*dist)/(2*dist)
        polo = (polo-d*polo.dot(d))
        polo = polo.normalized() if polo.length > 1e-6 else d.orthogonal().normalized()
        meio = raiz+d*proj+polo*math.sqrt(max(0.0, la*la-proj*proj))
        return meio, alvo

    def girar_local(self, n, pitch=0.0, yaw=0.0, roll=0.0):
        """Ossos verticais (coluna): pitch + inclina para a frente, yaw gira para a
        esquerda do personagem, roll inclina para a esquerda."""
        self.rig.pose.bones[n].rotation_quaternion = Euler((pitch, yaw, -roll), 'YXZ').to_quaternion()

    def aplicar(self, P):
        R = self.rig.pose.bones
        k = self.k
        for b in R:
            b.matrix_basis = Matrix.Identity(4)
        r = P['raiz']*k
        R['base'].location = Vector((r.x, r.z, -r.y))
        for n in ('pelve', 'coluna', 'peito', 'pescoco', 'cabeca'):
            g = P.get(n, V(0, 0, 0))
            self.girar_local('quadril' if n == 'pelve' else n, g.x, g.y, g.z)
        self.atualizar()
        # Pernas.
        yaw = P.get('pelve', V(0, 0, 0)).y
        for l, s in (('E', 1), ('D', -1)):
            pe = P['pe_'+l]
            tornozelo = pe['tornozelo']
            quadril = R['coxa_'+l].head.copy()
            frente = Matrix.Rotation(yaw*.6+pe.get('giro', 0.0), 3, 'Z')@Vector((s*.12, -1, 0))
            joelho, tornozelo = self.dois_ossos('coxa_'+l, 'canela_'+l, quadril, tornozelo, frente)
            self.apontar('coxa_'+l, quadril, joelho)
            self.atualizar()
            self.apontar('canela_'+l, joelho, tornozelo)
            self.atualizar()
            rot_pe = Matrix.Rotation(pe.get('giro', 0.0), 4, 'Z')@Matrix.Rotation(pe['ponta'], 4, 'X')
            Rpe = self.rest['pe_'+l]
            R['pe_'+l].matrix = Matrix.Translation(tornozelo)@(rot_pe@Rpe.to_3x3().to_4x4())
            self.atualizar()
            if pe.get('dedos') is not None:
                bola = R['pe_'+l].tail.copy()
                rot_d = Matrix.Rotation(pe.get('giro', 0.0), 4, 'Z')@Matrix.Rotation(pe['dedos'], 4, 'X')
                R['dedos_'+l].matrix = Matrix.Translation(bola)@(rot_d@self.rest['dedos_'+l].to_3x3().to_4x4())
        # Ferramenta (define a mão que a segura).
        mao_ferr = {}
        f = P.get('ferramenta')
        if f:
            M = self.matriz_ferramenta(f)
            Mh = M@self.props_rest[f['nome']].inverted()@self.rest['mao_'+f['mao']]
            mao_ferr[f['mao']] = Mh
            if f.get('segunda') is not None:
                outra = 'E' if f['mao'] == 'D' else 'D'
                ponto = M@Vector((0, 0, f['segunda']*k))
                P['mao_'+outra] = dict(alvo=ponto, segura=True)
        for l, s in (('E', 1), ('D', -1)):
            ombro = R['braco_'+l].head.copy()
            mao = P['mao_'+l]
            if l in mao_ferr:
                alvo = mao_ferr[l].translation.copy()
            else:
                alvo = mao['alvo'].copy()
                if mao.get('segura'):
                    alvo -= (alvo-ombro).normalized()*.06*k
            polo = mao.get('polo', Vector((s*.55, .35, -.75)))
            polo = Matrix.Rotation(P.get('peito', V(0, 0, 0)).y+P.get('pelve', V(0, 0, 0)).y, 3, 'Z')@polo
            cotovelo, alvo = self.dois_ossos('braco_'+l, 'antebraco_'+l, ombro, alvo, polo)
            self.apontar('braco_'+l, ombro, cotovelo)
            self.atualizar()
            self.apontar('antebraco_'+l, cotovelo, alvo)
            self.atualizar()
            if l in mao_ferr:
                R['mao_'+l].matrix = mao_ferr[l]
            elif 'giro' in mao:
                q = Quaternion(Vector((1, 0, 0)), mao['giro'])@self.rest['mao_'+l].to_quaternion()
                R['mao_'+l].matrix = Matrix.Translation(alvo)@q.to_matrix().to_4x4()
            else:
                R['mao_'+l].rotation_quaternion = Quaternion(Vector((1, 0, 0)), mao.get('punho', .12))

    def matriz_ferramenta(self, f):
        z = f['eixo'].normalized()
        cima = f.get('cima', Vector((1, 0, 0)))
        x = cima-z*cima.dot(z)
        x = x.normalized() if x.length > 1e-4 else z.orthogonal().normalized()
        y = z.cross(x)
        M = Matrix((x, y, z)).transposed().to_4x4()
        M.translation = f['pega']*self.k
        return M

    def chave(self, quadro):
        for b in self.rig.pose.bones:
            b.keyframe_insert('location', frame=quadro)
            b.keyframe_insert('rotation_quaternion', frame=quadro)

    def clipe(self, nome, quadros, funcao, laco=True):
        """funcao(t) -> pose; t de 0 a 1. Em laço, o último quadro repete o primeiro."""
        rig = self.rig
        rig.animation_data.action = None
        n = quadros+1 if laco else quadros
        for q in range(n):
            t = q/quadros if laco else q/(quadros-1)
            self.aplicar(funcao(t))
            self.chave(q+1)
        acao = rig.animation_data.action
        acao.name = self.tag+'_'+nome
        acao.use_fake_user = True
        trilha = rig.animation_data.nla_tracks.new()
        trilha.name = nome
        faixa = trilha.strips.new(nome, 1, acao)
        if hasattr(faixa, 'action_slot') and acao.slots:
            faixa.action_slot = acao.slots[0]
        trilha.mute = True
        rig.animation_data.action = None
        return trilha

    # ---------------------------------------------------------------- poses base

    def pe_parado(self, l, desloc=V(0, 0, 0), ponta=0.0, dedos=None, giro=0.0):
        s = 1 if l == 'E' else -1
        d = Vector((desloc.x*s, desloc.y, desloc.z))*self.k
        return dict(tornozelo=self.perna[l]['tornozelo']+d, ponta=ponta, dedos=dedos, giro=giro)

    def mao_solta(self, l, desloc=V(0, 0, 0), **extra):
        s = 1 if l == 'E' else -1
        d = Vector((desloc.x*s, desloc.y, desloc.z))*self.k
        return dict(alvo=self.W[l]+d, **extra)

    def base(self):
        return {'raiz': V(0, 0, -.008), 'pelve': V(0, 0, 0), 'coluna': V(0, 0, 0), 'peito': V(0, 0, 0),
                'pescoco': V(0, 0, 0), 'cabeca': V(0, 0, 0)}


# ---------------------------------------------------------------- clipes

def pose_de(m, p):
    """Converte parâmetros escalares/vetoriais em pose do Morador.
    Mãos: maoE/maoD = deslocamento em relação à mão solta (x positivo = para fora)
    ou 'abs' + vetor absoluto (corpo de 1,83 m). Pés: peE/peD deslocamento."""
    P = {n: p[n] for n in ('raiz', 'pelve', 'coluna', 'peito', 'pescoco', 'cabeca')}
    for l in ('E', 'D'):
        P['pe_'+l] = m.pe_parado(l, p.get('pe'+l, V(0, 0, 0)), p.get('ponta'+l, 0.0), p.get('dedos'+l), p.get('giro'+l, 0.0))
        if ('abs'+l) in p:
            alvo = p['abs'+l]*m.k
            P['mao_'+l] = dict(alvo=alvo, punho=p.get('punho'+l, .15))
        else:
            P['mao_'+l] = m.mao_solta(l, p.get('mao'+l, V(0, -.015, .02)), punho=p.get('punho'+l, .12))
        if ('polo'+l) in p:
            P['mao_'+l]['polo'] = p['polo'+l]
        if ('giro_mao'+l) in p:
            P['mao_'+l]['giro'] = p['giro_mao'+l]
    if 'pega' in p:
        P['ferramenta'] = dict(nome=p['ferr'], mao=p.get('ferr_mao', 'D'), pega=p['pega'], eixo=p['eixo'],
                               cima=p.get('cima', V(1, 0, 0)), segunda=p.get('segunda'))
    return P


def respirar(t, ciclos, amp=.012):
    return amp*math.sin(TAU*ciclos*t)


def clipe_parado(m):
    def f(t):
        b = m.base()
        p = dict(b)
        peso = math.sin(TAU*t)
        p['raiz'] = V(.012*peso, 0, -.008+.003*math.sin(TAU*2*t))
        p['pelve'] = V(0, .02*math.sin(TAU*t+.6), .025*peso)
        p['coluna'] = V(.01, 0, -.012*peso)
        p['peito'] = V(-respirar(t, 2, .014), 0, -.01*peso)
        p['cabeca'] = V(.04+.02*math.sin(TAU*t+1.3), .08*math.sin(TAU*t+2.0), .015*peso)
        for l, s in (('E', 1), ('D', -1)):
            p['mao'+l] = V(.004*math.sin(TAU*2*t+s), -.012+.008*math.sin(TAU*t+s*.8), .022+.006*math.sin(TAU*2*t))
        p['peE'] = V(0, 0, 0)
        p['peD'] = V(0, 0, 0)
        return pose_de(m, p)
    return f


def clipe_olhar(m):
    olhar = Curva([(0, 0.0), (.12, 0.0), (.26, .6), (.42, .55), (.58, -.55), (.74, -.5), (.88, 0.0)])
    inclina = Curva([(0, 0.0), (.26, -.06), (.42, .05), (.58, -.04), (.74, .06), (.88, 0.0)])
    def f(t):
        p = dict(m.base())
        y = olhar(t)
        peso = math.sin(TAU*t)
        p['raiz'] = V(.01*peso, 0, -.008)
        p['pelve'] = V(0, .05*y, .02*peso)
        p['peito'] = V(-respirar(t, 3, .012), .18*y, 0)
        p['pescoco'] = V(0, .3*y, 0)
        p['cabeca'] = V(inclina(t), .35*y, -.04*y)
        for l in ('E', 'D'):
            p['mao'+l] = V(0, -.012, .022)
        return pose_de(m, p)
    return f


def clipe_conversar(m):
    b = dict(m.base(), absD=V(-.2, -.18, .98), absE=V(.24, .01, .99), poloE=V(.9, .6, -.2),
             punhoE=-.5, punhoD=.05)
    k = chaves(b, [
        (0, {}),
        (.12, {'absD': V(-.22, -.27, 1.08), 'cabeca': V(.06, .12, .03)}),
        (.24, {'absD': V(-.14, -.24, 1.02), 'cabeca': V(-.03, .05, 0)}),
        (.36, {'absD': V(-.27, -.22, 1.12), 'peito': V(0, -.06, 0), 'cabeca': V(.08, -.08, .02)}),
        (.5, {'absD': V(-.24, -.05, .86), 'cabeca': V(.02, .1, -.02), 'peito': V(0, 0, 0)}),
        (.62, {'absD': V(-.25, -.03, .84), 'cabeca': V(.1, .15, 0)}),
        (.74, {'absD': V(-.17, -.25, 1.05), 'cabeca': V(-.02, .05, .04)}),
        (.88, {'absD': V(-.21, -.21, 1.0), 'cabeca': V(.05, .1, 0)}),
    ])
    c = curvas(k)
    def f(t):
        p = c(t)
        peso = math.sin(TAU*t)
        p['raiz'] = V(-.012*peso, 0, -.008)
        p['pelve'] = V(0, 0, -.025*peso)
        p['peito'] = p['peito']+V(-respirar(t, 4, .012), 0, 0)
        return pose_de(m, p)
    return f


def passada(m):
    """Mede o alcance da perna: passada máxima sem esticar o joelho."""
    P = m.perna['E']
    alcance = (m.arm.bones['coxa_E'].length+m.arm.bones['canela_E'].length)*.985
    queda = .03*m.k
    vertical = P['quadril'].z-queda-P['tornozelo'].z
    frente = math.sqrt(max(0, alcance**2-(vertical+.004)**2))-.02*m.k
    tras = math.sqrt(max(0, alcance**2-(vertical-.045*m.k)**2))-.02*m.k
    return frente, tras, queda


def clipe_andar(m, ciclo=1.0, braco_amp=.10, maos_giro=False):
    frente, tras, queda = passada(m)
    k = m.k
    apoio = .6
    velocidade = (frente+tras)/(apoio*ciclo)

    def pe(l, fase):
        P = m.perna[l]
        A, B, C = P['tornozelo'], P['bola'], P['calcanhar']
        if fase < apoio:
            s = fase/apoio
            y = -frente+(frente+tras)*s
            if s < .18:
                ponta = -.26*(1-suave(0, .18, s))
                piv, piv_rest = Vector((C.x, C.y+y, C.z)), C
            else:
                ponta = .6*suave(.6, 1, s)
                piv, piv_rest = Vector((B.x, B.y+y, B.z)), B
            dedos = 0.0 if ponta > 0 else None
            return dict(tornozelo=piv+Matrix.Rotation(ponta, 3, 'X')@(A-piv_rest), ponta=ponta, dedos=dedos)
        s = (fase-apoio)/(1-apoio)
        y = tras+(-frente-tras)*(1-math.cos(math.pi*s))/2
        ergue = .075*k*math.sin(math.pi*s)**.8
        ponta = .6+(-.26-.6)*suave(0, .7, s)
        bola = Vector((B.x, B.y+y, B.z+ergue))
        calc = Vector((C.x, C.y+y, C.z+ergue))
        a1 = bola+Matrix.Rotation(ponta, 3, 'X')@(A-B)
        a2 = calc+Matrix.Rotation(ponta, 3, 'X')@(A-C)
        return dict(tornozelo=a1.lerp(a2, suave(.55, 1, s)), ponta=ponta, dedos=None)

    def f(t):
        c = math.cos(TAU*t)
        p = dict(m.base())
        p['raiz'] = V(.02*math.sin(TAU*t), .0, -queda/k-.016*math.cos(2*TAU*t))
        p['pelve'] = V(.03, -.07*c, .035*math.sin(TAU*t))
        p['coluna'] = V(.03, .04*c, -.02*math.sin(TAU*t))
        p['peito'] = V(-respirar(t, 1, .006), .05*c, -.012*math.sin(TAU*t))
        p['pescoco'] = V(0, -.03*c, 0)
        p['cabeca'] = V(.05+.015*math.cos(2*TAU*t), -.03*c, .01*math.sin(TAU*t))
        P = pose_de(m, p)
        P['pe_E'] = pe('E', t % 1)
        P['pe_D'] = pe('D', (t+.5) % 1)
        for l, fase in (('E', 0.0), ('D', .5)):
            balanco = math.cos(TAU*(t+fase-.05))
            d = V(-.01, braco_amp*balanco, .03+.035*max(0.0, -balanco))
            P['mao_'+l] = m.mao_solta(l, d, punho=.12+.15*max(0.0, -balanco))
            if maos_giro:
                P['mao_'+l]['giro'] = 0.0
        return P
    return f, velocidade


def clipe_coletar(m):
    b = dict(m.base(), maoE=V(0, -.015, .02), maoD=V(0, -.015, .02), peD=V(0, -.05, 0))
    curvado = {'raiz': V(0, .11, -.30), 'pelve': V(.55, .06, 0), 'coluna': V(.28, 0, 0), 'peito': V(.18, .05, 0),
               'pescoco': V(-.12, 0, 0), 'cabeca': V(-.18, .05, 0), 'absE': V(.15, -.27, .50), 'punhoE': -.2}
    k = chaves(b, [
        (0, {'cabeca': V(.1, 0, 0)}),
        (.1, {'raiz': V(0, .04, -.08), 'pelve': V(.22, 0, 0), 'coluna': V(.12, 0, 0), 'cabeca': V(.18, 0, 0),
              'maoD': V(-.02, -.1, .08), 'maoE': V(0, -.06, .05)}),
        (.25, dict(curvado, absD=V(-.16, -.50, .14), punhoD=.4)),
        (.33, {'absD': V(-.13, -.48, .075), 'punhoD': .6}),
        (.4, {'absD': V(-.12, -.44, .12), 'punhoD': .3}),
        (.52, {'raiz': V(0, .06, -.14), 'pelve': V(.3, .14, 0), 'coluna': V(.14, .12, 0), 'peito': V(.1, .16, 0),
               'pescoco': V(0, .1, 0), 'cabeca': V(.22, .22, 0), 'absD': V(.08, -.2, .95), 'absE': V(.2, -.05, .82),
               'punhoD': .5}),
        (.6, {'absD': V(.17, -.03, .98), 'punhoD': .8, 'cabeca': V(.3, .26, 0)}),
        (.66, {'absD': V(.18, .0, .93), 'punhoD': .9}),
        (.76, {'raiz': V(0, .0, -.01), 'pelve': V(0, 0, 0), 'coluna': V(0, 0, 0), 'peito': V(-.05, 0, 0),
               'pescoco': V(0, 0, 0), 'cabeca': V(.0, -.25, 0)}),
        (.88, {'cabeca': V(.05, .1, 0), 'peito': V(0, 0, 0)}),
    ])
    # As mãos passam de deslocamento a absoluto: converte tudo para absoluto.
    for _, d in k:
        for l in ('E', 'D'):
            if ('abs'+l) not in d:
                s = 1 if l == 'E' else -1
                off = d['mao'+l]
                d['abs'+l] = (m.W[l]+Vector((off.x*s, off.y, off.z))*m.k)/m.k
            d.setdefault('punho'+l, .12)
    c = curvas(k)
    def f(t):
        p = c(t)
        p['peito'] = p['peito']+V(-respirar(t, 4, .01), 0, 0)
        return pose_de(m, p)
    return f


def clipe_ferramenta(m, lista, base_extra, respira=3):
    b = dict(m.base(), **base_extra)
    c = curvas(chaves(b, lista))
    def f(t):
        p = c(t)
        p['peito'] = p['peito']+V(-respirar(t, respira, .01), 0, 0)
        return pose_de(m, p)
    return f


def clipe_capinar(m):
    base = {'ferr': 'Prop_Pau', 'segunda': -.34, 'peE': V(.02, -.16, 0), 'peD': V(.02, .13, 0), 'giroD': .25,
            'cima': V(1, 0, 0), 'raiz': V(0, .02, -.05)}
    return clipe_ferramenta(m, [
        (0, {'pega': V(-.10, -.14, 1.30), 'eixo': norm(0, .22, 1), 'pelve': V(.08, .05, 0), 'coluna': V(.05, 0, 0),
             'peito': V(-.04, 0, 0), 'cabeca': V(.22, 0, 0)}),
        (.22, {'pega': V(-.10, -.18, 1.36), 'eixo': norm(0, .18, 1), 'peito': V(-.08, 0, 0)}),
        (.34, {'pega': V(-.08, -.32, 1.02), 'eixo': norm(0, .36, 1), 'pelve': V(.2, .02, 0), 'coluna': V(.12, 0, 0),
               'peito': V(.06, 0, 0), 'raiz': V(0, .05, -.09)}),
        (.40, {'pega': V(-.06, -.40, .80), 'eixo': norm(0, .44, 1), 'pelve': V(.34, 0, 0), 'coluna': V(.2, 0, 0),
               'peito': V(.12, 0, 0), 'cabeca': V(.06, 0, 0), 'raiz': V(0, .07, -.13)}),
        (.5, {'pega': V(-.07, -.30, .86), 'eixo': norm(0, .72, 1), 'pelve': V(.3, -.04, 0), 'raiz': V(0, .09, -.11)}),
        (.6, {'pega': V(-.08, -.26, .90), 'eixo': norm(0, .8, 1)}),
        (.74, {'pega': V(-.09, -.20, 1.12), 'eixo': norm(0, .32, 1), 'pelve': V(.15, .03, 0), 'coluna': V(.08, 0, 0),
               'peito': V(0, 0, 0), 'cabeca': V(.18, 0, 0), 'raiz': V(0, .04, -.06)}),
    ], base, respira=2)


def clipe_plantar(m):
    agachado = {'raiz': V(0, .13, -.47), 'pelve': V(.42, 0, 0), 'coluna': V(.3, 0, 0), 'peito': V(.22, 0, 0),
                'pescoco': V(-.05, 0, 0), 'cabeca': V(-.2, 0, 0)}
    b = dict(m.base(), peE=V(.07, -.03, 0), peD=V(.07, .05, 0), giroE=.25, giroD=-.25,
             absE=V(.2, -.05, .79), absD=V(-.2, -.05, .79), punhoE=.12, punhoD=.12)
    k = chaves(b, [
        (0, {}),
        (.12, dict(agachado, absE=V(.06, -.30, .42), absD=V(-.12, -.36, .30))),
        (.2, {'absD': V(-.1, -.42, .07), 'punhoD': .7}),
        (.26, {'absD': V(-.1, -.40, .15), 'punhoD': .4}),
        (.32, {'absD': V(-.09, -.42, .06), 'punhoD': .7}),
        (.4, {'absD': V(-.12, -.34, .22), 'punhoD': .3}),
        (.48, {'absE': V(.0, -.42, .17), 'punhoE': .8, 'cabeca': V(-.15, -.05, 0)}),
        (.56, {'absE': V(.06, -.30, .42), 'punhoE': .2}),
        (.64, {'absD': V(-.05, -.42, .06), 'absE': V(.04, -.41, .06), 'punhoD': 1.0, 'punhoE': 1.0}),
        (.7, {'absD': V(-.05, -.40, .13), 'absE': V(.04, -.39, .13)}),
        (.76, {'absD': V(-.05, -.42, .06), 'absE': V(.04, -.41, .06)}),
        (.88, {'raiz': V(0, .04, -.1), 'pelve': V(.12, 0, 0), 'coluna': V(.05, 0, 0), 'peito': V(0, 0, 0),
               'pescoco': V(0, 0, 0), 'cabeca': V(.1, 0, 0), 'absE': V(.2, -.08, .74), 'absD': V(-.2, -.08, .74),
               'punhoE': .12, 'punhoD': .12}),
    ])
    c = curvas(k)
    def f(t):
        p = c(t)
        p['peito'] = p['peito']+V(-respirar(t, 4, .01), 0, 0)
        return pose_de(m, p)
    return f


def clipe_pescar(m):
    base = {'ferr': 'Prop_Lanca', 'segunda': -.48, 'peE': V(.05, -.13, 0), 'peD': V(.03, .14, 0), 'giroD': .35,
            'cima': V(1, 0, 0), 'raiz': V(0, .02, -.07)}
    pronta = {'pega': V(-.12, .02, 1.30), 'eixo': norm(0, .55, 1), 'pelve': V(.14, .05, 0), 'coluna': V(.1, 0, 0),
              'peito': V(.04, 0, 0), 'cabeca': V(.32, 0, 0), 'raiz': V(0, .02, -.07)}
    return clipe_ferramenta(m, [
        (0, pronta),
        (.2, {'pega': V(-.10, .0, 1.32), 'eixo': norm(.06, .5, 1), 'cabeca': V(.34, .1, 0)}),
        (.36, {'pega': V(-.12, .01, 1.30), 'eixo': norm(-.04, .55, 1), 'cabeca': V(.33, -.06, 0)}),
        (.44, {'pega': V(-.11, .07, 1.40), 'eixo': norm(0, .62, 1), 'raiz': V(0, .04, -.05), 'pelve': V(.1, .06, 0)}),
        (.5, {'pega': V(-.06, -.32, .92), 'eixo': norm(0, .42, 1), 'pelve': V(.4, 0, 0), 'coluna': V(.24, 0, 0),
              'peito': V(.12, 0, 0), 'raiz': V(0, -.03, -.14), 'cabeca': V(.2, 0, 0)}),
        (.56, {'pega': V(-.06, -.34, .90)}),
        (.68, {'pega': V(-.10, -.12, 1.22), 'eixo': norm(0, 1, .3), 'pelve': V(.1, .1, 0), 'coluna': V(.05, .05, 0),
               'peito': V(-.02, .08, 0), 'cabeca': V(.12, .18, 0), 'raiz': V(0, .02, -.05)}),
        (.82, {'pega': V(-.11, -.10, 1.24), 'eixo': norm(.08, 1, .35), 'cabeca': V(.1, .25, 0)}),
        (.92, dict(pronta, pega=V(-.12, .03, 1.31))),
    ], base, respira=2)


def clipe_artesanato(m):
    """Ajoelhado num joelho, alisando a haste de uma flecha."""
    base = {'ferr': 'Prop_Flecha', 'ferr_mao': 'E', 'cima': V(0, 0, 1), 'eixo': norm(-1, -.1, .12),
            'peE': V(.02, -.24, 0), 'peD': V(.03, .30, .06), 'pontaD': 1.15, 'dedosD': 0.0,
            'raiz': V(0, .06, -.43), 'pelve': V(.22, 0, 0), 'coluna': V(.2, 0, 0), 'peito': V(.16, 0, 0),
            'pescoco': V(.05, 0, 0), 'cabeca': V(.28, 0, 0), 'pega': V(.12, -.32, .60), 'polo'+'E': V(.8, .3, -.6)}
    lista = []
    for i in range(3):
        t0 = i/3
        lista += [(t0, {'absD': V(-.0, -.33, .63), 'punhoD': .3}),
                  (t0+.2, {'absD': V(-.17, -.33, .62), 'punhoD': .25}),
                  (t0+.28, {'absD': V(-.12, -.30, .69), 'punhoD': .35})]
    lista[3][1]['cabeca'] = V(.3, .05, 0)
    lista[6][1]['cabeca'] = V(.26, -.05, 0)
    return clipe_ferramenta(m, lista, dict(base, absD=V(0, -.33, .63)), respira=3)


def clipe_construir(m):
    base = {'ferr': 'Prop_Macete', 'peE': V(.02, -.12, 0), 'peD': V(.02, .12, 0), 'giroD': .2, 'cima': V(1, 0, 0),
            'raiz': V(0, .07, -.13), 'pelve': V(.34, .05, 0), 'coluna': V(.2, 0, 0), 'peito': V(.1, 0, 0),
            'cabeca': V(.0, 0, 0), 'absE': V(.12, -.46, .80), 'punhoE': .6}
    return clipe_ferramenta(m, [
        (0, {'pega': V(-.17, -.22, 1.22), 'eixo': norm(0, .55, .85)}),
        (.16, {'pega': V(-.18, -.18, 1.28), 'eixo': norm(0, .7, .7), 'peito': V(.06, -.05, 0)}),
        (.3, {'pega': V(-.15, -.34, 1.10), 'eixo': norm(0, -.2, 1), 'peito': V(.12, .02, 0)}),
        (.38, {'pega': V(-.10, -.45, .84), 'eixo': norm(0, -1, -.12), 'peito': V(.16, .04, 0), 'raiz': V(0, .07, -.15)}),
        (.46, {'pega': V(-.11, -.43, .89), 'eixo': norm(0, -.9, .15)}),
        (.66, {'pega': V(-.15, -.28, 1.12), 'eixo': norm(0, .25, 1), 'peito': V(.08, 0, 0), 'raiz': V(0, .07, -.13)}),
    ], base, respira=1)


# ---------------------------------------------------------------- batalha

def clipe_batalha(m, nome):
    """Mesmas trajetórias de mão (e tempos) da versão anterior, com corpo inteiro:
    pés plantados, preparação, peso transferido e recuperação."""
    E0, D0 = m.eixo['E'][2], m.eixo['D'][2]
    h, k = m.h, m.k

    def f(t):
        p = dict(m.base())
        p['peE'] = V(.03, -.07, 0)
        p['peD'] = V(.03, .08, 0)
        p['giroE'] = .15
        p['giroD'] = -.2
        p['raiz'] = V(0, 0, -.045)
        p['pelve'] = V(.05, .08, 0)
        p['peito'] = V(.04-respirar(t, 1, .01), -.06, 0)
        p['cabeca'] = V(.0, -.03, 0)
        e, d = E0.copy(), D0.copy()
        ge = gd = 0.0
        onda = math.sin(math.pi*t)
        golpe = suave(.12, .45, t)*(1-suave(.58, .98, t))
        prepara = suave(0, .14, t)*(1-suave(.14, .32, t))
        if nome == 'pronto':
            p['raiz'] = V(.008*math.sin(TAU*t), 0, -.045+.006*math.sin(TAU*2*t))
            p['peito'] = V(.04-respirar(t, 2, .016), -.06, 0)
            p['cabeca'] = V(.0, -.03+.03*math.sin(TAU*t), 0)
            e = e+Vector((-.005, -.03, .025))
            d = d+Vector((.005, -.03, .025))
        elif nome in ('atacar_lanca', 'errar_lanca'):
            erro = nome == 'errar_lanca'
            d = d.lerp(Vector((-.10, -.34, .66)), golpe)+Vector((0, .05, .01))*prepara
            gd = 1.35*golpe
            e = e.lerp(Vector((.12, -.17, .63)), golpe)
            p['raiz'] = V(0, .03*prepara-.07*golpe-(.03 if erro else 0)*suave(.4, .6, t)*(1-suave(.7, 1, t)),
                          -.045-.04*golpe)
            p['pelve'] = V(.05+.12*golpe, .08-.12*prepara+.18*golpe, 0)
            p['coluna'] = V(.1*golpe, .06*golpe, 0)
            p['peito'] = V(.04+.12*golpe, -.06-.15*prepara+(.25 if erro else .12)*golpe, (.08 if erro else 0)*golpe)
            p['cabeca'] = V(-.08*golpe, -.03-.1*golpe, 0)
            p['peE'] = V(.03, -.07-.05*golpe, 0)
        elif nome in ('atacar_arco', 'errar_arco'):
            armar = suave(0, .28, t)*(1-suave(.78, 1, t))
            puxar = suave(.25, .53, t)*(1-suave(.57, .68, t))
            solta = suave(.55, .6, t)*(1-suave(.62, .8, t))
            e = e.lerp(Vector((.13, -.34, .77)), armar)
            d = d.lerp(Vector((-.10, -.28, .75)).lerp(Vector((-.025, -.045, .84)), puxar), armar)
            d = d+Vector((-.03, .05, .01))*solta
            gd = 1.1*armar
            p['pelve'] = V(.05, .08+.22*armar, 0)
            p['coluna'] = V(-.02*armar, .1*armar, 0)
            p['peito'] = V(.04-.06*armar+.03*solta, -.06+.15*armar, 0)
            p['cabeca'] = V(-.06*armar, -.03-.28*armar, .05*armar)
            if nome == 'errar_arco':
                p['peito'] = p['peito']+V(0, .08*solta, .04*solta)
        elif nome == 'receber_golpe':
            choque = suave(0, .18, t)*(1-suave(.3, 1, t))
            p['raiz'] = V(0, .07*choque, -.045-.05*choque)
            p['pelve'] = V(.05-.1*choque, .08, 0)
            p['coluna'] = V(-.18*choque, 0, .04*choque)
            p['peito'] = V(-.1*choque, -.06, 0)
            p['cabeca'] = V(-.26*choque, -.05*choque, .06*choque)
            p['peD'] = V(.03, .08+.06*choque, 0)
            e = e.lerp(Vector((.20, -.10, .62)), choque)
            d = d.lerp(Vector((-.20, -.10, .62)), choque)
        elif nome == 'esquivar':
            desvio = suave(0, .3, t)*(1-suave(.5, 1, t))
            p['raiz'] = V(.17*desvio, 0, -.045-.06*desvio)
            p['pelve'] = V(.05, .08, -.05*desvio)
            p['coluna'] = V(.05*desvio, .2*desvio, .12*desvio)
            p['peito'] = V(.04, -.06+.06*desvio, .08*desvio)
            p['cabeca'] = V(0, -.12*desvio, -.12*desvio)
            p['peE'] = V(.03+.16*desvio, -.07, .0)
            p['peD'] = V(.03-.08*desvio, .08, .0)
            e = e.lerp(Vector((.18, -.06, .65)), desvio)
            d = d.lerp(Vector((-.18, -.06, .65)), desvio)
        elif nome == 'defender':
            guarda = suave(0, .25, t)*(1-suave(.75, 1, t))
            p['raiz'] = V(0, .02*guarda, -.045-.05*guarda)
            p['pelve'] = V(.05+.1*guarda, .08, 0)
            p['peito'] = V(.04+.12*guarda, -.06, 0)
            p['cabeca'] = V(.1*guarda, 0, 0)
            e = e.lerp(Vector((.04, -.14, .77)), guarda)
            d = d.lerp(Vector((-.04, -.22, .75)), guarda)
        P = pose_de(m, p)
        P['mao_E'] = dict(alvo=e*h, giro=ge)
        P['mao_D'] = dict(alvo=d*h, giro=gd)
        return P
    return f


# ---------------------------------------------------------------- ferramentas

def material(nome, cor, aspereza=.8):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    c = [int(cor[i:i+2], 16)/255 for i in (0, 2, 4)]
    bs.inputs['Base Color'].default_value = tuple(((v+.055)/1.055)**2.4 if v > .04045 else v/12.92 for v in c)+(1.0,)
    bs.inputs['Roughness'].default_value = aspereza
    return m


def malha_ferramenta(nome, partes):
    """partes: [(tipo, params, material)] em coordenadas da ferramenta (eixo +Z)."""
    import bmesh
    bm = bmesh.new()
    mats = []
    for tipo, prm, mat in partes:
        if mat not in mats:
            mats.append(mat)
        antes = set(bm.faces)
        if tipo == 'cone':
            z0, z1, r0, r1 = prm
            g = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=r0, radius2=r1, depth=abs(z1-z0))
            bmesh.ops.translate(bm, verts=g['verts'], vec=Vector((0, 0, (z0+z1)/2)))
        elif tipo == 'bola':
            c, r = prm
            g = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=7, radius=1)
            bmesh.ops.scale(bm, verts=g['verts'], vec=r)
            bmesh.ops.translate(bm, verts=g['verts'], vec=c)
        elif tipo == 'cesto':
            r0, r1, alt = prm
            g = bmesh.ops.create_cone(bm, cap_ends=False, cap_tris=False, segments=14, radius1=r0, radius2=r1, depth=alt)
            fundo = bmesh.ops.create_circle(bm, cap_ends=True, segments=14, radius=r0)
            bmesh.ops.translate(bm, verts=fundo['verts'], vec=Vector((0, 0, -alt/2)))
        for f in set(bm.faces)-antes:
            f.material_index = mats.index(mat)
            f.smooth = True
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    for mat in mats:
        me.materials.append(mat)
    return me


def criar_ferramentas(m):
    madeira = material('Ferramenta_Madeira', '8c6238')
    pedra = material('Ferramenta_Pedra', '6f6a60', .9)
    fibra = material('Ferramenta_Fibra', 'b8955a', .9)
    pena = material('Ferramenta_Pena', 'c9472d', .8)
    defs = {
        'Prop_Pau': ('mao_D', [('cone', (-.97, .18, .016, .014), madeira), ('cone', (-1.06, -.97, .001, .016), madeira)]),
        'Prop_Lanca': ('mao_D', [('cone', (-1.35, .45, .013, .012), madeira), ('cone', (-1.5, -1.35, .002, .012), madeira),
                                 ('cone', (-1.37, -1.3, .016, .016), fibra)]),
        'Prop_Macete': ('mao_D', [('cone', (-.06, .33, .012, .012), madeira), ('bola', (Vector((0, 0, .36)), Vector((.07, .045, .045))), pedra),
                                  ('cone', (.3, .35, .016, .016), fibra)]),
        'Prop_Flecha': ('mao_E', [('cone', (-.38, .38, .005, .005), madeira), ('cone', (.38, .44, .001, .007), pedra),
                                  ('bola', (Vector((0, 0, -.33)), Vector((.018, .003, .05))), pena)]),
        'Prop_Cesto': ('quadril', [('cesto', (.075, .1, .15), fibra)]),
    }
    m.props_rest = {}
    rig = m.rig
    for b in rig.pose.bones:
        b.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    for nome, (osso, partes) in defs.items():
        o = bpy.data.objects.new(nome, malha_ferramenta(nome, partes))
        m.cena.collection.objects.link(o)
        o.parent = rig
        o.parent_type = 'BONE'
        o.parent_bone = osso
        if nome == 'Prop_Cesto':
            W = Matrix.Translation(Vector((.215*m.k, .03*m.k, .47*m.h)))@Matrix.Rotation(.1, 4, 'Y')
        else:
            # Repouso: na pega da mão (60% do osso), eixo da ferramenta vertical.
            b = m.arm.bones[osso]
            pega = b.head_local+(b.tail_local-b.head_local)*.6
            W = Matrix.Translation(pega)
        o.matrix_world = W
        m.props_rest[nome] = W.copy()
        o.hide_render = False


# ---------------------------------------------------------------- produção

ALDEIA = [('parado', 96, clipe_parado), ('olhar', 120, clipe_olhar), ('conversar', 120, clipe_conversar),
          ('coletar', 96, clipe_coletar), ('capinar', 48, clipe_capinar), ('plantar', 96, clipe_plantar),
          ('pescar', 72, clipe_pescar), ('artesanato', 72, clipe_artesanato), ('construir', 36, clipe_construir)]
BATALHA = [('pronto', 48), ('atacar_lanca', 32), ('errar_lanca', 32), ('atacar_arco', 32), ('errar_arco', 32),
           ('receber_golpe', 32), ('esquivar', 32), ('defender', 32)]
LACOS_BATALHA = {'pronto'}


def exportar(m, caminho, trilhas, com_props):
    rig = m.rig
    for tr in rig.animation_data.nla_tracks:
        tr.mute = tr.name not in trilhas
    rig.animation_data.action = None
    for b in rig.pose.bones:
        b.matrix_basis = Matrix.Identity(4)
    m.malha.modifiers['Esqueleto'].show_viewport = True
    bpy.ops.object.select_all(action='DESELECT')
    m.malha.select_set(True)
    rig.select_set(True)
    for o in m.cena.objects:
        if o.name.startswith('Prop_'):
            o.select_set(com_props)
    bpy.context.view_layer.objects.active = rig
    caminho.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(caminho), use_selection=True, use_active_scene=True, export_cameras=False,
                              export_lights=False, export_animation_mode='NLA_TRACKS', export_force_sampling=True,
                              export_optimize_animation_size=True)
    m.malha.modifiers['Esqueleto'].show_viewport = False


def produzir(tag, velocidades):
    m = Morador(tag)
    criar_ferramentas(m)
    aldeia = []
    for nome, quadros, fn in ALDEIA:
        m.clipe(nome, quadros, fn(m))
        aldeia.append(nome)
    andar, v = clipe_andar(m)
    tr_aldeia = m.clipe('andar_aldeia', 24, andar)
    velocidades[tag] = {'andar': round(v, 4)}
    batalha = []
    andar_b, _ = clipe_andar(m, ciclo=1.0, braco_amp=.05, maos_giro=True)
    tr_batalha = m.clipe('andar_batalha', 24, andar_b)
    for nome, quadros in BATALHA:
        m.clipe(nome, quadros, clipe_batalha(m, nome), laco=nome in LACOS_BATALHA)
        batalha.append(nome)
    # Os dois arquivos chamam a caminhada de 'andar' (nomes de trilha são únicos).
    tr_batalha.name = 'andar'
    exportar(m, RAIZ/'assets/models/habitantes/batalha'/(tag+'.glb'), set(batalha) | {'andar'}, False)
    tr_batalha.name = 'andar_batalha'
    tr_aldeia.name = 'andar'
    exportar(m, RAIZ/'assets/models/habitantes/aldeia'/(tag+'.glb'), set(aldeia) | {'andar'}, True)
    # A fonte abre mostrando a malha deformada e apenas a pose de repouso.
    m.malha.modifiers['Esqueleto'].show_viewport = True
    for trilha in m.rig.animation_data.nla_tracks:
        trilha.mute = trilha.name != 'parado'
    m.cena.frame_set(1)
    print('ANIMADO', tag, 'velocidade', round(v, 3), 'clipes', len(aldeia), len(batalha), 'tempo', round(time.time()-INICIO))
    return m.cena


INICIO = time.time()


def principal():
    args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    tags = [a for a in args if a in TAGS] or TAGS
    arquivo = RAIZ/'assets/models/habitantes/aldeia/animacao.json'
    velocidades = json.loads(arquivo.read_text(encoding='utf-8')) if arquivo.exists() else {}
    cenas = set()
    for tag in tags:
        cenas.add(produzir(tag, velocidades))
    arquivo.parent.mkdir(parents=True, exist_ok=True)
    arquivo.write_text(json.dumps(velocidades, indent=1, sort_keys=True), encoding='utf-8')
    if len(tags) == len(TAGS):
        nome_fonte = 'moradores_animados.blend'
    else:
        nome_fonte = 'moradores_animados_' + '_'.join(tags) + '.blend'
    bpy.data.libraries.write(str(RAIZ/'art/blender'/nome_fonte), cenas, fake_user=True, compress=True)
    print('ANIMACOES PRONTAS')


if __name__ == '__main__':
    try:
        principal()
    except Exception:
        traceback.print_exc()
    sys.stdout.flush()
    if '--manter' not in sys.argv:
        # wm.quit_blender trava às vezes com a janela aberta; a saída direta é segura
        # porque tudo já foi gravado.
        import os
        os._exit(0)
