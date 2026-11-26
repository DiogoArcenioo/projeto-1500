"""Centro de caça A1. Somente arte para aprovação; não implementa regras."""
from pathlib import Path
import json
import math
import bpy
from mathutils import Vector

RAIZ=Path(r"C:/Users/PC/Documents/ChatGPT/1500")
arquivo=RAIZ/"tools/modelar_agricultura_pesca.py"
fonte=arquivo.read_text(encoding="utf-8").rsplit("\nproduzir()",1)[0]
fonte=fonte.replace("return 2.25+.31*(y-cy)","return 2.65+.24*(y-cy)")
ns={"__file__":str(arquivo),"__name__":"helpers_caca"}
exec(compile(fonte,str(arquivo),"exec"),ns)
ns["iniciar"]("CentroCacaA1")
viga=ns["viga"]
tubo=ns["tubo"]
face=ns["face"]
amarra=ns["amarracao"]
ns["abrigo"](0,0,3.5,2.6)
# Apoios visíveis reforçam a estrutura aberta sem fechar os vãos.
for x in [-1.505,1.505]:
    for y in [-1.014,1.014]:
        viga((x,y,1.95),(x*.70,y,2.65+.24*y),.052)
# Bancada baixa à esquerda, com ripas e apoios tocando o chão.
for x in [-1.30,-.48]:
    for y in [.12,.86]:
        viga((x,y,0),(x,y,.78),.065)
for y in [.12,.86]:
    viga((-1.42,y,.72),(-.36,y,.72),.055)
for i in range(7):
    x=-1.40+i*.16
    viga((x,-.03,.79),(x,1.0,.79),.073)
for x in [-1.20,-.63]:
    ns["cesto"](x,.50,.865,.20,.34 if x<-.8 else .25)
ns["cesto"](-1.16,-.12,0,.28,.40)
# Cavalete aberto ao fundo, separado da bancada; função legível na câmera do jogo.
for x in [-.12,1.40]:
    viga((x,.42,0),(x,.42,1.60),.053)
    amarra((x,.42,1.12),(0,0,1),.057,4,.13)
viga((-.25,.42,1.12),(1.57,.42,1.12),.052)
viga((-.18,.42,.18),(1.51,.42,.18),.042)
# Dois arcos sem decoração ritual, com cordas tensionadas e empunhaduras.
for x in [.03,.46]:
    pts=[Vector((x+.24*math.sin(math.pi*i/20),.25,.14+1.65*i/20)) for i in range(21)]
    tubo("MadeiraClara",pts,[.013+.017*math.sin(math.pi*i/20) for i in range(21)],7)
    tubo("Fibras",[pts[0],pts[-1]],[.008,.008],5)
    amarra((x+.24,.25,.965),(0,0,1),.031,6,.16)
# Três lanças com ponta de madeira; não há peças metálicas.
for i,x in enumerate([.93,1.18,1.43]):
    h=1.88+i*.055
    tubo("Madeira",[(x,.20,0),(x-.025,.23,h-.20)],[.022,.017],7)
    tubo("CorteMadeira",[(x-.025,.23,h-.25),(x-.025,.23,h-.06),(x-.025,.23,h)],[.032,.021,.001],5)
    amarra((x-.025,.23,h-.23),(0,0,1),.027,3,.085)
# Recipiente trançado para flechas e projéteis agrupados.
ns["cesto"](.27,-.42,0,.155,.48)
for i in range(9):
    a=i*math.tau/9
    x=.27+.10*math.cos(a)
    y=-.42+.10*math.sin(a)
    h=.90+.075*(i%3)
    tubo("MadeiraClara",[(x,y,.04),(x,y,h)],[.008,.007],5)
    for lado in [-1,1]:
        face("FolhaSeca",[(x,y,h-.17),(x+lado*.045,y,h-.13),(x+lado*.043,y,h-.04),(x,y,h)])
# Pequenos cordões presos à trave, sem objetos suspensos sem amarração.
for x in [-1.27,-.56]:
    tubo("Fibras",[(x,.99,1.12),(x,.99,.92)],[.012,.012],5)
ns["RAIZ_OBJ"]["referencia"]="art/references/etapa_9/centro_caca_opcoes.png — A"
ns["RAIZ_OBJ"]["frente"]="Blender -Y / Godot +Z"
ns["RAIZ_OBJ"]["aprovacao"]="A1 no chat; modelo aguarda avaliação Godot"
cena=ns["fechar"]("centro_caca_nivel_1")
objetos=[o for o in cena.objects if o.type=="MESH"]
vs=[o.matrix_world@v.co for o in objetos for v in o.data.vertices]
limites=[[min(v[i] for v in vs),max(v[i] for v in vs)] for i in range(3)]
dados={"modelo":"centro_caca_nivel_1","bounds_blender":limites,"malhas":len(objetos),
       "faces":sum(len(o.data.polygons) for o in objetos),
       "triangulos":sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objetos),
       "frente":"-Y Blender / +Z Godot","referencia":"A1",
       "estado":"Aprovado A; aguardando B no Godot"}
(RAIZ/"art/references/etapa_9/medidas_centro.json").write_text(json.dumps(dados,indent=2),encoding="utf-8")
# Vista de trabalho legível no Blender, sem alterar as cenas anteriores.
cena.camera.location=(7,-9,6)
cena.camera.rotation_euler=(Vector((0,0,1.2))-cena.camera.location).to_track_quat("-Z","Y").to_euler()
cena.camera.data.ortho_scale=5.8
print(json.dumps(dados))
