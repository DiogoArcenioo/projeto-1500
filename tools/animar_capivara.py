"""Animações dos animais com patas plantadas (inspeção, encontro e batalha).

Uso (com janela; fecha o Blender ao terminar):
  blender --factory-startup --python tools/animar_capivara.py [-- capivara|queixada]
Queixada: parte de art/blender/queixada.blend (tools/modelar_queixada.py) e grava
assets/models/animais/queixada.glb, batalha/queixada.glb e queixada_animada.blend.
Parte do modelo e rig aprovados em art/blender/capivara.blend (não é alterado) e
grava:
 - assets/models/animais/capivara.glb          parada, andar, correr;
 - assets/models/animais/batalha/capivara.glb  as mesmas + investida, errar_ataque,
   receber_golpe, esquivar (mesmos nomes, quadros e momento de contato, ~0,53 s);
 - art/blender/capivara_animada.blend.
As patas são posicionadas por cinemática inversa: no apoio ficam paradas no chão
(sem escorregar) e no balanço sobem em arco. Andar é uma marcha de quatro tempos;
correr é um galope curto com flexão do tronco.
"""
import bpy, math, sys, traceback
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion, Euler

RAIZ = Path(__file__).resolve().parents[1]
lib = {'__name__': 'lib', '__file__': str(RAIZ/'tools/animar_moradores.py')}
exec(compile((RAIZ/'tools/animar_moradores.py').read_text(encoding='utf-8'), 'animar_moradores', 'exec'), lib)
suave, Curva = lib['suave'], lib['Curva']
TAU = math.tau
PATAS = [(m, l) for m in ('frente', 'tras') for l in ('E', 'D')]


class Capivara:
    def __init__(self, especie='capivara'):
        self.especie = especie
        with bpy.data.libraries.load(str(RAIZ/'art/blender'/(especie+'.blend'))) as (o, d):
            d.scenes = [o.scenes[0]]
        self.cena = d.scenes[0]
        self.cena.name = especie.capitalize()+'_Animada'
        bpy.context.window.scene = self.cena
        self.rig = next(o for o in self.cena.objects if o.type == 'ARMATURE')
        self.arm = self.rig.data
        ad = self.rig.animation_data
        for tr in list(ad.nla_tracks):
            ad.nla_tracks.remove(tr)
        ad.action = None
        self.malha = next(o for o in self.cena.objects if o.type == 'MESH')
        for m in self.malha.modifiers:
            if m.type == 'ARMATURE':
                m.show_viewport = False
        for b in self.rig.pose.bones:
            b.rotation_mode = 'QUATERNION'
        self.rest = {b.name: b.matrix_local.copy() for b in self.arm.bones}
        self.tornozelo = {p: self.arm.bones['%s_pe_%s' % p].head_local.copy() for p in PATAS}

    def atualizar(self):
        bpy.context.view_layer.update()

    def apontar(self, n, cabeca, cauda):
        b = self.arm.bones[n]
        q = (b.tail_local-b.head_local).rotation_difference(cauda-cabeca)@b.matrix_local.to_quaternion()
        self.rig.pose.bones[n].matrix = Matrix.Translation(cabeca)@q.to_matrix().to_4x4()

    def dois_ossos(self, a, b, raiz, alvo, polo):
        la, lb = self.arm.bones[a].length, self.arm.bones[b].length
        d = alvo-raiz
        dist = max(.01, min(d.length, (la+lb)*.999))
        d.normalize()
        alvo = raiz+d*dist
        proj = (la*la-lb*lb+dist*dist)/(2*dist)
        polo = (polo-d*polo.dot(d)).normalized()
        return raiz+d*proj+polo*math.sqrt(max(0.0, la*la-proj*proj)), alvo

    def aplicar(self, P):
        R = self.rig.pose.bones
        for b in R:
            b.matrix_basis = Matrix.Identity(4)
        r = P.get('raiz', Vector())
        g = P.get('giro', Vector())
        R['raiz'].location = Vector((r.x, r.z, -r.y))
        R['raiz'].rotation_quaternion = Euler((g.x, g.z, -g.y), 'YXZ').to_quaternion()
        for n in ('tronco', 'pescoco', 'cabeca'):
            a = P.get(n, Vector())
            # Ossos horizontais (apontam para -y): x > 0 baixa a cabeça, z = guinada.
            R[n].rotation_quaternion = Euler((a.x, a.z, a.y), 'XYZ').to_quaternion()
        self.atualizar()
        for p in PATAS:
            m, l = p
            sup, can, pe = '%s_%s' % p, '%s_canela_%s' % p, '%s_pe_%s' % p
            alvo = self.tornozelo[p]+P['patas'][p][0]
            ombro = R[sup].head.copy()
            # Direção em que a articulação do meio dobra. Na queixada o carpo avança e o
            # jarrete recua (ungulado); na capivara, o contrário.
            polo = Vector((0, 1, 0)) if m == 'frente' else Vector((0, -1, 0))
            if self.especie == 'queixada':
                polo = -polo
            joelho, alvo = self.dois_ossos(sup, can, ombro, alvo, polo)
            self.apontar(sup, ombro, joelho)
            self.atualizar()
            self.apontar(can, joelho, alvo)
            self.atualizar()
            rot = Matrix.Rotation(P['patas'][p][1], 4, 'X')
            R[pe].matrix = Matrix.Translation(alvo)@(rot@self.rest[pe].to_3x3().to_4x4())

    def clipe(self, nome, quadros, f, laco=True):
        rig = self.rig
        rig.animation_data.action = None
        n = quadros+1 if laco else quadros
        for q in range(n):
            t = q/quadros if laco else q/(quadros-1)
            self.aplicar(f(t))
            for b in rig.pose.bones:
                b.keyframe_insert('location', frame=q+1)
                b.keyframe_insert('rotation_quaternion', frame=q+1)
        acao = rig.animation_data.action
        acao.name = self.especie+'_'+nome
        acao.use_fake_user = True
        tr = rig.animation_data.nla_tracks.new()
        tr.name = nome
        faixa = tr.strips.new(nome, 1, acao)
        if acao.slots:
            faixa.action_slot = acao.slots[0]
        tr.mute = True
        rig.animation_data.action = None


def pata(fase, apoio, passada, ergue):
    """Deslocamento da pata (em relação ao repouso) e flexão do pé."""
    if fase < apoio:
        s = fase/apoio
        return Vector((0, -passada/2+passada*s, 0)), .35*suave(.8, 1, s)
    s = (fase-apoio)/(1-apoio)
    y = passada/2-passada*(1-math.cos(math.pi*s))/2
    return Vector((0, y, ergue*math.sin(math.pi*s)**.9)), .35+(.5-.35)*math.sin(math.pi*s)-.35*suave(.6, 1, s)


def marcha(fases, apoio, passada, ergue):
    def patas(t):
        return {p: pata((t+fases[p]) % 1, apoio, passada, ergue) for p in PATAS}
    return patas


def clipe_andar(c):
    patas = marcha({('tras', 'E'): 0, ('frente', 'E'): .25, ('tras', 'D'): .5, ('frente', 'D'): .75}, .68, .2, .045)

    def f(t):
        return {'raiz': Vector((.006*math.sin(TAU*t), 0, -.004+.006*math.cos(2*TAU*t))),
                'giro': Vector((.01*math.sin(2*TAU*t), .025*math.sin(TAU*t), .02*math.sin(TAU*t+.8))),
                'tronco': Vector((.01*math.cos(2*TAU*t), 0, -.02*math.sin(TAU*t))),
                'pescoco': Vector((-.02*math.cos(2*TAU*t), 0, .025*math.sin(TAU*t+.5))),
                'cabeca': Vector((.03*math.cos(2*TAU*t+.4), 0, -.02*math.sin(TAU*t))),
                'patas': patas(t)}
    return f


def clipe_correr(c):
    patas = marcha({('tras', 'E'): 0, ('tras', 'D'): .07, ('frente', 'E'): .45, ('frente', 'D'): .52}, .4, .38, .085)

    def f(t):
        flexao = math.sin(TAU*t)
        return {'raiz': Vector((0, .02*flexao, .025*max(0.0, math.sin(TAU*(t-.2)))-.01)),
                'giro': Vector((.07*math.sin(TAU*t+.3), 0, 0)),
                'tronco': Vector((.06*flexao, 0, 0)),
                'pescoco': Vector((-.06*math.sin(TAU*t+.6), 0, 0)),
                'cabeca': Vector((-.04*math.sin(TAU*t+.9), 0, 0)),
                'patas': patas(t)}
    return f


def clipe_parada(c):
    olhar = Curva([(0, 0.0), (.2, .0), (.32, .28), (.5, .26), (.6, -.1), (.85, -.12)])
    pastar = Curva([(0, 0.0), (.55, 0.0), (.62, .35), (.66, .33), (.7, .36), (.74, .33), (.8, 0.0)])

    def f(t):
        resp = math.sin(TAU*3*t)
        plantadas = {p: (Vector(), 0.0) for p in PATAS}
        return {'raiz': Vector((.004*math.sin(TAU*t), 0, .003*resp)),
                'giro': Vector((0, .012*math.sin(TAU*t), 0)),
                'tronco': Vector((.006*resp, 0, 0)),
                'pescoco': Vector((.35*pastar(t), 0, .4*olhar(t))),
                'cabeca': Vector((.3*pastar(t)+.02*math.sin(TAU*6*t)*pastar(t), 0, .55*olhar(t))),
                'patas': plantadas}
    return f


def clipe_batalha(c, nome):
    def f(t):
        pulso = math.sin(math.pi*t)**2
        P = {'raiz': Vector(), 'giro': Vector(), 'tronco': Vector(), 'pescoco': Vector(), 'cabeca': Vector(),
             'patas': {p: (Vector(), 0.0) for p in PATAS}}
        if nome in ('investida', 'errar_ataque'):
            prepara = suave(0, .22, t)*(1-suave(.22, .4, t))
            avanco = suave(.24, .45, t)*(1-suave(.6, 1, t))
            P['raiz'] = Vector((0, .05*prepara-.17*avanco, -.035*prepara+.02*avanco))
            P['giro'] = Vector((-.05*prepara+.06*avanco, 0, (.2 if nome == 'errar_ataque' else 0)*avanco))
            P['pescoco'] = Vector((-.1*prepara+.18*avanco, 0, 0))
            P['cabeca'] = Vector((.1*prepara-.25*math.sin(TAU*t)*avanco, 0, 0))
            for p in PATAS:
                passo = .12 if p[0] == 'frente' else .05
                P['patas'][p] = (Vector((0, -passo*suave(.28, .45, t)*(1-suave(.65, 1, t)), .05*math.sin(math.pi*suave(.26, .44, t)))), 0.0)
        elif nome == 'receber_golpe':
            choque = suave(0, .15, t)*(1-suave(.3, 1, t))
            P['raiz'] = Vector((0, .08*choque, -.02*choque))
            P['giro'] = Vector((-.1*choque, .08*choque, 0))
            P['pescoco'] = Vector((-.18*choque, 0, .1*choque))
            P['cabeca'] = Vector((-.1*choque, .12*math.sin(TAU*t)*choque, 0))
        else:
            salto = suave(0, .3, t)*(1-suave(.55, 1, t))
            P['raiz'] = Vector((.14*salto, 0, .05*math.sin(math.pi*suave(0, .5, t))))
            P['giro'] = Vector((0, .1*salto, .08*salto))
            P['cabeca'] = Vector((0, 0, -.14*salto))
            for p in PATAS:
                atraso = 0 if p[0] == 'frente' else .06
                lado = suave(.05+atraso, .3+atraso, t)*(1-suave(.55+atraso, .95, t))
                P['patas'][p] = (Vector((.14*lado, 0, .04*math.sin(math.pi*min(1.0, lado*2)))), 0.0)
        return P
    return f


def exportar(c, caminho, trilhas):
    rig = c.rig
    for tr in rig.animation_data.nla_tracks:
        tr.mute = tr.name not in trilhas
    for b in rig.pose.bones:
        b.matrix_basis = Matrix.Identity(4)
    for m in c.malha.modifiers:
        if m.type == 'ARMATURE':
            m.show_viewport = True
    bpy.ops.object.select_all(action='DESELECT')
    for o in c.cena.objects:
        if o.type in ('ARMATURE', 'MESH', 'EMPTY'):
            o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    caminho.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(caminho), use_selection=True, use_active_scene=True, export_cameras=False,
                              export_lights=False, export_animation_mode='NLA_TRACKS', export_force_sampling=True)
    for m in c.malha.modifiers:
        if m.type == 'ARMATURE':
            m.show_viewport = False


# ---------------------------------------------------------------- queixada

def clipe_andar_queixada(c):
    """Marcha de quatro tempos, passo curto e firme; cabeça acena a cada apoio."""
    patas = marcha({('tras', 'E'): 0, ('frente', 'E'): .25, ('tras', 'D'): .5, ('frente', 'D'): .75}, .64, .24, .05)

    def f(t):
        return {'raiz': Vector((.007*math.sin(TAU*t), 0, -.005+.007*math.cos(2*TAU*t))),
                'giro': Vector((.012*math.sin(2*TAU*t+.4), .03*math.sin(TAU*t), .025*math.sin(TAU*t+.8))),
                'tronco': Vector((.012*math.cos(2*TAU*t), 0, -.025*math.sin(TAU*t))),
                'pescoco': Vector((.06-.03*math.cos(2*TAU*t+.5), 0, .03*math.sin(TAU*t+.5))),
                'cabeca': Vector((.04+.05*math.cos(2*TAU*t+.9), 0, -.025*math.sin(TAU*t))),
                'patas': patas(t)}
    return f


def clipe_correr_queixada(c):
    """Galope curto e potente: posteriores juntos empurram, o tronco flexiona."""
    patas = marcha({('tras', 'E'): 0, ('tras', 'D'): .08, ('frente', 'E'): .48, ('frente', 'D'): .56}, .42, .42, .085)

    def f(t):
        flexao = math.sin(TAU*t)
        return {'raiz': Vector((0, .025*flexao, .028*max(0.0, math.sin(TAU*(t-.18)))-.012)),
                'giro': Vector((.08*math.sin(TAU*t+.3), 0, 0)),
                'tronco': Vector((.07*flexao, 0, 0)),
                'pescoco': Vector((.1-.07*math.sin(TAU*t+.6), 0, 0)),
                'cabeca': Vector((.05-.05*math.sin(TAU*t+.9), 0, 0)),
                'patas': patas(t)}
    return f


def clipe_parada_queixada(c):
    """Alerta: fareja em pequenas fungadas, vira a cabeça e fuça a terra."""
    olhar = Curva([(0, 0.0), (.14, .0), (.24, .3), (.38, .28), (.46, -.18), (.56, -.15), (.62, 0.0)])
    fucar = Curva([(0, 0.0), (.62, 0.0), (.68, .42), (.86, .44), (.93, 0.0)])
    fareja = Curva([(0, 0.0), (.04, 1.0), (.14, 1.0), (.2, 0.0), (.42, 0.0), (.46, 1.0), (.58, 1.0), (.62, 0.0)])

    def f(t):
        resp = math.sin(TAU*4*t)
        fu = fucar(t)
        fungada = .035*math.sin(TAU*22*t)*max(0.0, fareja(t))
        cavar = .04*math.sin(TAU*14*t)*fu
        plantadas = {p: (Vector(), 0.0) for p in PATAS}
        return {'raiz': Vector((.004*math.sin(TAU*t), .01*fu, .003*resp-.01*fu)),
                'giro': Vector((.03*fu, .015*math.sin(TAU*t), 0)),
                'tronco': Vector((.006*resp+.04*fu, 0, 0)),
                'pescoco': Vector((.38*fu+.02*fareja(t), 0, .45*olhar(t))),
                'cabeca': Vector((.32*fu-.1*fareja(t)+fungada+cavar, 0, .5*olhar(t))),
                'patas': plantadas}
    return f


def clipe_batalha_queixada(c, nome):
    """Investida de cabeça baixa com golpe de presas para cima no contato (~0,53 s)."""
    def f(t):
        P = {'raiz': Vector(), 'giro': Vector(), 'tronco': Vector(), 'pescoco': Vector(), 'cabeca': Vector(),
             'patas': {p: (Vector(), 0.0) for p in PATAS}}
        if nome in ('investida', 'errar_ataque'):
            erro = nome == 'errar_ataque'
            prepara = suave(0, .22, t)*(1-suave(.24, .38, t))
            avanco = suave(.24, .45, t)*(1-suave(.62, 1, t))
            golpe = suave(.4, .47, t)*(1-suave(.5, .66, t))
            P['raiz'] = Vector((0, .06*prepara-.2*avanco, -.04*prepara+.015*avanco-(.03 if erro else 0)*suave(.5, .6, t)*(1-suave(.7, 1, t))))
            P['giro'] = Vector((-.06*prepara+.05*avanco-.12*golpe, 0, (.28 if erro else 0)*avanco))
            P['pescoco'] = Vector((.22*prepara+.18*avanco-.2*golpe, 0, 0))
            P['cabeca'] = Vector((.18*prepara+.16*avanco-.55*golpe, 0, (.2 if erro else 0)*golpe))
            for p in PATAS:
                passo = .14 if p[0] == 'frente' else .07
                atraso = 0 if p[0] == 'tras' else .03
                P['patas'][p] = (Vector((0, -passo*suave(.26+atraso, .44+atraso, t)*(1-suave(.66, 1, t)),
                                         .05*math.sin(math.pi*suave(.26+atraso, .43+atraso, t)))), 0.0)
        elif nome == 'receber_golpe':
            choque = suave(0, .12, t)*(1-suave(.28, 1, t))
            P['raiz'] = Vector((-.03*choque, .1*choque, -.025*choque))
            P['giro'] = Vector((-.12*choque, .1*choque, -.06*choque))
            P['pescoco'] = Vector((-.22*choque, 0, .12*choque))
            P['cabeca'] = Vector((-.15*choque, .14*math.sin(TAU*1.5*t)*choque, 0))
        else:
            salto = suave(0, .28, t)*(1-suave(.55, 1, t))
            P['raiz'] = Vector((.16*salto, 0, .06*math.sin(math.pi*suave(0, .48, t))))
            P['giro'] = Vector((0, .12*salto, .1*salto))
            P['cabeca'] = Vector((0, 0, -.18*salto))
            for p in PATAS:
                atraso = 0 if p[0] == 'frente' else .05
                lado = suave(.04+atraso, .28+atraso, t)*(1-suave(.55+atraso, .95, t))
                P['patas'][p] = (Vector((.16*lado, 0, .045*math.sin(math.pi*min(1.0, lado*2)))), 0.0)
        return P
    return f


CLIPES = {
    'capivara': {'parada': (64, clipe_parada), 'andar': (32, clipe_andar), 'correr': (20, clipe_correr), 'batalha': clipe_batalha},
    'queixada': {'parada': (96, clipe_parada_queixada), 'andar': (28, clipe_andar_queixada),
                 'correr': (18, clipe_correr_queixada), 'batalha': clipe_batalha_queixada},
}


def principal():
    args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    especie = args[0] if args and args[0] in CLIPES else 'capivara'
    c = Capivara(especie)
    cfg = CLIPES[especie]
    for nome in ('parada', 'andar', 'correr'):
        quadros, fn = cfg[nome]
        c.clipe(nome, quadros, fn(c))
    for nome in ('investida', 'errar_ataque', 'receber_golpe', 'esquivar'):
        c.clipe(nome, 28, cfg['batalha'](c, nome), laco=False)
    base = {'parada', 'andar', 'correr'}
    exportar(c, RAIZ/'assets/models/animais'/(especie+'.glb'), base)
    exportar(c, RAIZ/'assets/models/animais/batalha'/(especie+'.glb'), base | {'investida', 'errar_ataque', 'receber_golpe', 'esquivar'})
    salvar_fonte(c)
    print(especie.upper()+' PRONTA', [t.name for t in c.rig.animation_data.nla_tracks])


def salvar_fonte(c):
    for modificador in c.malha.modifiers:
        if modificador.type == 'ARMATURE':
            modificador.show_viewport = True
    for trilha in c.rig.animation_data.nla_tracks:
        trilha.mute = trilha.name != 'parada'
    c.cena.frame_set(1)
    caminho = RAIZ/'art/blender'/(c.especie+'_animada.blend')
    bpy.data.libraries.write(str(caminho), {c.cena}, fake_user=True, compress=True)


if __name__ == '__main__':
    try:
        principal()
    except Exception:
        traceback.print_exc()
    sys.stdout.flush()
    import os
    os._exit(0)
