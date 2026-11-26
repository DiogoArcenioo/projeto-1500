"""Anima e exporta a onça B para inspeção no Godot."""
import math
from pathlib import Path

import bpy
from mathutils import Euler, Vector

RAIZ = Path(__file__).resolve().parents[1]
fonte = RAIZ/'tools/animar_capivara.py'
lib = {'__file__':str(fonte), '__name__':'animais'}
exec(compile(fonte.read_text(encoding='utf-8'),str(fonte),'exec'),lib)
TAU = math.tau
suave, marcha, PATAS = lib['suave'], lib['marcha'], lib['PATAS']


class Onca(lib['Capivara']):
    def aplicar(self, pose):
        super().aplicar(pose)
        onda = pose.get('cauda', 0.0)
        for i in range(5):
            osso = self.rig.pose.bones[f'cauda_{i}']
            osso.rotation_quaternion = Euler((onda*.05*i, 0, onda*(.12+.05*i)), 'XYZ').to_quaternion()


def repouso(t):
    respira = math.sin(TAU*3*t)
    atenta = math.sin(TAU*t) * .07
    return {'tronco':Vector((.009*respira,0,0)), 'pescoco':Vector((.014*respira,0,atenta)),
            'cabeca':Vector((-.018*respira,0,atenta*.5)), 'cauda':math.sin(TAU*t),
            'patas':{p:(Vector(),0.0) for p in PATAS}}


def locomocao(rapido):
    if rapido:
        fases = {('tras','E'):0, ('tras','D'):.15, ('frente','E'):.46, ('frente','D'):.62}
        patas = marcha(fases,.46,.46,.16)
    else:
        fases = {('tras','E'):0, ('frente','E'):.24, ('tras','D'):.50, ('frente','D'):.74}
        patas = marcha(fases,.68,.31,.077)

    def pose(t):
        onda = math.sin(TAU*t)
        if rapido:
            return {'raiz':Vector((0,0,.064*(1-math.cos(TAU*t))-.025)),
                    'giro':Vector((.055*onda,0,0)), 'tronco':Vector((.10*onda,0,0)),
                    'pescoco':Vector((-.11*onda,0,0)), 'cabeca':Vector((.032*onda,0,0)),
                    'cauda':.7*onda, 'patas':patas(t)}
        return {'raiz':Vector((.010*onda,0,-.008+.01*math.cos(2*TAU*t))),
                'giro':Vector((.013*onda,.018*onda,0)), 'tronco':Vector((.014*onda,0,.025*onda)),
                'pescoco':Vector((-.027*onda,0,0)), 'cabeca':Vector((.018*onda,0,-.022*onda)),
                'cauda':.6*onda, 'patas':patas(t)}
    return pose


def batalha(nome):
    def pose(t):
        p = {'patas':{m:(Vector(),0.0) for m in PATAS}}
        if nome in ('investida','errar_ataque'):
            baixa = suave(0,.22,t)*(1-suave(.27,.42,t))
            salta = suave(.24,.43,t)*(1-suave(.57,.94,t))
            arco = math.sin(math.pi*suave(.27,.65,t))
            erro = .20 if nome=='errar_ataque' else 0.0
            p.update(raiz=Vector((erro*salta,.06*baixa-.29*salta,.16*arco-.055*baixa)),
                     giro=Vector((.12*salta-.10*baixa,0,erro*salta)),
                     tronco=Vector((.16*baixa-.19*salta,0,0)), pescoco=Vector((.25*baixa-.16*salta,0,0)),
                     cabeca=Vector((.13*baixa-.12*salta,0,erro*salta)), cauda=-.85*salta)
            for i,m in enumerate(PATAS):
                atraso = .018*(i%2)
                salto = suave(.25+atraso,.45+atraso,t)*(1-suave(.59+atraso,.92,t))
                p['patas'][m] = (Vector((erro*salto,-(.34 if m[0]=='frente' else .23)*salto,.23*arco)),.34*arco)
        elif nome=='receber_golpe':
            onda = suave(0,.14,t)*(1-suave(.25,.90,t))
            p.update(raiz=Vector((.045*onda,.115*onda,-.048*onda)), giro=Vector((-.13*onda,.06*onda,0)),
                     pescoco=Vector((-.18*onda,0,-.11*onda)), cabeca=Vector((-.08*onda,0,.15*onda)),cauda=onda)
        else:
            onda = suave(.02,.27,t)*(1-suave(.52,.92,t))
            salto = math.sin(math.pi*suave(.02,.82,t))
            p.update(raiz=Vector((.24*onda,.04*onda,.085*salto)),giro=Vector((0,-.14*onda,.12*onda)),
                     cabeca=Vector((0,0,-.15*onda)),cauda=-onda)
            for m in PATAS:
                p['patas'][m]=(Vector((.22*onda,.023*onda,.12*salto)),0.0)
        return p
    return pose


def produzir():
    anterior = bpy.context.window.scene
    try:
        onca = Onca('onca_pintada')
        c = onca.cena
        c.name = 'Onca_Pintada_Animada'
        for obj in c.objects:
            for mod in obj.modifiers:
                if mod.type=='ARMATURE': mod.show_viewport=False
        clipes = {'parada':(96,repouso), 'andar':(32,locomocao(False)), 'correr':(20,locomocao(True))}
        for nome,(quadros,fn) in clipes.items():
            onca.clipe(nome,quadros,fn)
        golpes = ['investida','errar_ataque','receber_golpe','esquivar']
        for nome in golpes:
            onca.clipe(nome,28,batalha(nome),laco=False)
        for obj in c.objects:
            for mod in obj.modifiers:
                if mod.type=='ARMATURE': mod.show_viewport=True
        lib['exportar'](onca, RAIZ/'assets/models/animais/onca_pintada.glb', set(clipes)|set(golpes))
        c.frame_end = 97
        lib['salvar_fonte'](onca)
        print('ONÇA — clipes:',list(clipes)+golpes)
    finally:
        bpy.context.window.scene = anterior


if __name__ == '__main__':
    produzir()
