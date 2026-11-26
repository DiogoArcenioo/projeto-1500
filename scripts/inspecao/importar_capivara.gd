@tool
extends EditorScenePostImport
## Preserva a pintura por face do Blender no material importado.
func _post_import(cena: Node) -> Object:
	for m: MeshInstance3D in cena.find_children("*","MeshInstance3D",true,false):
		for i in range(m.mesh.get_surface_count()):
			var arrays:=m.mesh.surface_get_arrays(i)
			var material:=m.mesh.surface_get_material(i) as StandardMaterial3D
			if material and arrays[Mesh.ARRAY_COLOR]!=null and not arrays[Mesh.ARRAY_COLOR].is_empty():
				material.vertex_color_use_as_albedo=true
	return cena
