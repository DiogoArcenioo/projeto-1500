extends RefCounted
## Recortes de malhas aprovadas; não modifica os recursos originais.
static func recortar(original: MeshInstance3D,area: AABB,manter_dentro: bool,origem:=Vector3.ZERO) -> ArrayMesh:
	var malha:=ArrayMesh.new()
	for s in range(original.mesh.get_surface_count()):
		var arrays:=original.mesh.surface_get_arrays(s).duplicate(true)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in range(vertices.size()): indices.append(i)
		var aceitos:=PackedInt32Array()
		for i in range(0,indices.size(),3):
			var a:=vertices[indices[i]]
			var b:=vertices[indices[i+1]]
			var c:=vertices[indices[i+2]]
			var dentro:=area.has_point(a) and area.has_point(b) and area.has_point(c)
			var toca:=area.has_point(a) or area.has_point(b) or area.has_point(c)
			if (manter_dentro and dentro) or (not manter_dentro and not toca):
				aceitos.append_array(PackedInt32Array([indices[i],indices[i+1],indices[i+2]]))
		if aceitos.is_empty(): continue
		for i in range(vertices.size()): vertices[i]-=origem
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_INDEX]=aceitos
		malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		malha.surface_set_material(malha.get_surface_count()-1,original.get_active_material(s))
	return malha
