"""Revisão 4 dos moradores: mesma base aprovada (anatomia CC0 + roupa + cabelo),
com acabamento mais próximo da referência estilizada:
 - corpo liso, sem a decimação que deixava as facetas;
 - braços relaxados junto ao corpo em vez da pose em A;
 - íris maiores e escuras (menos branco aparente);
 - cabelo suavizado.
Uso (com janela; o script fecha o Blender ao terminar):
  blender --factory-startup --python tools/modelar_moradores_v4.py -- [base|tudo]
'base' grava art/blender/moradores_1500_v4.blend e renderiza a dupla;
'tudo' também roda tools/variar_moradores_v4.py (8 variações + GLBs).
"""
import sys
import bpy
from pathlib import Path

RAIZ = Path(r'C:\Users\PC\Documents\ChatGPT\1500')
args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
modo = args[0] if args else 'base'

fonte = (RAIZ/'tools/modelar_moradores_v3.py').read_text(encoding='utf-8')
trocas = [
    # Sem decimação: a superfície fica lisa como na referência.
    ("reducao.ratio=.34", "reducao.ratio=1.0"),
    ("f.use_smooth=min(alturas)>1.48*escala", "f.use_smooth=True"),
    # Íris maiores e escuras (antes .013): menos branco aparente, olhar mais natural.
    ("(.013,.0035,.013),5,'Cabeca',16)", "(.0165,.0035,.0165),5,'Cabeca',16)"),
    ("v2['NOME_CENA']='1500_Moradores_Revisao3'", "v2['NOME_CENA']='1500_Moradores_Revisao4'"),
    ("replace('moradores_1500_v2.blend','moradores_1500_v3.blend')", "replace('moradores_1500_v2.blend','moradores_1500_v4.blend')"),
    ("v2['produzir']()", "pass"),
    # Cabelo assentado com folga maior sobre o crânio liso (sem pele aparecendo).
    ("dist<.045:\n                v.co=proximo+normal*.009", "dist<.08:\n                v.co=proximo+normal*.017"),
    # A roupa se ajusta só ao tronco: braços ficam fora do cálculo (antes viravam "tutu").
    ("    arvore=BVHTree.FromObject(corpo,bpy.context.evaluated_depsgraph_get())\n",
     "    arvore=BVHTree.FromObject(corpo,bpy.context.evaluated_depsgraph_get())\n"
     "    bm_tronco=bmesh.new()\n"
     "    bm_tronco.from_mesh(corpo.data)\n"
     "    bmesh.ops.delete(bm_tronco,geom=[v for v in bm_tronco.verts if abs(v.co.x)>.2*escala and .7*escala<v.co.z<1.47*escala],context='VERTS')\n"
     "    tronco=BVHTree.FromBMesh(bm_tronco)\n"
     "    bm_tronco.free()\n"),
    ("ponto,_,_,_=arvore.ray_cast(origem,-direcao,2.0)", "ponto,_,_,_=tronco.ray_cast(origem,-direcao,2.0)"),
]
for a, b in trocas:
    assert a in fonte, a
    fonte = fonte.replace(a, b)
contexto = {'__name__': 'revisao4'}
exec(compile(fonte, 'modelar_moradores_v4_base', 'exec'), contexto)
v2 = contexto['v2']
v2['produzir']()
cena = bpy.data.scenes['1500_Moradores_Revisao4']

def suavizar_detalhes():
    for o in list(cena.objects):
        if o.type != 'MESH':
            continue
        for f in o.data.polygons:
            f.use_smooth = True
        # Cabelo e roupa: uma subdivisão arredonda os blocos sem perder a forma.
        if o.name.endswith('_CabeloRostoRoupa'):
            mod = o.modifiers.new('Arredondar', 'SUBSURF')
            mod.levels = 1
            mod.render_levels = 1
            with bpy.context.temp_override(scene=cena, object=o, active_object=o):
                bpy.ops.object.modifier_apply(modifier=mod.name)
    print('OBJETOS', [(o.name, o.type) for o in cena.objects])
suavizar_detalhes()

if modo == 'tudo':
    import traceback
    try:
        exec(compile((RAIZ/'tools/variar_moradores_v4.py').read_text(encoding='utf-8'),
                     str(RAIZ/'tools/variar_moradores_v4.py'), 'exec'),
             {'__name__': 'variar', 'CENA': cena, 'RAIZ': RAIZ})
    except Exception:
        # Com janela aberta, um erro deixaria o Blender parado: registra e fecha.
        traceback.print_exc()
        sys.stdout.flush()
else:
    pasta = RAIZ/'exports/revisao_moradores_v4'
    pasta.mkdir(parents=True, exist_ok=True)
    cena.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else cena.render.engine
    cena.render.filepath = str(pasta/'dupla_base.png')
    with bpy.context.temp_override(scene=cena):
        bpy.ops.render.render(write_still=True, scene=cena.name)
print('REVISAO4 PRONTA', modo)
bpy.ops.wm.quit_blender()
