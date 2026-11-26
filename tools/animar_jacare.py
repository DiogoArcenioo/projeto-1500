"""Animações do jacaré-de-papo-amarelo (inspeção, encontro e batalha).

Uso (com janela; fecha o Blender ao terminar):
  blender --factory-startup --python tools/animar_jacare.py
Parte de art/blender/jacare.blend (tools/modelar_jacare.py) e grava:
 - assets/models/animais/jacare_papo_amarelo.glb          parada, andar, correr;
 - assets/models/animais/batalha/jacare_papo_amarelo.glb  + investida, errar_ataque,
   receber_golpe, esquivar (mesmos nomes e momento de contato da capivara, ~0,53 s);
 - art/blender/jacare_animado.blend.
Patas por cinemática inversa (cotovelos e joelhos abertos para os lados), tronco e cauda
em onda lateral com atraso entre segmentos, mandíbula articulada.
"""
import bpy, math, sys, traceback
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

RAIZ = Path(__file__).resolve().parents[1]
lib = {'__name__': 'lib', '__file__': str(RAIZ/'tools/animar_capivara.py')}
exec(compile((RAIZ/'tools/animar_capivara.py').read_text(encoding='utf-8'), 'animar_capivara', 'exec'), lib)
Base, pata, PATAS, exportar = lib['Capivara'], lib['pata'], lib['PATAS'], lib['exportar']
suave, Curva = lib['suave'], lib['Curva']
TAU = math.tau
COLUNA = ['tronco', 'pescoco', 'cabeca', 'mandibula', 'cauda_1', 'cauda_2', 'cauda_3', 'cauda_4']


class Jacare(Base):
    def __init__(self):
        super().__init__('jacare')
        self.cena.name = 'Jacare_Animado'

    def rotacao(self, nome, a):
        """a = (cabeceio, rolagem, guinada) em eixos do mundo no repouso: cabeceio > 0 baixa a
        ponta do osso que aponta para a frente; guinada > 0 vira para +x."""
        inv = self.rest[nome].to_3x3().inverted()
        return (Quaternion(inv@Vector((0, 0, 1)), -a.z)@Quaternion(inv@Vector((1, 0, 0)), a.x)
                @ Quaternion(inv@Vector((0, 1, 0)), a.y))

    def aplicar(self, P):
        R = self.rig.pose.bones
        for b in R:
            b.matrix_basis = Matrix.Identity(4)
        r, g = P.get('raiz', Vector()), P.get('giro', Vector())
        R['raiz'].location = Vector((r.x, r.z, -r.y))
        R['raiz'].rotation_quaternion = self.rotacao('raiz', Vector((g.x, g.y, g.z)))
        for n in COLUNA:
            R[n].rotation_quaternion = self.rotacao(n, P.get(n, Vector()))
        self.atualizar()
        for p in PATAS:
            m, l = p
            s = 1 if l == 'E' else -1
            sup, can, pe = '%s_%s' % p, '%s_canela_%s' % p, '%s_pe_%s' % p
            alvo = self.tornozelo[p]+P['patas'][p][0]
            ombro = R[sup].head.copy()
            # Postura aberta: cotovelo para fora e para trás, joelho para fora e para a frente.
            polo = Vector((s, .55, .35)) if m == 'frente' else Vector((s, -.55, .35))
            joelho, alvo = self.dois_ossos(sup, can, ombro, alvo, polo)
            self.apontar(sup, ombro, joelho)
            self.atualizar()
            self.apontar(can, joelho, alvo)
            self.atualizar()
            rot = Matrix.Rotation(P['patas'][p][1], 4, 'X')
            R[pe].matrix = Matrix.Translation(alvo)@(rot@self.rest[pe].to_3x3().to_4x4())


def onda(t, amp, fase=0.0, freq=1.0):
    """Ondulação lateral: cada segmento da cauda atrasa em relação ao anterior."""
    res = {}
    for i, n in enumerate(['tronco', 'cauda_1', 'cauda_2', 'cauda_3', 'cauda_4']):
        ganho = (.55, .7, 1.0, 1.3, 1.6)[i]
        res[n] = Vector((0, 0, amp*ganho*math.sin(TAU*(freq*t-.11*i)+fase)))
    return res


def marcha(fases, apoio, passada, ergue):
    return lambda t: {p: pata((t+fases[p]) % 1, apoio, passada, ergue) for p in PATAS}


def base_pose():
    return {'raiz': Vector(), 'giro': Vector(), **{n: Vector() for n in COLUNA}, 'patas': {p: (Vector(), 0.0) for p in PATAS}}


def clipe_andar(c):
    """Andar alto: pares diagonais, corpo erguido, tronco e cauda em S."""
    patas = marcha({('frente', 'E'): 0, ('tras', 'D'): .04, ('frente', 'D'): .5, ('tras', 'E'): .54}, .72, .26, .05)

    def f(t):
        P = base_pose()
        P.update(onda(t, .1, 0.0))
        P['raiz'] = Vector((.008*math.sin(TAU*t), 0, .075+.006*math.cos(2*TAU*t)))
        P['giro'] = Vector((-.02, .03*math.sin(TAU*t), 0))
        P['pescoco'] = Vector((.02, 0, -.06*math.sin(TAU*t)))
        P['cabeca'] = Vector((-.03, 0, -.05*math.sin(TAU*t-.2)))
        P['patas'] = patas(t)
        return P
    return f


def clipe_correr(c):
    """Corrida: passos rápidos e ondulação forte; corpo mais baixo."""
    patas = marcha({('frente', 'E'): 0, ('tras', 'D'): .06, ('frente', 'D'): .5, ('tras', 'E'): .56}, .5, .42, .07)

    def f(t):
        P = base_pose()
        P.update(onda(t, .2, 0.0))
        P['raiz'] = Vector((.015*math.sin(TAU*t), 0, .06+.01*math.cos(2*TAU*t)))
        P['giro'] = Vector((-.02, .06*math.sin(TAU*t), 0))
        P['pescoco'] = Vector((.03, 0, -.12*math.sin(TAU*t)))
        P['cabeca'] = Vector((-.02, 0, -.08*math.sin(TAU*t-.2)))
        P['patas'] = patas(t)
        return P
    return f


def clipe_parada(c):
    """Em repouso: respira, a cauda balança devagar e a boca se abre para aquecer."""
    boca = Curva([(0, 0.0), (.4, 0.0), (.52, .42), (.78, .42), (.9, 0.0)])
    cabeca = Curva([(0, 0.0), (.2, -.05), (.4, -.07), (.52, -.12), (.78, -.12), (.9, -.02)])
    olhar = Curva([(0, 0.0), (.12, .0), (.22, .12), (.34, .1), (.4, 0.0)])

    def f(t):
        P = base_pose()
        resp = math.sin(TAU*3*t)
        P.update(onda(t, .035, 0.0))
        P['raiz'] = Vector((0, 0, .012+.003*resp))
        P['tronco'] = P['tronco']+Vector((-.006*resp, 0, 0))
        P['pescoco'] = Vector((cabeca(t)*.4, 0, olhar(t)*.5))
        P['cabeca'] = Vector((cabeca(t), 0, olhar(t)*.5))
        P['mandibula'] = Vector((boca(t)+.02*math.sin(TAU*9*t)*boca(t), 0, 0))
        return P
    return f


def clipe_batalha(c, nome):
    def f(t):
        P = base_pose()
        P['raiz'] = Vector((0, 0, .06))
        if nome in ('investida', 'errar_ataque'):
            erro = nome == 'errar_ataque'
            prepara = suave(0, .22, t)*(1-suave(.24, .36, t))
            avanco = suave(.24, .44, t)*(1-suave(.62, 1, t))
            abre = suave(.26, .4, t)*(1-suave(.43, .48, t))
            sacode = suave(.46, .52, t)*(1-suave(.62, .76, t))
            P['raiz'] = Vector((0, .07*prepara-.34*avanco, .06+.03*avanco-(.03 if erro else 0)*suave(.5, .6, t)))
            P['giro'] = Vector((-.05*avanco, 0, (.3 if erro else 0)*avanco))
            P.update(onda(t, .12*prepara+.08*sacode, 0.0, 2.0))
            P['pescoco'] = Vector((-.12*abre, 0, .18*sacode*math.sin(TAU*3*t)))
            P['cabeca'] = Vector((-.2*abre+.06*avanco, 0, .25*sacode*math.sin(TAU*3*t+.4)))
            P['mandibula'] = Vector((.75*abre, 0, 0))
            for p in PATAS:
                passo = .16 if p[0] == 'frente' else .1
                atraso = 0 if p[0] == 'tras' else .03
                P['patas'][p] = (Vector((0, -passo*suave(.26+atraso, .44+atraso, t)*(1-suave(.66, 1, t)),
                                         .05*math.sin(math.pi*suave(.26+atraso, .42+atraso, t)))), 0.0)
        elif nome == 'receber_golpe':
            choque = suave(0, .12, t)*(1-suave(.3, 1, t))
            P['raiz'] = Vector((-.02*choque, .1*choque, .06-.02*choque))
            P['giro'] = Vector((-.08*choque, .12*choque, -.1*choque))
            P.update(onda(t, .25*choque, 0.0, 2.5))
            P['pescoco'] = Vector((-.15*choque, 0, .1*choque))
            P['cabeca'] = Vector((-.2*choque, 0, 0))
            P['mandibula'] = Vector((.45*choque, 0, 0))
        else:
            desvio = suave(0, .28, t)*(1-suave(.55, 1, t))
            P['raiz'] = Vector((.18*desvio, 0, .06+.02*math.sin(math.pi*suave(0, .5, t))))
            P['giro'] = Vector((0, .1*desvio, .22*desvio))
            P.update(onda(t, .22*desvio, 1.2, 1.0))
            P['cabeca'] = Vector((0, 0, -.2*desvio))
            for p in PATAS:
                atraso = 0 if p[0] == 'frente' else .05
                lado = suave(.04+atraso, .28+atraso, t)*(1-suave(.55+atraso, .95, t))
                P['patas'][p] = (Vector((.18*lado, 0, .04*math.sin(math.pi*min(1.0, lado*2)))), 0.0)
        return P
    return f


def principal():
    c = Jacare()
    c.clipe('parada', 120, clipe_parada(c))
    c.clipe('andar', 36, clipe_andar(c))
    c.clipe('correr', 22, clipe_correr(c))
    for nome in ('investida', 'errar_ataque', 'receber_golpe', 'esquivar'):
        c.clipe(nome, 28, clipe_batalha(c, nome), laco=False)
    base = {'parada', 'andar', 'correr'}
    exportar(c, RAIZ/'assets/models/animais/jacare_papo_amarelo.glb', base)
    exportar(c, RAIZ/'assets/models/animais/batalha/jacare_papo_amarelo.glb', base | {'investida', 'errar_ataque', 'receber_golpe', 'esquivar'})
    bpy.data.libraries.write(str(RAIZ/'art/blender/jacare_animado.blend'), {c.cena}, fake_user=True, compress=True)
    print('JACARE ANIMADO', [t.name for t in c.rig.animation_data.nla_tracks])


if __name__ == '__main__':
    try:
        principal()
    except Exception:
        traceback.print_exc()
    sys.stdout.flush()
    import os
    os._exit(0)
