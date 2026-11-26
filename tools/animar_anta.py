"""Animações da anta (inspeção, encontro e batalha).

Uso (com janela; fecha o Blender ao terminar):
  blender --factory-startup --python tools/animar_anta.py
Parte de art/blender/anta.blend (tools/modelar_anta.py) e grava:
 - assets/models/animais/anta.glb          parada, andar, correr;
 - assets/models/animais/batalha/anta.glb  + investida, errar_ataque, receber_golpe,
   esquivar (mesmos nomes e momento de contato, ~0,53 s);
 - art/blender/anta_animada.blend.
Patas por cinemática inversa (carpo avança, jarrete recua), peso que balança sobre as
patas de apoio e tromba com movimento próprio, atrasado em relação à cabeça.
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
COLUNA = ['tronco', 'pescoco', 'cabeca', 'tromba']


class Anta(Base):
    def __init__(self):
        super().__init__('anta')

    def rotacao(self, nome, a):
        """a = (cabeceio, rolagem, guinada) nos eixos do mundo no repouso; cabeceio > 0
        baixa a ponta de um osso voltado para a frente; guinada > 0 vira para +x."""
        inv = self.rest[nome].to_3x3().inverted()
        return (Quaternion(inv@Vector((0, 0, 1)), -a.z)@Quaternion(inv@Vector((1, 0, 0)), a.x)
                @ Quaternion(inv@Vector((0, 1, 0)), a.y))

    def aplicar(self, P):
        R = self.rig.pose.bones
        for b in R:
            b.matrix_basis = Matrix.Identity(4)
        r, g = P.get('raiz', Vector()), P.get('giro', Vector())
        R['raiz'].location = Vector((r.x, r.z, -r.y))
        R['raiz'].rotation_quaternion = self.rotacao('raiz', g)
        for n in COLUNA:
            R[n].rotation_quaternion = self.rotacao(n, P.get(n, Vector()))
        self.atualizar()
        for p in PATAS:
            m, l = p
            sup, can, pe = '%s_%s' % p, '%s_canela_%s' % p, '%s_pe_%s' % p
            alvo = self.tornozelo[p]+P['patas'][p][0]
            ombro = R[sup].head.copy()
            # Ungulado: o carpo avança e o jarrete recua ao flexionar.
            polo = Vector((0, -1, 0)) if m == 'frente' else Vector((0, 1, 0))
            joelho, alvo = self.dois_ossos(sup, can, ombro, alvo, polo)
            self.apontar(sup, ombro, joelho)
            self.atualizar()
            self.apontar(can, joelho, alvo)
            self.atualizar()
            rot = Matrix.Rotation(P['patas'][p][1], 4, 'X')
            R[pe].matrix = Matrix.Translation(alvo)@(rot@self.rest[pe].to_3x3().to_4x4())


def marcha(fases, apoio, passada, ergue):
    return lambda t: {p: pata((t+fases[p]) % 1, apoio, passada, ergue) for p in PATAS}


def base_pose():
    return {'raiz': Vector(), 'giro': Vector(), **{n: Vector() for n in COLUNA}, 'patas': {p: (Vector(), 0.0) for p in PATAS}}


def clipe_andar(c):
    """Passo de quatro tempos, pesado: o corpo balança sobre a pata de apoio, a cabeça
    acena e a tromba segue com atraso."""
    patas = marcha({('tras', 'E'): 0, ('frente', 'E'): .25, ('tras', 'D'): .5, ('frente', 'D'): .75}, .66, .46, .07)

    def f(t):
        P = base_pose()
        P['raiz'] = Vector((.018*math.sin(TAU*t), 0, -.008+.012*math.cos(2*TAU*t)))
        P['giro'] = Vector((.012*math.sin(2*TAU*t+.4), .035*math.sin(TAU*t), .025*math.sin(TAU*t+.6)))
        P['tronco'] = Vector((.01*math.cos(2*TAU*t), 0, -.02*math.sin(TAU*t)))
        P['pescoco'] = Vector((.08+.035*math.cos(2*TAU*t+.6), 0, .03*math.sin(TAU*t+.5)))
        P['cabeca'] = Vector((.04+.04*math.cos(2*TAU*t+1.0), 0, -.03*math.sin(TAU*t+.3)))
        P['tromba'] = Vector((.1+.08*math.cos(2*TAU*t+1.6), 0, .12*math.sin(TAU*t+1.2)))
        P['patas'] = patas(t)
        return P
    return f


def clipe_correr(c):
    """Trote diagonal de fuga: pares diagonais juntos, cabeça estendida, tromba recolhida."""
    patas = marcha({('frente', 'E'): 0, ('tras', 'D'): .03, ('frente', 'D'): .5, ('tras', 'E'): .53}, .46, .72, .11)

    def f(t):
        P = base_pose()
        P['raiz'] = Vector((.012*math.sin(TAU*t), 0, .02*math.sin(2*TAU*t-.6)))
        P['giro'] = Vector((-.03+.02*math.sin(2*TAU*t), .02*math.sin(TAU*t), 0))
        P['tronco'] = Vector((.015*math.sin(2*TAU*t), 0, 0))
        P['pescoco'] = Vector((-.05+.03*math.sin(2*TAU*t+.8), 0, 0))
        P['cabeca'] = Vector((-.06+.03*math.sin(2*TAU*t+1.2), 0, 0))
        P['tromba'] = Vector((-.12+.06*math.sin(2*TAU*t+1.8), 0, .05*math.sin(TAU*t)))
        P['patas'] = patas(t)
        return P
    return f


def clipe_parada(c):
    """Pastando: baixa a cabeça, a tromba explora e puxa folhas, mastiga, ergue e olha."""
    baixa = Curva([(0, .0), (.1, .0), (.2, .55), (.52, .55), (.62, .05), (.9, .0)])
    olhar = Curva([(0, 0.0), (.62, 0.0), (.7, .32), (.8, .3), (.86, -.2), (.94, -.15)])
    puxa = Curva([(0, 0.0), (.24, 0.0), (.28, .35), (.33, -.1), (.38, .3), (.43, -.12), (.48, .25), (.52, 0.0)])

    def f(t):
        P = base_pose()
        b = baixa(t)
        resp = math.sin(TAU*4*t)
        mastiga = .03*math.sin(TAU*18*t)*suave(.5, .56, t)*(1-suave(.66, .72, t))
        P['raiz'] = Vector((.006*math.sin(TAU*t), .02*b, .004*resp-.012*b))
        P['giro'] = Vector((.04*b, .015*math.sin(TAU*t), 0))
        P['tronco'] = Vector((.008*resp+.03*b, 0, 0))
        P['pescoco'] = Vector((.42*b, 0, .5*olhar(t)))
        P['cabeca'] = Vector((.35*b+mastiga, 0, .45*olhar(t)))
        P['tromba'] = Vector((.25*b+puxa(t)+.06*math.sin(TAU*7*t), 0, .18*math.sin(TAU*3*t+.4)))
        return P
    return f


def clipe_batalha(c, nome):
    def f(t):
        P = base_pose()
        if nome in ('investida', 'errar_ataque'):
            erro = nome == 'errar_ataque'
            prepara = suave(0, .22, t)*(1-suave(.24, .38, t))
            avanco = suave(.24, .45, t)*(1-suave(.62, 1, t))
            golpe = suave(.4, .47, t)*(1-suave(.5, .66, t))
            P['raiz'] = Vector((0, .07*prepara-.26*avanco, -.05*prepara+.02*avanco-(.04 if erro else 0)*suave(.5, .6, t)*(1-suave(.7, 1, t))))
            P['giro'] = Vector((-.05*prepara+.05*avanco-.08*golpe, 0, (.25 if erro else 0)*avanco))
            P['pescoco'] = Vector((.25*prepara+.12*avanco-.18*golpe, 0, (.12 if erro else 0)*golpe))
            P['cabeca'] = Vector((.15*prepara+.1*avanco-.3*golpe, 0, (.18 if erro else 0)*golpe))
            P['tromba'] = Vector((-.25*golpe+.1*prepara, 0, 0))
            for p in PATAS:
                passo = .18 if p[0] == 'frente' else .1
                atraso = 0 if p[0] == 'tras' else .03
                P['patas'][p] = (Vector((0, -passo*suave(.26+atraso, .44+atraso, t)*(1-suave(.66, 1, t)),
                                         .07*math.sin(math.pi*suave(.26+atraso, .43+atraso, t)))), 0.0)
        elif nome == 'receber_golpe':
            choque = suave(0, .12, t)*(1-suave(.3, 1, t))
            P['raiz'] = Vector((-.03*choque, .12*choque, -.03*choque))
            P['giro'] = Vector((-.1*choque, .1*choque, -.06*choque))
            P['pescoco'] = Vector((-.25*choque, 0, .12*choque))
            P['cabeca'] = Vector((-.12*choque, 0, 0))
            P['tromba'] = Vector((-.35*choque, 0, .2*math.sin(TAU*2*t)*choque))
        else:
            salto = suave(0, .28, t)*(1-suave(.55, 1, t))
            P['raiz'] = Vector((.2*salto, 0, .05*math.sin(math.pi*suave(0, .48, t))))
            P['giro'] = Vector((0, .1*salto, .12*salto))
            P['cabeca'] = Vector((0, 0, -.2*salto))
            P['tromba'] = Vector((0, 0, -.25*salto))
            for p in PATAS:
                atraso = 0 if p[0] == 'frente' else .05
                lado = suave(.04+atraso, .28+atraso, t)*(1-suave(.55+atraso, .95, t))
                P['patas'][p] = (Vector((.2*lado, 0, .06*math.sin(math.pi*min(1.0, lado*2)))), 0.0)
        return P
    return f


def principal():
    c = Anta()
    c.clipe('parada', 144, clipe_parada(c))
    c.clipe('andar', 36, clipe_andar(c))
    c.clipe('correr', 20, clipe_correr(c))
    for nome in ('investida', 'errar_ataque', 'receber_golpe', 'esquivar'):
        c.clipe(nome, 28, clipe_batalha(c, nome), laco=False)
    base = {'parada', 'andar', 'correr'}
    exportar(c, RAIZ/'assets/models/animais/anta.glb', base)
    exportar(c, RAIZ/'assets/models/animais/batalha/anta.glb', base | {'investida', 'errar_ataque', 'receber_golpe', 'esquivar'})
    bpy.data.libraries.write(str(RAIZ/'art/blender/anta_animada.blend'), {c.cena}, fake_user=True, compress=True)
    print('ANTA ANIMADA', [t.name for t in c.rig.animation_data.nla_tracks])


if __name__ == '__main__':
    try:
        principal()
    except Exception:
        traceback.print_exc()
    sys.stdout.flush()
    import os
    os._exit(0)
