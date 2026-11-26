"""Clipes de pesca dos moradores (etapa 12).

Uso (com janela; fecha o Blender ao terminar):
  blender --factory-startup --python tools/animar_pescador.py [-- homem_01 ...]
Reaproveita o rig e a cinemática inversa de tools/animar_moradores.py e grava
assets/models/habitantes/pesca/<tag>.glb com a vara (Prop_Vara: só o cabo; o resto da
vara é dobrado no Godot pela tensão da linha) e os clipes:
 - pesca_espera  (laço)  vara apontada para a água, respiração e olhar na boia;
 - pesca_lancar          vara vai por cima do ombro e chicoteia; solta a linha em ~55%;
 - pesca_fisgar          puxão curto e seco para cravar o anzol;
 - pesca_puxar   (laço)  corpo para trás, vara alta, bombeando;
 - pesca_ceder   (laço)  corpo para a frente, vara baixa apontada para o peixe;
 - pesca_erguer          a mão esquerda pega o peixe e o ergue para mostrar.
No Godot as duas poses de briga são misturadas pela entrada do jogador.
"""
import bpy, sys, traceback, time
from pathlib import Path
from mathutils import Matrix

RAIZ = Path(__file__).resolve().parents[1]
lib = {'__name__': 'lib', '__file__': str(RAIZ/'tools/animar_moradores.py')}
exec(compile((RAIZ/'tools/animar_moradores.py').read_text(encoding='utf-8'), 'animar_moradores', 'exec'), lib)
Morador, V, norm, chaves, curvas = lib['Morador'], lib['V'], lib['norm'], lib['chaves'], lib['curvas']
pose_de, respirar, material, malha_ferramenta, exportar, TAGS = (lib['pose_de'], lib['respirar'], lib['material'],
                                                                 lib['malha_ferramenta'], lib['exportar'], lib['TAGS'])

PES = {'peE': V(.05, -.13, 0), 'peD': V(.02, .17, 0), 'giroD': .32, 'giroE': -.08}
SEGURA = {'ferr': 'Prop_Vara', 'segunda': .3, 'cima': V(1, 0, 0), **PES}
PRONTA = {'pega': V(-.12, -.3, 1.02), 'eixo': norm(.04, -1, .62), 'raiz': V(0, 0, -.03), 'pelve': V(.06, 0, 0),
          'coluna': V(.05, 0, 0), 'peito': V(.02, 0, 0), 'pescoco': V(0, 0, 0), 'cabeca': V(.18, 0, 0)}
PUXA = {'pega': V(-.13, -.16, 1.18), 'eixo': norm(.05, -.55, 1), 'raiz': V(0, .08, -.07), 'pelve': V(-.1, 0, 0),
        'coluna': V(-.05, 0, 0), 'peito': V(-.06, 0, 0), 'cabeca': V(.14, 0, 0), 'peD': V(.02, .24, 0), 'peE': V(.05, -.15, 0)}
CEDE = {'pega': V(-.1, -.4, .98), 'eixo': norm(0, -1, .32), 'raiz': V(0, -.04, -.05), 'pelve': V(.18, 0, 0),
        'coluna': V(.1, 0, 0), 'peito': V(.06, 0, 0), 'cabeca': V(.2, 0, 0)}


def criar_vara(m):
    madeira = material('Vara_Taquara', 'a88a52', .6)
    fibra = material('Vara_Fibra', '7d6440', .9)
    me = malha_ferramenta('Prop_Vara', [('cone', (-.3, .55, .017, .012), madeira), ('cone', (-.06, .14, .02, .019), fibra),
                                        ('cone', (.28, .31, .015, .015), fibra)])
    o = bpy.data.objects.new('Prop_Vara', me)
    m.cena.collection.objects.link(o)
    for b in m.rig.pose.bones:
        b.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    o.parent = m.rig
    o.parent_type = 'BONE'
    o.parent_bone = 'mao_D'
    b = m.arm.bones['mao_D']
    W = Matrix.Translation(b.head_local+(b.tail_local-b.head_local)*.6)
    o.matrix_world = W
    m.props_rest = {'Prop_Vara': W.copy()}


def clipe(m, lista, base, ciclica=True, respira=2, tremor=0.0):
    c = curvas(chaves(dict(m.base(), **base), lista), ciclica)

    def f(t):
        p = c(t)
        p['peito'] = p['peito']+V(-respirar(t, respira, .01), 0, 0)
        if tremor:
            p['pega'] = p['pega']+V(.004, 0, .006)*__import__('math').sin(t*__import__('math').tau*7)*tremor
        return pose_de(m, p)
    return f


def espera(m):
    return clipe(m, [
        (0, PRONTA),
        (.25, {'pega': V(-.12, -.3, 1.035), 'eixo': norm(.06, -1, .64), 'cabeca': V(.2, .08, 0), 'raiz': V(.01, 0, -.035)}),
        (.5, {'pega': V(-.125, -.3, 1.025), 'eixo': norm(.02, -1, .6), 'cabeca': V(.16, -.05, 0), 'raiz': V(-.01, 0, -.03)}),
        (.75, {'cabeca': V(.19, .03, 0), 'raiz': V(0, 0, -.032)}),
    ], SEGURA)


def lancar(m):
    return clipe(m, [
        (0, PRONTA),
        (.3, {'pega': V(-.2, .02, 1.38), 'eixo': norm(.15, .55, 1), 'raiz': V(0, .07, -.02), 'pelve': V(-.08, -.2, 0),
              'coluna': V(-.06, -.12, 0), 'peito': V(-.08, -.15, 0), 'cabeca': V(.05, .1, 0), 'peD': V(.02, .2, 0)}),
        (.42, {'pega': V(-.19, .0, 1.4), 'eixo': norm(.12, .45, 1)}),
        (.55, {'pega': V(-.12, -.38, 1.28), 'eixo': norm(0, -1, .95), 'pelve': V(.12, .08, 0), 'coluna': V(.1, .06, 0),
               'peito': V(.08, .08, 0), 'raiz': V(0, -.06, -.04), 'cabeca': V(.12, 0, 0), 'peD': V(.02, .17, 0)}),
        (.7, {'pega': V(-.12, -.4, 1.08), 'eixo': norm(0, -1, .4), 'pelve': V(.16, .04, 0), 'raiz': V(0, -.05, -.05)}),
        (1.0, PRONTA),
    ], SEGURA, ciclica=False)


def fisgar(m):
    return clipe(m, [
        (0, PRONTA),
        (.3, {'pega': V(-.13, -.14, 1.24), 'eixo': norm(.05, -.4, 1), 'raiz': V(0, .08, -.02), 'pelve': V(-.1, 0, 0),
              'peito': V(-.1, 0, 0), 'cabeca': V(.06, 0, 0), 'peD': V(.02, .22, 0)}),
        (1.0, PUXA),
    ], SEGURA, ciclica=False)


def puxar(m):
    return clipe(m, [
        (0, PUXA),
        (.5, {'pega': V(-.13, -.21, 1.12), 'eixo': norm(.04, -.72, 1), 'raiz': V(0, .06, -.078), 'peito': V(-.03, 0, 0)}),
    ], SEGURA, tremor=1.0)


def ceder(m):
    return clipe(m, [
        (0, CEDE),
        (.5, {'pega': V(-.1, -.42, .965), 'eixo': norm(.02, -1, .3), 'cabeca': V(.22, .03, 0)}),
    ], SEGURA, tremor=.6)


def erguer(m):
    base = {'ferr': 'Prop_Vara', 'cima': V(1, 0, 0), **PES, 'punhoE': .1}
    mao = PUXA['pega']+PUXA['eixo'].normalized()*.3
    return clipe(m, [
        (0, dict(PUXA, absE=mao)),
        (.35, {'pega': V(-.2, -.02, 1.3), 'eixo': norm(.35, .3, 1), 'absE': V(.1, -.32, .92), 'raiz': V(0, .02, -.06),
               'pelve': V(.18, 0, 0), 'coluna': V(.08, 0, 0), 'peito': V(.1, 0, 0), 'cabeca': V(.3, 0, 0), 'punhoE': -.3}),
        (.65, {'absE': V(.14, -.34, 1.3), 'raiz': V(0, 0, -.02), 'pelve': V(0, 0, 0), 'coluna': V(0, 0, 0),
               'peito': V(-.05, -.15, 0), 'cabeca': V(.05, -.22, 0), 'punhoE': .2}),
        (1.0, {'absE': V(.15, -.31, 1.33), 'cabeca': V(.08, -.26, 0)}),
    ], base, ciclica=False)


CLIPES = [('pesca_espera', 96, espera, True), ('pesca_lancar', 32, lancar, False), ('pesca_fisgar', 16, fisgar, False),
          ('pesca_puxar', 24, puxar, True), ('pesca_ceder', 36, ceder, True), ('pesca_erguer', 40, erguer, False)]


def produzir(tag):
    m = Morador(tag)
    criar_vara(m)
    for nome, quadros, fn, laco in CLIPES:
        m.clipe(nome, quadros, fn(m), laco=laco)
    exportar(m, RAIZ/'assets/models/habitantes/pesca'/(tag+'.glb'), {c[0] for c in CLIPES}, True)
    print('PESCADOR', tag)
    return m.cena


def principal():
    args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    tags = [a for a in args if a in TAGS] or TAGS
    cenas = {produzir(t) for t in tags}
    if len(tags) == len(TAGS):
        bpy.data.libraries.write(str(RAIZ/'art/blender/pescadores_animados.blend'), cenas, fake_user=True, compress=True)
    print('PESCADORES PRONTOS', round(time.time()-INICIO))


INICIO = time.time()
if __name__ == '__main__':
    try:
        principal()
    except Exception:
        traceback.print_exc()
    sys.stdout.flush()
    import os
    os._exit(0)
