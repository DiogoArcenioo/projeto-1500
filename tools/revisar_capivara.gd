extends SceneTree
var cena
var total:=0
var falhas:=0
func _initialize() -> void: executar.call_deferred()
func ok(v: bool,t: String) -> void:
	total+=1
	if not v:
		falhas+=1
		push_error(t)
func esperar() -> void:
	for i in range(32): await process_frame
func captura(nome: String) -> void:
	await esperar()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://exports/revisao_capivara")
	ok(root.get_texture().get_image().save_png("res://exports/revisao_capivara/"+nome+".png")==OK,"Captura "+nome)
func executar() -> void:
	cena=load("res://scenes/inspecao/capivara_etapa_10.tscn").instantiate()
	root.add_child(cena)
	await esperar()
	var malhas: Array[Node]=cena.get_node("Capivara").find_children("*","MeshInstance3D",true,false)
	ok(malhas.size()==1,"Uma malha para o animal")
	var esqueletos: Array[Node]=cena.get_node("Capivara").find_children("*","Skeleton3D",true,false)
	ok(esqueletos.size()==1 and esqueletos[0].get_bone_count()==16,"Rig de 16 ossos")
	var tri:=0
	for m: MeshInstance3D in malhas:
		var limites: AABB=m.global_transform*m.get_aabb()
		ok(limites.size.x>.35 and limites.size.x<.65 and limites.size.z>.95 and limites.size.z<1.4,"Dimensões adultas da capivara")
		ok(absf(limites.position.y-cena.get_node("Capivara").position.y)<.025,"Patas no nível do solo")
		ok(m.mesh.get_surface_count()<=2,"No máximo duas superfícies")
		for i in range(m.mesh.get_surface_count()):
			var arrays:=m.mesh.surface_get_arrays(i)
			var material=m.mesh.surface_get_material(i)
			ok(material.vertex_color_use_as_albedo,"Cor do Blender habilitada na superfície "+str(i))
			tri+=arrays[Mesh.ARRAY_INDEX].size()/3
			ok(arrays[Mesh.ARRAY_VERTEX].size()>0,"Vértices importados")
			var pesos: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var normalizados:=true
			for j in range(0,pesos.size(),4):
				if absf(pesos[j]+pesos[j+1]+pesos[j+2]+pesos[j+3]-1)>.02: normalizados=false
			ok(not pesos.is_empty() and normalizados,"Pesos normalizados da superfície "+str(i))
	ok(tri<6000,"Até 6000 triângulos: "+str(tri))
	for nome in ["parada","andar","correr"]:
		var existe:=false
		if cena.animador:
			for a in cena.animador.get_animation_list():
				if str(a).contains(nome): existe=true
		ok(existe,"Animação "+nome)
		if existe:
			cena.animar(nome)
			cena.animador.advance(.2)
			var indice: int=esqueletos[0].find_bone("frente_E")
			if nome!="parada": ok(esqueletos[0].get_bone_pose_rotation(indice).angle_to(Quaternion.IDENTITY)>.01,"Pata dianteira se move em "+nome)
	if cena.animador: cena.animador.stop()
	esqueletos[0].reset_bone_poses()
	for vista in ["Frente","Lateral","Costas","Escala","Geral"]:
		cena.enquadrar(vista)
		await captura(vista.to_lower())
	cena.enquadrar("Frente")
	cena.animar("andar")
	await captura("caminhada")
	cena.animar("correr")
	await captura("corrida")
	cena.queue_free()
	await process_frame
	print("CAPIVARA: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)
