"""Revisão dos moradores: fonte Blender e renders; sem exportação para Godot.
Guia direto: moradores_recorte_aprovado.png. Versão anterior rejeitada no chat.
"""
import ast
import bpy
import math
from pathlib import Path
from mathutils import Vector

RAIZ = Path(r'C:\Users\PC\Documents\ChatGPT\1500')
# Reutiliza apenas utilitários de malha e rig, sem executar a produção anterior.
modulo = ast.parse((RAIZ/'tools/modelar_moradores.py').read_text(encoding='utf-8'))
modulo.body = [n for n in modulo.body if not isinstance(n, ast.Expr)]
util = {}
exec(compile(modulo, 'utilitarios_moradores', 'exec'), util)
Malha, material = util['Malha'], util['material']
NOME_CENA = '1500_Moradores_Revisao2'


def distancia_segmento(p,a,b):
    d=b-a
    t=max(0,min(1,(p-a).dot(d)/d.length_squared))
    return (p-(a+t*d)).length


def pesos_pele(p,rig,escala):
    p=p/escala
    x,y,z=p
    if z>1.49:
        return {'Cabeca':1.0}
    if z>1.42 and abs(x)<.09:
        t=max(0,min(1,(z-1.42)/.07))
        return {'Pescoco':1-t,'Cabeca':t}
    if abs(x)>.215 and z>.68:
        l='E' if x>0 else 'D'
        nomes=['Braco.'+l,'Antebraco.'+l,'Mao.'+l]
    elif z<.93:
        l='E' if x>0 else 'D'
        nomes=['Coxa.'+l,'Canela.'+l,'Pe.'+l]
        if z>.84:
            t=max(0,min(1,(z-.84)/.09))
            return {'Quadril':t,'Coxa.'+l:1-t}
    else:
        if z<1.08:
            t=max(0,min(1,(z-.98)/.1))
            return {'Quadril':1-t,'Coluna':t}
        t=max(0,min(1,(z-1.17)/.15))
        return {'Coluna':1-t,'Peito':t}
    ds=[]
    for nome in nomes:
        b=rig.data.bones[nome]
        ds.append((distancia_segmento(p,b.head_local/escala,b.tail_local/escala),nome))
    ds.sort()
    a,b=ds[:2]
    # Faixa estreita de mistura: evita que a mão puxe o cotovelo.
    t=max(0,min(.5,(.035-(b[0]-a[0]))/.07))
    return {a[1]:1-t,b[1]:t}


def unir_pele(m,nome,cena,rig,escala):
    dados=bpy.data.meshes.new(nome+'_PeleAnatomica')
    dados.from_pydata(m.v,[],m.f)
    dados.update()
    obj=bpy.data.objects.new(nome+'_Pele',dados)
    cena.collection.objects.link(obj)
    dados.materials.append(m.materiais[0])
    with bpy.context.temp_override(scene=cena,view_layer=cena.view_layers[0]):
        for o in list(bpy.context.selected_objects):
            o.select_set(False)
        obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        remesh=obj.modifiers.new('UniaoAnatomica','REMESH')
        remesh.mode='VOXEL'
        remesh.voxel_size=.0075*escala
        remesh.use_smooth_shade=False
        bpy.ops.object.modifier_apply(modifier=remesh.name)
        suavizar=obj.modifiers.new('TransicoesMusculares','SMOOTH')
        suavizar.factor=.68
        suavizar.iterations=7
        bpy.ops.object.modifier_apply(modifier=suavizar.name)
        reduzir=obj.modifiers.new('FacetasIntencionais','DECIMATE')
        reduzir.ratio=min(1,5200/max(1,len(obj.data.polygons)*2))
        bpy.ops.object.modifier_apply(modifier=reduzir.name)
    uv=obj.data.uv_layers.new(name='UVMap')
    for f in obj.data.polygons:
        alturas=[obj.data.vertices[i].co.z/escala for i in f.vertices]
        # Rosto e dedos não recebem a triangulação ruidosa dos músculos.
        f.use_smooth=min(alturas)>1.49 or max(alturas)<.12
        for loop in f.loop_indices:
            p=obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv=(p.x+.5,p.z/2)
    grupos={b.name:obj.vertex_groups.new(name=b.name) for b in rig.data.bones}
    for v in obj.data.vertices:
        for nome,peso in pesos_pele(v.co,rig,escala).items():
            if peso>0:
                grupos[nome].add([v.index],peso,'REPLACE')
    obj.parent=rig
    mod=obj.modifiers.new('Deformacao','ARMATURE')
    mod.object=rig
    return obj


def construir(nome,cena,feminino=False):
    escala=.95 if feminino else 1.0
    rig=util['criar_rig'](cena,nome,escala)
    mats=[material(nome+'_PeleV2','b67846' if feminino else 'bc7942'),
          material(nome+'_CabeloV2','24251f'),material(nome+'_TerracotaV2','af502e'),
          material(nome+'_FolhaV2','677532'),material(nome+'_FibraV2','c6a160'),
          material(nome+'_IrisV2','292219'),material(nome+'_EscleraV2','ded1b0'),
          material(nome+'_LabioV2','975a35'),material(nome+'_PeleEscuraV2','965a32'),
          material(nome+'_CabeloLuzV2','33352a'),material(nome+'_TerracotaLuzV2','bd6233')]
    m=Malha(mats,escala)
    next(n for n in mats[5].node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Roughness'].default_value=.28
    ombros=.219 if feminino else .252
    cintura=.128 if feminino else .155
    quadril=.191 if feminino else .173
    m.horizontal([(.84,0,.009,quadril*.82,.09),(.91,0,.009,quadril,.112),
        (.99,0,0,quadril*.93,.111),(1.065,0,.005,cintura,.097),
        (1.105,0,.006,.136 if feminino else .162,.101),
        (1.145,0,.006,.145 if feminino else .177,.107),
        (1.188,0,.004,.160 if feminino else .195,.112),
        (1.230,0,.003,.180 if feminino else .214,.115),
        (1.267,0,.002,.195 if feminino else .232,.126),
        (1.314,0,0,.206 if feminino else .245,.132),
        (1.365,0,.004,ombros,.106),(1.414,0,.008,.195 if feminino else .225,.089),
        (1.448,0,.007,.098,.061)],0,'Peito',20)
    m.horizontal([(1.405,0,.01,.065,.058),(1.48,0,.008,.060,.058),
                  (1.54,0,0,.065,.060)],0,'Pescoco',14)
    if not feminino:
        # Relevo contínuo, sem esferas anexadas para representar músculos.
        for i,(x,y,z) in enumerate(m.v):
            if y<-.01 and 1.03<z<1.43:
                frente=max(0,min(1,-y/.1))
                peitoral=.027*math.exp(-((abs(x)-.105)/.085)**2-((z-1.307)/.048)**2)
                esterno=.015*math.exp(-(x/.023)**2-((z-1.31)/.11)**2)
                abdomen=.010*math.cos((z-1.105)*math.pi/.043)*math.exp(-((z-1.16)/.115)**2-(x/.10)**2)
                m.v[i]=(x,y+frente*(-peitoral+esterno-abdomen),z)
    for s,l in [(1,'E'),(-1,'D')]:
        # Ombro, bíceps, cotovelo, antebraço e punho unidos numa superfície.
        braco=.86 if feminino else 1
        m.tubo([(s*.195,.004,1.40),(s*.255,.002,1.376),(s*.283,-.003,1.303),
                (s*.315,-.003,1.215),(s*.352,0,1.108),(s*.374,-.009,1.035),
                (s*.396,-.020,.967),(s*.412,-.023,.885)],
               [(r*braco,r*braco*.90) for r in [.060,.079,.074,.062,.046,.055,.046,.031]],0,'Braco.'+l,18)
        # Coxa e panturrilha assimétricas na profundidade, joelho e tornozelo.
        m.tubo([(s*.096,.012,.94),(s*.106,.015,.82),(s*.110,.005,.70),
                (s*.112,-.027,.536),(s*.112,-.022,.493),(s*.114,.020,.389),
                (s*.117,.024,.282),(s*.118,.006,.135)],
               [(.085,.092),(.101 if feminino else .098,.102),(.085,.092),
                (.063,.066),(.063,.063),(.070,.072),(.055,.061),(.037,.042)],0,'Coxa.'+l,18)
        m.horizontal([(.022,s*.118,-.065,.054,.115),(.065,s*.118,-.068,.055,.121),
                      (.105,s*.118,-.029,.044,.073),(.145,s*.118,.002,.039,.042)],0,'Pe.'+l,12)
        for i in range(4):
            x=s*.118+(i-1.5)*.023
            m.elipsoide((x,-.174,.044),(.013,.023 if i<2 else .018,.022),0,'Pe.'+l,8)
    # Cabeça com volumes de mandíbula, maçãs, nariz, sobrancelhas e queixo.
    m.horizontal([(1.505,0,-.023,.059,.065),(1.542,0,-.012,.091,.079),
        (1.585,0,-.003,.116,.098),(1.634,0,.002,.133,.108),
        (1.683,0,.008,.131,.111),(1.731,0,.012,.126,.110),
        (1.779,0,.014,.115,.103),(1.821,0,.016,.088,.077),
        (1.842,0,.016,.048,.047)],0,'Cabeca',24)
    for s in [-1,1]:
        m.elipsoide((s*.132,.004,1.643),(.022,.023,.041),0,'Cabeca',10)
    m.horizontal([(1.623,0,-.118,.020,.011),(1.635,0,-.132,.022,.022),
        (1.657,0,-.116,.016,.018),(1.693,0,-.101,.011,.011)],0,'Cabeca',12)
    pele=unir_pele(m,nome,cena,rig,escala)
    d=Malha(mats,escala)
    # Mãos com dedos separados, preservados da redução volumétrica do corpo.
    for s,l in [(1,'E'),(-1,'D')]:
        d.tubo([(s*.410,-.023,.890),(s*.422,-.027,.840),(s*.430,-.030,.800)],
               [(.032,.027),(.041,.025),(.036,.020)],0,'Mao.'+l,12)
        for i,comprimento in enumerate([.061,.074,.069,.052]):
            x=s*(.405+i*.019)
            d.tubo([(x,-.030,.812),(x+s*.004,-.033,.780),
                    (x+s*.003,-.044,.812-comprimento)],
                   [.0085,.0080,.0065],0,'Mao.'+l,7)
        d.tubo([(s*.394,-.031,.850),(s*.379,-.051,.823),(s*.378,-.059,.796),
                (s*.386,-.061,.785)],[.014,.012,.010,.008],0,'Mao.'+l,7)
    # Olhos em amêndoa acompanhando a curvatura do rosto, íris e pálpebras.
    def olho_y(x):
        return -.119+(abs(x)/.10)**2*.027
    for s in [-1,1]:
        x,z=s*.052,1.681
        contorno=[(-.023,-.001),(-.013,.008),(.007,.008),(.023,.001),(.012,-.006),(-.009,-.006)]
        d.face([(x+dx,olho_y(x+dx),z+dz) for dx,dz in contorno],6,'Cabeca')
        d.elipsoide((x+.002,olho_y(x)-.003,z+.001),(.010,.0035,.009),5,'Cabeca',12)
        d.elipsoide((x-.001,olho_y(x)-.006,z+.004),(.0018,.001,.0018),6,'Cabeca',6)
        d.tubo([(x-.023,olho_y(x-.023)-.001,z),
                (x-.012,olho_y(x-.012)-.002,z+.009),
                (x+.008,olho_y(x+.008)-.002,z+.010),
                (x+.023,olho_y(x+.023)-.001,z+.001)],
               [.0014,.002,.002,.0013],8,'Cabeca',5)
        d.face([(x-.026,olho_y(x-.026)+.001,1.712),(x-.019,olho_y(x-.019)-.003,1.721),
                (x+.020,olho_y(x+.020)-.003,1.718),(x+.027,olho_y(x+.027)+.001,1.711),
                (x+.008,olho_y(x+.008)-.004,1.714)],1,'Cabeca')
        d.elipsoide((s*.017,-.138,1.626),(.0045,.0015,.002),8,'Cabeca',8)
        d.elipsoide((s*.143,-.014,1.645),(.008,.004,.023),8,'Cabeca',8)
    # Lábios com forma e espessura, discreto sorriso sem linha de caneta.
    d.face([(-.031,-.103,1.587),(-.012,-.114,1.593),(0,-.117,1.590),
            (.012,-.114,1.593),(.031,-.103,1.587),(0,-.120,1.584)],7,'Cabeca')
    d.face([(-.029,-.105,1.586),(0,-.121,1.584),(.029,-.105,1.586),
            (.014,-.116,1.578),(-.014,-.116,1.578)],7,'Cabeca')
    d.tubo([(-.024,-.110,1.585),(0,-.122,1.584),(.024,-.110,1.585)],
           [.001,.0013,.001],8,'Cabeca',5)
    # Cabelo volumétrico: cúpula, repartição e mechas em cunhas fechadas.
    aneis=[]
    for j,(raio,zbase) in enumerate([(1,1.637),(1.035,1.755),(.82,1.827),(.34,1.866),(.05,1.875)]):
        anel=[]
        for i in range(16):
            a=i*math.tau/16
            frente=max(0,-math.sin(a))
            z=zbase+(frente*.12 if j==0 else .006*math.cos(a*2))
            anel.append((.139*raio*math.cos(a),.018+.122*raio*math.sin(a),z))
        aneis.append(anel)
    d.aneis(aneis,1,'Cabeca')
    # Mechas posteriores se afastam do pescoço e descansam atrás dos ombros.
    for i in range(7):
        a=.12+i*math.pi/7
        x=.122*math.cos(a)
        y=.017+.116*math.sin(a)
        fim=1.10+(i%3)*.035 if feminino else 1.49+(i%3)*.025
        abrir=1.34 if feminino else 1.14
        d.tubo([(x*.80,y*.75,1.80),(x,y,1.66),(x*abrir,y+.025,1.49),
                (x*abrir,y+.055,fim+.05),(x*1.02,y+.057,fim)],
               [(.041,.020),(.047,.027),(.048,.027),(.034,.020),(.006,.005)],
               9 if i%3==1 else 1,'Cabeca',6)
    # Franja em planos assimétricos: uma repartição, sem capacete em V.
    d.face([(.035,-.098,1.850),(-.025,-.132,1.829),(-.095,-.125,1.775),
            (-.138,-.057,1.701),(-.086,-.083,1.751),(-.008,-.104,1.805)],1,'Cabeca')
    d.face([(.035,-.098,1.850),(.096,-.098,1.814),(.137,-.041,1.729),
            (.109,-.091,1.771)],1,'Cabeca')
    for s in [-1,1]:
        d.tubo([(s*.128,-.025,1.762),(s*.146,-.019,1.664),(s*.151,.017,1.56)],
               [(.027,.022),(.025,.021),(.008,.008)],1,'Cabeca',6)
    # Cobertura de cintura ajustada ao quadril e painéis sobrepostos com dobras.
    # Costas e laterais; a frente é fechada pelos painéis diagonais, sem saia-caixa.
    traseira=[]
    for z,rx,ry in [(.966,quadril+.012,.126),(.886,quadril+.024,.137),(.755,quadril+.021,.143)]:
        traseira.append([(rx*math.cos(i*math.pi/12),.007+ry*math.sin(i*math.pi/12),
                          z+(.025*math.sin(i*.9) if z<.8 else 0)) for i in range(13)])
    d.aneis(traseira,2,'Quadril',False)
    def pano(xs,topos,fundos,mat,prof):
        linhas=[]
        for t in [0,.30,.66,1]:
            linha=[]
            for i,x in enumerate(xs):
                y=prof*math.sqrt(max(.02,1-(x/(quadril+.032))**2))+.006*math.cos(i*math.pi)
                z=topos[i]*(1-t)+fundos[i]*t
                linha.append((x,y-.012*t,z))
            linhas.append(linha)
        for j in range(3):
            for i in range(len(xs)-1):
                d.face([linhas[j][i],linhas[j][i+1],linhas[j+1][i+1],linhas[j+1][i]],mat,'Quadril')
    pano([-.218,-.158,-.09,-.021,.045],[.958,.960,.960,.960,.958],[.728,.768,.800,.835,.870],3,-.139)
    pano([-.062,-.001,.067,.132,.210],[.960,.963,.963,.960,.953],[.684,.635,.685,.744,.800],2,-.148)
    # Faixa diagonal superior e dobra iluminada no painel maior.
    d.face([(-.205,-.112,.957),(.210,-.115,.930),(.204,-.122,.901),(-.202,-.123,.929)],10,'Quadril')
    d.face([(.059,-.159,.940),(.092,-.159,.938),(.087,-.174,.694),(.066,-.172,.679)],10,'Quadril')
    for z in [.954,.968]:
        pts=[((quadril+.017)*math.cos(i*math.tau/48),.136*math.sin(i*math.tau/48),z) for i in range(49)]
        d.tubo(pts,[.0065]*len(pts),4,'Quadril',6)
    d.elipsoide((.005,-.148,.961),(.022,.014,.021),4,'Quadril',10)
    for s in [-1,1]:
        d.tubo([(.005,-.153,.955),(.005+s*.020,-.167,.890),(.005+s*.016,-.171,.817)],
               [.007,.006,.005],4,'Quadril',6)
    if feminino:
        # Faixa acompanha o tórax, com borda e uma quebra de plano central.
        d.horizontal([(1.237,0,-.007,.184,.127),(1.275,0,-.007,.204,.137),
                      (1.322,0,-.004,.217,.132),(1.361,0,-.001,.215,.117)],3,'Peito',20)
    detalhes=d.objeto(nome+'_CabeloRostoRoupa',cena,rig)
    rig['referencia']='art/references/etapa_4/moradores_recorte_aprovado.png'
    rig['estado']='Revisão 2 — somente Blender; aprovação antes de exportar'
    rig['limite_historico']='Proposta artística; roupa sem autenticação histórica'
    util['animar'](cena,rig)
    return rig,pele,detalhes


def produzir():
    anterior=bpy.data.scenes.get(NOME_CENA)
    if anterior:
        for obj in list(anterior.objects):
            bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.scenes.remove(anterior)
    cena=bpy.data.scenes.new(NOME_CENA)
    bpy.context.window.scene=cena
    cena.unit_settings.system='METRIC'
    cena.render.fps=24
    cena.frame_end=137
    pares=[]
    for nome,f in [('Morador_Revisao2',False),('Moradora_Revisao2',True)]:
        objetos=construir(nome,cena,f)
        pares.append(objetos)
    pares[0][0].location.x=-.56
    pares[1][0].location.x=.56
    cena.frame_set(1)
    # Palco neutro para comparar anatomia, roupa e rosto sem o ambiente ocultá-los.
    mundo=bpy.data.worlds.new('MoradoresV2_Mundo')
    mundo.use_nodes=True
    fundo=next(n for n in mundo.node_tree.nodes if n.type=='BACKGROUND')
    fundo.inputs[0].default_value=(.75,.72,.66,1)
    fundo.inputs[1].default_value=.33
    cena.world=mundo
    for nome,pos,energia,tamanho in [('Principal',(-3.0,-4.5,6),650,2.2),('Preenchimento',(4,-2,3.5),100,4),('Recorte',(1.0,3.0,4.0),280,3)]:
        dado=bpy.data.lights.new('V2_'+nome,'AREA')
        dado.energy=energia
        dado.shape='DISK'
        dado.size=tamanho
        o=bpy.data.objects.new('V2_'+nome,dado)
        cena.collection.objects.link(o)
        o.location=pos
        o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
    # Piso e cenário de revisão, nunca parte dos personagens.
    piso_dados=bpy.data.meshes.new('V2_Piso')
    piso_dados.from_pydata([(-200,-200,-.003),(200,-200,-.003),(200,200,-.003),(-200,200,-.003)],[],[(0,1,2,3)])
    piso=bpy.data.objects.new('V2_Piso',piso_dados)
    cena.collection.objects.link(piso)
    piso.data.materials.append(material('V2_Fundo','e4c8a1'))
    cd=bpy.data.cameras.new('V2_Camera')
    camera=bpy.data.objects.new('V2_Camera',cd)
    cena.collection.objects.link(camera)
    camera.location=(2.7,-7.6,2.85)
    camera.rotation_euler=(Vector((0,0,.96))-camera.location).to_track_quat('-Z','Y').to_euler()
    cd.type='ORTHO'
    cd.ortho_scale=2.95
    cena.camera=camera
    cena.render.resolution_x=1400
    cena.render.resolution_y=1000
    cena.render.resolution_percentage=100
    cena.render.image_settings.file_format='PNG'
    cena.view_settings.view_transform='AgX'
    cena.view_settings.look='AgX - Medium High Contrast'
    # O motor instalado já usa EEVEE; não altera a configuração global do Blender.
    if hasattr(cena,'eevee'):
        cena.eevee.taa_render_samples=64
    destino=RAIZ/'art/blender/moradores_1500_v2.blend'
    bpy.data.libraries.write(str(destino),{cena},fake_user=True,compress=True)
    for rig,pele,detalhes in pares:
        print(rig.name,'pele',len(pele.data.polygons),'faces; detalhes',len(detalhes.data.polygons),'faces')
    print('Fonte Blender:',destino,'— NÃO exportado para Godot')


produzir()
