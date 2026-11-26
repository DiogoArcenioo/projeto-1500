"""Centro de cura nível 1 (etapa 13).

Uso (com janela; fecha o Blender ao terminar):
  blender --factory-startup --python tools/modelar_centro_cura.py
Mesma linguagem do centro de caça e da pesca (madeira, palha e fibras de
tools/modelar_agricultura_pesca.py). Abrigo aberto com duas redes de dormir para
os pacientes, jirau com feixes de ervas secando e cestos de plantas. Objetos de
cuidado genéricos, sem rituais ou objetos sagrados atribuídos a povos reais.
Grava assets/models/centro_cura_nivel_1.glb e art/blender/centro_cura_nivel_1.blend.
"""
from pathlib import Path
import math, os, sys, traceback
import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[1]
arquivo = RAIZ/"tools/modelar_agricultura_pesca.py"
fonte = arquivo.read_text(encoding="utf-8").rsplit("\nproduzir()", 1)[0]
ns = {"__file__": str(arquivo), "__name__": "helpers_cura"}
exec(compile(fonte, str(arquivo), "exec"), ns)


def rede_dormir(cx, cy, comprimento=2.0, largura=.62):
    viga, tubo, face, amarra = ns["viga"], ns["tubo"], ns["face"], ns["amarracao"]
    meio = comprimento/2+.18
    for x in (cx-meio, cx+meio):
        viga((x, cy, 0), (x, cy, 1.55), .058)
        amarra((x, cy, 1.18), (0, 0, 1), .062, 4, .12)

    def p(u, v):
        larg = largura*(.18+.82*math.sin(math.pi*u)**.6)
        return Vector((cx+(u-.5)*comprimento, cy+v*larg/2, 1.12-.46*math.sin(math.pi*u)-.07*(1-v*v)*math.sin(math.pi*u)))
    nu, nv = 16, 6
    for i in range(nu):
        for j in range(nv):
            u0, u1 = i/nu, (i+1)/nu
            v0, v1 = -1+2*j/nv, -1+2*(j+1)/nv
            q = [p(u0, v0), p(u1, v0), p(u1, v1), p(u0, v1)]
            mat = "FibraClara" if (i+j) % 2 == 0 else "FibraMel"
            face(mat, q)
            face(mat, q[::-1])
    # Punhos: as cordas das pontas até os esteios.
    for u, x in ((0, cx-meio), (1, cx+meio)):
        for v in (-1, 0, 1):
            tubo("Fibras", [p(u, v), Vector((x, cy, 1.18))], [.006, .006], 4)
    # Bordas reforçadas.
    for v in (-1, 1):
        pts = [p(i/24, v) for i in range(25)]
        tubo("Fibras", pts, [.012]*25, 4)


def feixe_ervas(x, y, z, comprimento=.34, cor="FolhaOliva"):
    """Feixe de folhas amarrado, pendurado de cabeça para baixo para secar."""
    lamina, tubo = ns["lamina"], ns["tubo"]
    tubo("Fibras", [(x, y, z+.18), (x, y, z)], [.004, .004], 4)
    for k in range(7):
        a = k*math.tau/7
        lamina(Vector((x+.012*math.cos(a), y+.012*math.sin(a), z)), a, .06, .045, -comprimento, cor)


def produzir():
    ns["iniciar"]("CentroCuraC1")
    viga, tubo, amarra, cesto, lamina, pedra = ns["viga"], ns["tubo"], ns["amarracao"], ns["cesto"], ns["lamina"], ns["pedra"]
    ns["abrigo"](0, .25, 3.4, 2.3)
    rede_dormir(0, .72)
    rede_dormir(0, -.2)
    # Jirau de secagem à direita: duas forquilhas e travessas com feixes de ervas.
    for y in (-1.55, -.75):
        viga((1.95, y, 0), (1.95, y, 1.45), .05)
        amarra((1.95, y, 1.3), (0, 0, 1), .052, 3, .1)
    for z in (1.32, 1.02):
        viga((1.95, -1.7, z), (1.95, -.6, z), .035)
        for k in range(4):
            y = -1.58+k*.27
            feixe_ervas(1.95, y, z-.02, .26 if z < 1.2 else .3, ["FolhaOliva", "FolhaSeca", "FolhaMusgo", "FolhaVerde"][(k+int(z*10)) % 4])
    # Banco baixo de tronco com cestos de plantas colhidas, à esquerda na frente.
    viga((-1.95, -1.45, .22), (-1.0, -1.45, .22), .13)
    for x in (-1.85, -1.1):
        viga((x, -1.45, 0), (x, -1.45, .2), .06)
    for i, (x, r, h) in enumerate(((-1.75, .17, .24), (-1.38, .14, .2), (-1.05, .15, .22))):
        cesto(x, -1.45, .34, r, h)
        for k in range(5):
            a = k*math.tau/5+i
            lamina(Vector((x+.06*math.cos(a), -1.45+.06*math.sin(a), .34+h*.8)), a, .22, .07, .9, ["FolhaJade", "FolhaLima", "FolhaVerde"][(i+k) % 3])
    # Cesto grande no chão e pedras de apoio.
    cesto(-1.9, 1.35, 0, .26, .38)
    pedra(1.25, 1.55, .015, (.45, .32, .14))
    ns["RAIZ_OBJ"]["referencia"] = "Etapa 13 — centro de cura (abrigo, redes, jirau de ervas)"
    ns["RAIZ_OBJ"]["frente"] = "Blender -Y / Godot +Z"
    cena = ns["fechar"]("centro_cura_nivel_1")
    objetos = [o for o in cena.objects if o.type == "MESH"]
    vs = [o.matrix_world@v.co for o in objetos for v in o.data.vertices]
    print("CURA limites", [[round(min(v[i] for v in vs), 2), round(max(v[i] for v in vs), 2)] for i in range(3)])


if __name__ == "__main__" or True:
    try:
        produzir()
    except Exception:
        traceback.print_exc()
    sys.stdout.flush()
    os._exit(0)
