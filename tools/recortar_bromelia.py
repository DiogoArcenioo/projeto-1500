"""Reutiliza a bromélia da clareira no setor de coleta. Executar com clareira_1500.blend."""
import bpy
from pathlib import Path
from mathutils import Vector
from math import hypot
root=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='DESELECT')
plant=[]
for name in ['Bromelias','Flores_Coral','Flores_Ouro']:
    obj=next(o for o in bpy.context.scene.objects if o.name.startswith(name))
    mesh=obj.data
    faces=[list(f.vertices) for f in mesh.polygons if all(hypot(mesh.vertices[i].co.x+8,mesh.vertices[i].co.y+6)<1.45 for i in f.vertices)]
    indices=sorted({i for f in faces for i in f})
    lookup={v:i for i,v in enumerate(indices)}
    part=bpy.data.meshes.new(name)
    part.from_pydata([mesh.vertices[i].co+Vector((8,6,-.09)) for i in indices],[],[[lookup[i] for i in f] for f in faces])
    part.materials.append(mesh.materials[0]);part.update()
    leaf=bpy.data.objects.new(name,part);bpy.context.scene.collection.objects.link(leaf)
    leaf.select_set(True);plant.append(leaf)
assert all(len(o.data.polygons)>0 for o in plant)
bpy.ops.export_scene.gltf(filepath=str(root/'assets/models/bromelia_clareira.glb'),use_selection=True,export_animations=False)
