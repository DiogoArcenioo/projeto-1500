"""Revisão com base anatômica CC0 do Blender Studio, adaptada à referência.
Somente Blender: não contém exportador GLB nem alteração de cenas Godot.
"""
import ast
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

RAIZ=Path(r'C:\Users\PC\Documents\ChatGPT\1500')
modulo=ast.parse((RAIZ/'tools/modelar_moradores_v2.py').read_text(encoding='utf-8'))
modulo.body=[n for n in modulo.body if not (isinstance(n,ast.Expr) and isinstance(n.value,ast.Call)
             and isinstance(n.value.func,ast.Name) and n.value.func.id=='produzir')]
v2={}
exec(compile(modulo,'utilitarios_v2','exec'),v2)
criar_anterior=v2['construir']
Malha=v2['Malha']


def construir(nome,cena,feminino=False):
    rig,rejeitado,detalhes=criar_anterior(nome,cena,feminino)
    bpy.data.objects.remove(rejeitado,do_unlink=True)
    # Conserva apenas cabelo e roupa; rosto, mãos e anatomia são reconstruídos.
    bm=bmesh.new()
    bm.from_mesh(detalhes.data)
    apagar=[]
    escala=.95 if feminino else 1.0
    for f in bm.faces:
        z=[v.co.z/escala for v in f.verts]
        sobrancelha=f.material_index==1 and min(z)>1.70 and max(z)<1.735
        if f.material_index in [0,5,6,7,8] or sobrancelha:
            apagar.append(f)
    bmesh.ops.delete(bm,geom=apagar,context='FACES')
    bm.to_mesh(detalhes.data)
    bm.free()
    arquivo=str(RAIZ/'art/blender/bases_cc0/human_base_meshes_bundle.blend')
    prefixo='GEO-body_female_stylized' if feminino else 'GEO-body_male_stylized'
    with bpy.data.libraries.load(arquivo,link=False) as (fonte,destino):
        destino.objects=[prefixo,prefixo+'.eye.L',prefixo+'.eye.R']
    corpo,esq,dir=destino.objects
    for o in destino.objects:
        cena.collection.objects.link(o)
    bpy.context.view_layer.update()
    pontos=[corpo.matrix_world@Vector(p) for p in corpo.bound_box]
    cx=(min(p.x for p in pontos)+max(p.x for p in pontos))/2
    zmin=min(p.z for p in pontos)
    altura=max(p.z for p in pontos)-zmin
    fator=(1.74 if feminino else 1.83)/altura
    olhos=[]
    for o in destino.objects:
        matriz=o.matrix_world.copy()
        o.data=o.data.copy()
        for v in o.data.vertices:
            p=matriz@v.co
            v.co=((p.x-cx)*fator,p.y*fator,(p.z-zmin)*fator)
        o.parent=rig
        o.matrix_parent_inverse=Matrix.Identity(4)
        o.matrix_basis=Matrix.Identity(4)
        o.data.materials.clear()
        o.data.materials.append(detalhes.data.materials[0 if o==corpo else 6])
        for f in o.data.polygons:
            f.material_index=0
        if o!=corpo:
            ps=[v.co for v in o.data.vertices]
            centro=Vector(tuple((min(p[i] for p in ps)+max(p[i] for p in ps))/2 for i in range(3)))
            olhos.append(centro)
            for f in o.data.polygons:
                f.use_smooth=True
    corpo.name=nome+'_Anatomia'
    # Preserva detalhe de mãos/face e usa facetas maiores no tronco e pernas.
    with bpy.context.temp_override(scene=cena,view_layer=cena.view_layers[0]):
        for o in list(bpy.context.selected_objects):
            o.select_set(False)
        corpo.select_set(True)
        bpy.context.view_layer.objects.active=corpo
        reducao=corpo.modifiers.new('EstilizacaoLowPoly','DECIMATE')
        reducao.ratio=.34
        bpy.ops.object.modifier_apply(modifier=reducao.name)
    for f in corpo.data.polygons:
        alturas=[corpo.data.vertices[i].co.z for i in f.vertices]
        f.use_smooth=min(alturas)>1.48*escala
    bpy.context.view_layer.update()
    arvore=BVHTree.FromObject(corpo,bpy.context.evaluated_depsgraph_get())
    # A roupa acompanha a anatomia, sem atravessar cintura ou tórax.
    for v in detalhes.data.vertices:
        if v.co.z>1.42*escala:
            # Cabelo: afasta somente pontos que ficaram dentro do novo crânio.
            proximo,normal,_,dist=arvore.find_nearest(v.co)
            if proximo is not None and (v.co-proximo).dot(normal)<0 and dist<.045:
                v.co=proximo+normal*.009
            continue
        radial=Vector((v.co.x,v.co.y,0))
        if radial.length<.02:
            continue
        direcao=radial.normalized()
        origem=direcao*1.5+Vector((0,0,v.co.z))
        ponto,_,_,_=arvore.ray_cast(origem,-direcao,2.0)
        if ponto is not None:
            raio=Vector((ponto.x,ponto.y,0)).length+.008
            if raio>radial.length:
                v.co.x=direcao.x*raio
                v.co.y=direcao.y*raio
    # Íris castanhas e sobrancelhas assentadas sobre as pálpebras reais.
    d=Malha(list(detalhes.data.materials),1)
    for olho in olhos:
        x,y,z=olho
        raio=.038*fator
        frente=y-raio+.001
        d.elipsoide((x+.003,frente-.001,z),(.013,.0035,.013),5,'Cabeca',16)
        d.elipsoide((x-.001,frente-.004,z+.004),(.002,.001,.002),6,'Cabeca',8)
        pontos=[]
        for dx,dz in [(-.029,.036),(-.012,.042),(.012,.042),(.029,.037)]:
            p,_,_,_=arvore.ray_cast(Vector((x+dx,-1,z+dz)),Vector((0,1,0)),2)
            if p is not None:
                pontos.append(p+Vector((0,-.003,0)))
        if len(pontos)==4:
            d.tubo(pontos,[.003,.004,.0038,.0015],1,'Cabeca',6)
    d.objeto(nome+'_Olhar',cena,rig)
    rig['origem_anatomia']='Blender Studio Human Base Meshes v1.4.1; Julien Kaspar; CC0'
    rig['referencia']='art/references/etapa_4/moradores_recorte_aprovado.png'
    rig['estado']='Revisão 3 — Blender apenas; rig/animação serão reajustados após aceite da forma'
    # A revisão é de forma: a anatomia nova permanece em pose neutra.
    rig.animation_data_clear()
    for b in rig.pose.bones:
        b.rotation_euler=(0,0,0)
        b.location=(0,0,0)
    return rig,corpo,detalhes


v2['construir']=construir
v2['NOME_CENA']='1500_Moradores_Revisao3'
# A função de palco escreve apenas fonte Blender. Redireciona a revisão sem sobrescrever a V2.
fonte=ast.parse((RAIZ/'tools/modelar_moradores_v2.py').read_text(encoding='utf-8').replace('moradores_1500_v2.blend','moradores_1500_v3.blend'))
funcao=next(n for n in fonte.body if isinstance(n,ast.FunctionDef) and n.name=='produzir')
exec(compile(ast.Module(body=[funcao],type_ignores=[]),'palco_revisao3','exec'),v2)
v2['produzir']()
