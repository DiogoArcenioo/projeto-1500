extends SceneTree
const PASTA:="res://exports/revisao_centro_caca/"
var cena
var total:=0
var falhas:=0
func _initialize() -> void: executar.call_deferred()
func ok(v: bool,m: String) -> void:
	total+=1
	if not v:
		falhas+=1
		push_error(m)
func captura(nome: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in range(45): await process_frame
	await RenderingServer.frame_post_draw
	ok(root.get_texture().get_image().save_png(PASTA+nome+".png")==OK,"Captura "+nome)
func executar() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA)
	ok(FileAccess.file_exists("res://art/blender/centro_caca_nivel_1.blend"),"Fonte Blender preservado")
	cena=load("res://scenes/inspecao/centro_caca_etapa_9.tscn").instantiate()
	root.add_child(cena)
	await process_frame
	var modelo: Node3D=cena.get_node("CentroCaca")
	var malhas: Array=modelo.find_children("*","MeshInstance3D",true,false)
	ok(malhas.size()==14,"Quatorze malhas do asset")
	ok(modelo.find_children("*","Camera3D",true,false).is_empty(),"Sem câmera exportada")
	ok(modelo.find_children("*","Light3D",true,false).is_empty(),"Sem iluminação embutida no asset")
	var caixa:=AABB()
	var primeira:=true
	var triangulos:=0
	for m: MeshInstance3D in malhas:
		ok(m.mesh!=null and m.mesh.get_surface_count()==1,"Superfície válida "+m.name)
		var transformacao: Transform3D=modelo.global_transform.affine_inverse()*m.global_transform
		var local: AABB=transformacao*m.get_aabb()
		caixa=local if primeira else caixa.merge(local)
		primeira=false
		var material:=m.mesh.surface_get_material(0) as StandardMaterial3D
		ok(material!=null,"Material importado "+m.name)
		if material: ok(material.albedo_color.a>.99,"Material opaco "+m.name)
		var arrays:=m.mesh.surface_get_arrays(0)
		triangulos+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
	ok(triangulos<65000,"Orçamento de triângulos")
	ok(caixa.size.x>4.0 and caixa.size.x<4.4,"Largura de jogo")
	ok(caixa.size.y>2.9 and caixa.size.y<3.2,"Altura de jogo")
	ok(caixa.position.y>=-.005,"Apoios no solo")
	for nome in ["Frente","Lateral","Costas","Detalhes","Geral"]:
		cena.enquadrar(nome)
		ok(root.get_camera_3d()!=null,"Câmera "+nome)
		await captura(nome.to_lower())
	cena.enquadrar("Frente")
	cena.luz.aplicar(23)
	await captura("noite")
	cena.queue_free()
	await process_frame
	print("ARTE_CENTRO_CACA: %d verificações; %d falhas; %d triângulos"%[total,falhas,triangulos])
	quit(1 if falhas else 0)
